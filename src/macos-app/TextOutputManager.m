#import "TextOutputManager.h"
#import <Carbon/Carbon.h>
#import <ApplicationServices/ApplicationServices.h>

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

- (void)onAppActivated:(NSNotification *)note {
    NSRunningApplication *app = note.userInfo[NSWorkspaceApplicationKey];
    NSString *myBundleId = [[NSBundle mainBundle] bundleIdentifier];
    if (app && ![app.bundleIdentifier isEqualToString:myBundleId]) {
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
    NSString *myBundleId = [[NSBundle mainBundle] bundleIdentifier];
    if (frontApp && ![frontApp.bundleIdentifier isEqualToString:myBundleId]) {
        self.targetApp = frontApp;
        NSLog(@"[TextOutputManager] Explicitly captured target app: %@ (%@)",
              frontApp.localizedName, frontApp.bundleIdentifier);
    }
}

- (void)commitEnglishText:(NSString *)text completion:(void(^ _Nullable)(BOOL success))completion {
    if (text.length == 0) {
        if (completion) completion(NO);
        return;
    }

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

    // 3. Dispatch paste event after window focus settles
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [self synthesizePasteCommandWithTarget:target];

        if (completion) completion(YES);
    });
}

- (void)synthesizePasteCommandWithTarget:(nullable NSRunningApplication *)target {
    // Standard full Command+V keystroke sequence
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
        NSLog(@"[TextOutputManager] Synthesized complete Command+V sequence via CGEvent.");
    }

    // Secondary fallback: AppleScript keystroke
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(80 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        NSString *scriptStr = @"tell application \"System Events\" to keystroke \"v\" using command down";
        NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptStr];
        NSDictionary *err = nil;
        [appleScript executeAndReturnError:&err];
        if (err) {
            NSLog(@"[TextOutputManager] AppleScript fallback notice: %@", err);
        }
    });
}

@end
