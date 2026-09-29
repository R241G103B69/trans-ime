#import "LocalDictionary.h"

@implementation TranslationCandidate

- (instancetype)initWithText:(NSString *)text
                       style:(NSString *)style
                        tone:(NSString *)tone {
    self = [super init];
    if (self) {
        _text = [text copy];
        _style = [style copy];
        _tone = [tone copy];
        _isVocabulary = NO;
    }
    return self;
}

- (instancetype)initWithText:(NSString *)text
                originalWord:(NSString *)originalWord
                         pos:(NSString *)pos {
    self = [super init];
    if (self) {
        _text = [text copy];
        _originalWord = [originalWord copy];
        _pos = [pos copy];
        _style = [NSString stringWithFormat:@"词汇 (%@)", pos ?: @"释义"];
        _tone = @"vocab";
        _isVocabulary = YES;
    }
    return self;
}

- (NSString *)description {
    if (self.isVocabulary) {
        return [NSString stringWithFormat:@"[%@] %@ (%@)", self.style, self.text, self.originalWord];
    }
    return [NSString stringWithFormat:@"[%@] %@", self.style, self.text];
}

@end

@implementation MatchResult
- (instancetype)init {
    self = [super init];
    if (self) {
        _sentenceCandidates = @[];
        _vocabularyCandidates = @[];
        _isExactSentenceMatch = NO;
    }
    return self;
}
@end

@interface LocalDictionary ()
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *sentences;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *vocabulary;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *exactSentenceMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<NSString *> *> *vocabMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *vocabPosMap;
@end

@implementation LocalDictionary

+ (instancetype)sharedDictionary {
    static LocalDictionary *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LocalDictionary alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sentences = [NSMutableArray array];
        _vocabulary = [NSMutableArray array];
        _exactSentenceMap = [NSMutableDictionary dictionary];
        _vocabMap = [NSMutableDictionary dictionary];
        _vocabPosMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)loadFromJSONPath:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        NSLog(@"[LocalDictionary] Warning: Unable to read file at %@", path);
        return;
    }

    NSError *error = nil;
    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![root isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[LocalDictionary] Error parsing JSON: %@", error);
        return;
    }

    NSArray *sentencesArr = root[@"sentences"];
    if ([sentencesArr isKindOfClass:[NSArray class]]) {
        [self.sentences setArray:sentencesArr];
        for (NSDictionary *s in sentencesArr) {
            NSString *chinese = s[@"chinese"];
            if (chinese) {
                self.exactSentenceMap[chinese] = s;
                // Also index without punctuation
                NSString *trimmed = [chinese stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
                self.exactSentenceMap[trimmed] = s;
            }
        }
    }

    NSArray *vocabArr = root[@"vocabulary"];
    if ([vocabArr isKindOfClass:[NSArray class]]) {
        [self.vocabulary setArray:vocabArr];
        for (NSDictionary *v in vocabArr) {
            NSString *word = v[@"chinese"];
            NSArray *eng = v[@"english"];
            NSString *pos = v[@"pos"];
            if (word && eng) {
                self.vocabMap[word] = eng;
                if (pos) self.vocabPosMap[word] = pos;
            }
        }
    }
    NSLog(@"[LocalDictionary] Loaded %lu sentences, %lu vocab entries",
          (unsigned long)self.sentences.count, (unsigned long)self.vocabulary.count);
}

- (nullable MatchResult *)search:(NSString *)query {
    NSString *cleanQuery = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cleanQuery.length == 0) return nil;

    MatchResult *result = [[MatchResult alloc] init];
    result.sourceChinese = cleanQuery;

    // 1. Check exact sentence match
    NSDictionary *exact = self.exactSentenceMap[cleanQuery];
    if (!exact) {
        NSString *unpunctuated = [cleanQuery stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
        exact = self.exactSentenceMap[unpunctuated];
    }

    NSMutableArray<TranslationCandidate *> *sCands = [NSMutableArray array];
    NSMutableArray<TranslationCandidate *> *vCands = [NSMutableArray array];

    if (exact) {
        result.isExactSentenceMatch = YES;
        NSArray *cands = exact[@"candidates"];
        for (NSDictionary *c in cands) {
            TranslationCandidate *cand = [[TranslationCandidate alloc] initWithText:c[@"text"]
                                                                             style:c[@"style"]
                                                                              tone:c[@"tone"]];
            [sCands addObject:cand];
        }

        // Keywords in exact sentence
        NSArray *keywords = exact[@"keywords"];
        for (NSDictionary *kw in keywords) {
            NSString *word = kw[@"word"];
            NSString *pos = kw[@"pos"];
            NSArray *trans = kw[@"translations"];
            for (NSString *t in trans) {
                TranslationCandidate *tc = [[TranslationCandidate alloc] initWithText:t
                                                                         originalWord:word
                                                                                  pos:pos];
                [vCands addObject:tc];
            }
        }
    } else {
        // Partial or keyword matching in sentence templates
        for (NSDictionary *s in self.sentences) {
            NSString *chinese = s[@"chinese"];
            if ([chinese containsString:cleanQuery] || [cleanQuery containsString:chinese]) {
                NSArray *cands = s[@"candidates"];
                for (NSDictionary *c in cands) {
                    TranslationCandidate *cand = [[TranslationCandidate alloc] initWithText:c[@"text"]
                                                                                     style:[NSString stringWithFormat:@"推荐 (%@)", c[@"style"]]
                                                                                      tone:c[@"tone"]];
                    [sCands addObject:cand];
                }
                break;
            }
        }

        // Extract vocabulary found in query
        [vCands addObjectsFromArray:[self lookupVocabularyForSentence:cleanQuery]];
    }

    result.sentenceCandidates = sCands;
    result.vocabularyCandidates = vCands;
    return result;
}

- (NSArray<TranslationCandidate *> *)lookupVocabularyForSentence:(NSString *)sentence {
    NSMutableArray<TranslationCandidate *> *list = [NSMutableArray array];
    for (NSString *word in self.vocabMap) {
        if ([sentence containsString:word]) {
            NSArray<NSString *> *translations = self.vocabMap[word];
            NSString *pos = self.vocabPosMap[word];
            for (NSString *t in translations) {
                TranslationCandidate *tc = [[TranslationCandidate alloc] initWithText:t
                                                                         originalWord:word
                                                                                  pos:pos];
                [list addObject:tc];
            }
        }
    }
    return list;
}

- (NSArray<TranslationCandidate *> *)searchByPinyin:(NSString *)pinyinQuery {
    NSString *clean = [[pinyinQuery lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableArray<TranslationCandidate *> *list = [NSMutableArray array];

    for (NSDictionary *s in self.sentences) {
        NSString *py = [[s[@"pinyin"] lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@""];
        if ([py containsString:clean]) {
            NSArray *cands = s[@"candidates"];
            if (cands.count > 0) {
                NSDictionary *c = cands[0];
                TranslationCandidate *tc = [[TranslationCandidate alloc] initWithText:c[@"text"]
                                                                                style:[NSString stringWithFormat:@"%@ -> %@", s[@"chinese"], c[@"style"]]
                                                                                 tone:c[@"tone"]];
                [list addObject:tc];
            }
        }
    }
    return list;
}

@end
