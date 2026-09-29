#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>
#import "PinyinEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface TransInputController : IMKInputController

@property (nonatomic, strong) NSMutableString *compositionBuffer;
@property (nonatomic, strong) IMKCandidates *candidatesWindow;
@property (nonatomic, strong) NSArray<PinyinCandidate *> *currentCandidates;

@end

NS_ASSUME_NONNULL_END
