#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TranslationCandidate : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *style; // e.g. "自然推荐", "正式商务", "日常口语", "精简短语"
@property (nonatomic, copy) NSString *tone;  // "natural", "formal", "casual", "concise"
@property (nonatomic, copy, nullable) NSString *originalWord;
@property (nonatomic, copy, nullable) NSString *pos; // Part of speech (名词, 动词等)
@property (nonatomic, assign) BOOL isVocabulary;

- (instancetype)initWithText:(NSString *)text
                       style:(NSString *)style
                        tone:(NSString *)tone;

- (instancetype)initWithText:(NSString *)text
                originalWord:(NSString *)originalWord
                         pos:(nullable NSString *)pos;
@end

@interface MatchResult : NSObject
@property (nonatomic, copy) NSString *sourceChinese;
@property (nonatomic, strong) NSArray<TranslationCandidate *> *sentenceCandidates;
@property (nonatomic, strong) NSArray<TranslationCandidate *> *vocabularyCandidates;
@property (nonatomic, assign) BOOL isExactSentenceMatch;
@end

@interface LocalDictionary : NSObject

+ (instancetype)sharedDictionary;
- (void)loadFromJSONPath:(NSString *)path;
- (nullable MatchResult *)search:(NSString *)query;
- (NSArray<TranslationCandidate *> *)lookupVocabularyForSentence:(NSString *)sentence;
- (NSArray<TranslationCandidate *> *)searchByPinyin:(NSString *)pinyinQuery;

@end

NS_ASSUME_NONNULL_END
