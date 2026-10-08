#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface TextOutputManager : NSObject

@property (nonatomic, strong, nullable) NSRunningApplication *targetApp;

+ (instancetype)sharedManager;

- (BOOL)hasAccessibilityPermission;
- (void)requestAccessibilityPermission;

/// Call this immediately before presenting the translation window to capture target focus
- (void)captureTargetApplication;

/// Inserts the chosen English text directly into the target application
- (void)commitEnglishText:(NSString *)text completion:(void(^ _Nullable)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
