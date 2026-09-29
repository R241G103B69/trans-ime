#import "TextOutputManager.h"
#import <Carbon/Carbon.h>

@implementation TextOutputManager

+ (instancetype)sharedManager {
    static TextOutputManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TextOutputManager alloc] init];
    });
    return instance;
}

- (void)captureTargetApplication {
    NSRunningApplication *frontApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    // Don't capture our own app as the target
    if (frontApp && ![frontApp.bundleIdentifier isEqualToString:[[NSBundle mainBundle] bundleIdentifier]]) {
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

    // 1. Save old pasteboard content if possible
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSString *oldString = [pasteboard stringForType:NSPasteboardTypeString];

    // 2. Put English text onto pasteboard
    [pasteboard clearContents];
    [pasteboard setString:text forType:NSPasteboardTypeString];

    // 3. Reactivate previous application
    if (self.targetApp) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.targetApp activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        #pragma clang diagnostic pop
    }

    // 4. Send Command+V to paste the text into the active cursor
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(80 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [self synthesizePasteCommand];

        // 5. Optionally restore previous clipboard content after paste finishes
        if (oldString) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(400 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                // Only restore if user hasn't copied something new in the meantime
                NSString *current = [pasteboard stringForType:NSPasteboardTypeString];
                if ([current isEqualToString:text]) {
                    [pasteboard clearContents];
                    [pasteboard setString:oldString forType:NSPasteboardTypeString];
                }
            });
        }

        if (completion) completion(YES);
    });
}

- (void)synthesizePasteCommand {
    // Attempt 1: CGEventPost with Command+V
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (source) {
        CGKeyCode vKeyCode = (CGKeyCode)9; // 'v' key in US layout
        CGEventRef keyDown = CGEventCreateKeyboardEvent(source, vKeyCode, true);
        CGEventRef keyUp = CGEventCreateKeyboardEvent(source, vKeyCode, false);

        if (keyDown && keyUp) {
            CGEventSetFlags(keyDown, kCGEventFlagMaskCommand);
            CGEventSetFlags(keyUp, kCGEventFlagMaskCommand);

            CGEventPost(kCGHIDEventTap, keyDown);
            usleep(15000); // 15ms
            CGEventPost(kCGHIDEventTap, keyUp);

            CFRelease(keyDown);
            CFRelease(keyUp);
            CFRelease(source);
            return;
        }
        CFRelease(source);
    }

    // Fallback: osascript System Events keystroke
    NSString *scriptStr = @"tell application \"System Events\" to keystroke \"v\" using {command down}";
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptStr];
    NSDictionary *err = nil;
    [appleScript executeAndReturnError:&err];
    if (err) {
        NSLog(@"[TextOutputManager] AppleScript fallback notice: %@", err);
    }
}

@end
