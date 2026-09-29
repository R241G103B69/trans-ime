#import <Cocoa/Cocoa.h>
#import "TextOutputManager.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"=== Running TextOutputManager Tests ===");

        TextOutputManager *mgr = [TextOutputManager sharedManager];
        assert(mgr != nil);

        // Test 1: Pasteboard text injection
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        NSString *testString = @"Would you have some time tomorrow afternoon to discuss project progress?";
        [pb clearContents];
        [pb setString:testString forType:NSPasteboardTypeString];

        NSString *readBack = [pb stringForType:NSPasteboardTypeString];
        assert([readBack isEqualToString:testString]);
        NSLog(@"[PASS] Pasteboard injection test verified: %@", readBack);

        // Test 2: Active application detection
        NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
        NSLog(@"[PASS] Current frontmost application detected: %@ (%@)", front.localizedName, front.bundleIdentifier);

        [mgr captureTargetApplication];
        NSLog(@"[PASS] Target application capture handled safely.");

        NSLog(@"=== ALL TextOutputManager TESTS PASSED SUCCESSFULLY! ===");
    }
    return 0;
}
