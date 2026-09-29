#import <Cocoa/Cocoa.h>
#import "LocalDictionary.h"

NS_ASSUME_NONNULL_BEGIN

@protocol CandidateViewDelegate <NSObject>
- (void)didSelectCandidate:(TranslationCandidate *)candidate index:(NSInteger)index;
@end

@interface CandidateView : NSView

@property (nonatomic, weak) id<CandidateViewDelegate> delegate;
@property (nonatomic, strong) NSArray<TranslationCandidate *> *candidates;
@property (nonatomic, assign) NSInteger selectedIndex;

- (void)updateCandidates:(NSArray<TranslationCandidate *> *)candidates;
- (void)selectNext;
- (void)selectPrevious;
- (nullable TranslationCandidate *)selectedCandidate;
- (nullable TranslationCandidate *)candidateAtIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
