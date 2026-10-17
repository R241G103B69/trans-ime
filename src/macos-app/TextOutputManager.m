#import "TextOutputManager.h"
#import <Carbon/Carbon.h>
#import <ApplicationServices/ApplicationServices.h>

@interface TextOutputManager ()
@property (nonatomic, assign) BOOL isCommitting;
@end

@implementation TextOutputManager

+ (instancetype)sharedManager {
    static TextOutputManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TextOutputManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isCommitting = NO;
        // Automatically track whatever external app the user is interacting with!
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                               selector:@selector(onAppActivated:)
                                                                   name:NSWorkspaceDidActivateApplicationNotification
                                                                 object:nil];
        
        // Initial capture
        [self captureTargetApplication];
    }
    return self;
}

- (BOOL)isSystemOrUtilityApp:(nullable NSRunningApplication *)app {
    if (!app || !app.bundleIdentifier) return YES;

    NSString *bundleId = app.bundleIdentifier;
    NSString *myBundleId = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleId isEqualToString:myBundleId]) {
        return YES;
    }

    // System utility / background applications where user cannot type documents
    static NSSet *systemBundleIds = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        systemBundleIds = [NSSet setWithObjects:
            @"com.apple.systempreferences",
            @"com.apple.SystemSettings",
            @"com.apple.dock",
            @"com.apple.Spotlight",
            @"com.apple.loginwindow",
            @"com.apple.controlcenter",
            @"com.apple.notificationcenterui",
            @"com.apple.WindowManager",
            @"com.apple.accessibility.AccessibilityUIServer",
            @"com.apple.TextInputMenuAgent",
            @"com.apple.TextInputSwitcher",
            @"com.apple.screencaptureui",
            nil];
    });

    return [systemBundleIds containsObject:bundleId];
}

- (void)onAppActivated:(NSNotification *)note {
    NSRunningApplication *app = note.userInfo[NSWorkspaceApplicationKey];
    if (app && ![self isSystemOrUtilityApp:app]) {
        self.targetApp = app;
        NSLog(@"[TextOutputManager] Auto-tracked active app: %@ (%@, pid: %d)",
              app.localizedName, app.bundleIdentifier, app.processIdentifier);
    }
}

- (BOOL)hasAccessibilityPermission {
    return AXIsProcessTrusted();
}

- (void)requestAccessibilityPermission {
    NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

- (void)captureTargetApplication {
    NSRunningApplication *frontApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (frontApp && ![self isSystemOrUtilityApp:frontApp]) {
        self.targetApp = frontApp;
        NSLog(@"[TextOutputManager] Explicitly captured target app: %@ (%@)",
              frontApp.localizedName, frontApp.bundleIdentifier);
    } else if (!self.targetApp || self.targetApp.isTerminated) {
        // Fallback: look for the most relevant active regular application
        NSArray<NSRunningApplication *> *apps = [[NSWorkspace sharedWorkspace] runningApplications];
        for (NSRunningApplication *app in apps) {
            if (app.activationPolicy == NSApplicationActivationPolicyRegular && ![self isSystemOrUtilityApp:app]) {
                self.targetApp = app;
                NSLog(@"[TextOutputManager] Fallback captured target app: %@ (%@)",
                      app.localizedName, app.bundleIdentifier);
                break;
            }
        }
    }
}

- (void)commitEnglishText:(NSString *)text completion:(void(^ _Nullable)(BOOL success))completion {
    if (text.length == 0) {
        if (completion) completion(NO);
        return;
    }

    // Debounce / Anti-double-commit guard
    if (self.isCommitting) {
        NSLog(@"[TextOutputManager] Ignored duplicate commit request for: %@", text);
        if (completion) completion(NO);
        return;
    }
    self.isCommitting = YES;

    NSLog(@"[TextOutputManager] Committing English text: %@", text);

    // 1. Write text to general pasteboard
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:text forType:NSPasteboardTypeString];

    // 2. Reactivate target application
    NSRunningApplication *target = self.targetApp;
    if (target) {
        NSLog(@"[TextOutputManager] Reactivating target app: %@ (pid: %d)", target.localizedName, target.processIdentifier);
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [target activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        #pragma clang diagnostic pop
    }

    // 3. Dispatch EXACTLY ONE paste event after window focus settles
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [self synthesizePasteCommandWithTarget:target];

        if (completion) completion(YES);
    });

    // Reset committing flag after short debounce period
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(350 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        self.isCommitting = NO;
    });
}

- (void)synthesizePasteCommandWithTarget:(nullable NSRunningApplication *)target {
    // Standard full Command+V keystroke sequence via CGEvent
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (source) {
        CGKeyCode cmdKey = (CGKeyCode)55; // Left Command key (0x37)
        CGKeyCode vKey   = (CGKeyCode)9;  // 'v' key in US layout (0x09)

        // 1. Command Down
        CGEventRef cmdDown = CGEventCreateKeyboardEvent(source, cmdKey, true);
        CGEventSetFlags(cmdDown, kCGEventFlagMaskCommand);
        CGEventPost(kCGHIDEventTap, cmdDown);
        CFRelease(cmdDown);

        usleep(15000); // 15ms

        // 2. 'v' Down with Command flag
        CGEventRef vDown = CGEventCreateKeyboardEvent(source, vKey, true);
        CGEventSetFlags(vDown, kCGEventFlagMaskCommand);
        CGEventPost(kCGHIDEventTap, vDown);
        CFRelease(vDown);

        usleep(25000); // 25ms

        // 3. 'v' Up with Command flag
        CGEventRef vUp = CGEventCreateKeyboardEvent(source, vKey, false);
        CGEventSetFlags(vUp, kCGEventFlagMaskCommand);
        CGEventPost(kCGHIDEventTap, vUp);
        CFRelease(vUp);

        usleep(15000); // 15ms

        // 4. Command Up
        CGEventRef cmdUp = CGEventCreateKeyboardEvent(source, cmdKey, false);
        CGEventSetFlags(cmdUp, 0);
        CGEventPost(kCGHIDEventTap, cmdUp);
        CFRelease(cmdUp);

        CFRelease(source);
        NSLog(@"[TextOutputManager] Successfully synthesized single Command+V via CGEvent.");
        return; // Return immediately! NEVER fall through to secondary AppleScript!
    }

    // Fallback ONLY IF CGEventSource failed to initialize
    NSLog(@"[TextOutputManager] CGEventSource unavailable, falling back to AppleScript.");
    NSString *scriptStr = @"tell application \"System Events\" to keystroke \"v\" using command down";
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptStr];
    NSDictionary *err = nil;
    [appleScript executeAndReturnError:&err];
    if (err) {
        NSLog(@"[TextOutputManager] AppleScript fallback notice: %@", err);
    }
}

@end
