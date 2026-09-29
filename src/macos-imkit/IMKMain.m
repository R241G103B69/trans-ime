#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>
#import "TransInputController.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *connectionName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"InputMethodConnectionName"];
        if (!connectionName) {
            connectionName = @"TransIME_1_Connection";
        }

        NSString *identifier = [[NSBundle mainBundle] bundleIdentifier] ?: @"com.antigravity.inputmethod.TransIME";

        IMKServer *server = [[IMKServer alloc] initWithName:connectionName
                                           bundleIdentifier:identifier];
        if (!server) {
            NSLog(@"[TransIME] Failed to initialize IMKServer");
            return 1;
        }

        NSLog(@"[TransIME] System Input Method Server started successfully with connection: %@", connectionName);
        [[NSApplication sharedApplication] run];
    }
    return 0;
}
