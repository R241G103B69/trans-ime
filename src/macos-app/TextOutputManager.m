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
    // Don't capture our own app as the target
    if (frontApp && ![frontApp.bundleIdentifier isEqualToString:myBundleId]) {
        self.targetApp = frontApp;
        NSLog(@"[TextOutputManager] Captured target app: %@ (%@)", frontApp.localizedName, frontApp.bundleIdentifier);
    }
}

- (void)commitEnglishText:(NSString *)text completion:(void(^ _Nullable)(BOOL success))completion {
    if (text.length == 0) {
        if (completion) completion(NO);
        return;
    }

    NSLog(@"[TextOutputManager] Committing English text: %@", text);

    // 1. Always put English text onto pasteboard so user has it immediately
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:text forType:NSPasteboardTypeString];

    // 2. Check Accessibility permission
    BOOL isTrusted = [self hasAccessibilityPermission];
    if (!isTrusted) {
        NSLog(@"[TextOutputManager] WARNING: Accessibility permission not granted. Prompting user...");
        [self requestAccessibilityPermission];
    }

    // 3. Reactivate target application
    NSRunningApplication *target = self.targetApp;
    if (target) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [target activateWithOptions:NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps];
        #pragma clang diagnostic pop
    }

    // 4. Send paste command after target application window regains focus
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(160 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [self synthesizePasteCommandWithTarget:target];

        if (completion) completion(YES);
    });
}

- (void)synthesizePasteCommandWithTarget:(nullable NSRunningApplication *)target {
    pid_t targetPid = target ? target.processIdentifier : 0;

    // Method 1: CGEventPost with Command+V
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (source) {
        CGKeyCode vKeyCode = (CGKeyCode)9; // 'v' key in US QWERTY layout
        CGEventRef keyDown = CGEventCreateKeyboardEvent(source, vKeyCode, true);
        CGEventRef keyUp = CGEventCreateKeyboardEvent(source, vKeyCode, false);

        if (keyDown && keyUp) {
            CGEventSetFlags(keyDown, kCGEventFlagMaskCommand);
            CGEventSetFlags(keyUp, kCGEventFlagMaskCommand);

            // Post to target PID directly if available, or to system event tap
            if (targetPid > 0) {
                CGEventPostToPid(targetPid, keyDown);
                usleep(25000); // 25ms
                CGEventPostToPid(targetPid, keyUp);
            }

            // Also post to HID Event Tap for universal compatibility
            CGEventPost(kCGHIDEventTap, keyDown);
            usleep(25000); // 25ms
            CGEventPost(kCGHIDEventTap, keyUp);

            CFRelease(keyDown);
            CFRelease(keyUp);
            CFRelease(source);
            return;
        }
        CFRelease(source);
    }

    // Method 2: Fallback via AppleScript System Events keystroke
    NSString *scriptStr = @"tell application \"System Events\" to keystroke \"v\" using {command down}";
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptStr];
    NSDictionary *err = nil;
    [appleScript executeAndReturnError:&err];
    if (err) {
        NSLog(@"[TextOutputManager] AppleScript fallback message: %@", err);
    }
}

@end
