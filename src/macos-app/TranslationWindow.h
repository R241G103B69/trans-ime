#import <Cocoa/Cocoa.h>
#import "CandidateView.h"
#import "TranslationEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface TranslationWindow : NSPanel <NSTextFieldDelegate, CandidateViewDelegate>

@property (nonatomic, strong) NSTextField *inputField;
@property (nonatomic, strong) CandidateView *candidateView;
@property (nonatomic, strong) NSTextField *statusBar;
@property (nonatomic, strong) NSVisualEffectView *visualEffectView;

+ (instancetype)sharedWindow;

- (void)toggleWindow;
- (void)presentWindow;
- (void)dismissWindow;

@end

NS_ASSUME_NONNULL_END
