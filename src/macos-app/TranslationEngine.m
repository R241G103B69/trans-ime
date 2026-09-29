#import "TranslationEngine.h"

@interface TranslationEngine ()
@property (nonatomic, strong) NSCache<NSString *, NSArray<TranslationCandidate *> *> *cache;
@property (nonatomic, strong) dispatch_source_t debounceTimer;
@property (nonatomic, strong) NSURLSession *urlSession;
@property (nonatomic, copy) NSString *latestPendingQuery;
@end

@implementation TranslationEngine

+ (instancetype)sharedEngine {
    static TranslationEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TranslationEngine alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cache = [[NSCache alloc] init];
        _cache.countLimit = 500;
        _targetLanguage = @"en";
        _enableLLM = NO;
        
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 4.0;
        config.timeoutIntervalForResource = 6.0;
        _urlSession = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

- (void)clearCache {
    [self.cache removeAllObjects];
}

- (NSArray<TranslationCandidate *> *)quickOfflineLookup:(NSString *)chineseText {
    NSString *clean = [chineseText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (clean.length == 0) return @[];

    // 1. Check in-memory cache
    NSArray<TranslationCandidate *> *cached = [self.cache objectForKey:clean];
    if (cached) return cached;

    // 2. Check local dictionary
    MatchResult *match = [[LocalDictionary sharedDictionary] search:clean];
    if (match) {
        NSMutableArray<TranslationCandidate *> *result = [NSMutableArray array];
        [result addObjectsFromArray:match.sentenceCandidates];
        [result addObjectsFromArray:match.vocabularyCandidates];
        if (result.count > 0) {
            [self.cache setObject:result forKey:clean];
            return result;
        }
    }

    return @[];
}

- (void)translate:(NSString *)chineseText
     debounceMs:(NSInteger)debounceMs
       callback:(TranslationCallback)callback {
    
    NSString *clean = [chineseText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (clean.length == 0) {
        callback(chineseText, @[], YES, nil);
        return;
    }

    // 1. Instant cache or local dict response
    NSArray<TranslationCandidate *> *quick = [self quickOfflineLookup:clean];
    if (quick.count > 0) {
        callback(clean, quick, YES, nil);
        // If exact match was found, no need to query network
        MatchResult *m = [[LocalDictionary sharedDictionary] search:clean];
        if (m && m.isExactSentenceMatch) {
            return;
        }
    }

    // 2. Debounce timer for online/LLM query
    self.latestPendingQuery = clean;
    if (self.debounceTimer) {
        dispatch_source_cancel(self.debounceTimer);
        self.debounceTimer = nil;
    }

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    self.debounceTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    uint64_t interval = (uint64_t)debounceMs * NSEC_PER_MSEC;
    dispatch_source_set_timer(self.debounceTimer, dispatch_time(DISPATCH_TIME_NOW, interval), DISPATCH_TIME_FOREVER, 10 * NSEC_PER_MSEC);

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.debounceTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSString *query = strongSelf.latestPendingQuery;
        if (strongSelf.enableLLM && strongSelf.llmApiKey.length > 0) {
            [strongSelf requestLLMTranslation:query callback:callback];
        } else {
            [strongSelf requestOnlineTranslation:query callback:callback];
        }
    });

    dispatch_resume(self.debounceTimer);
}

#pragma mark - Online Public Translation API

- (void)requestOnlineTranslation:(NSString *)query callback:(TranslationCallback)callback {
    // We try Google Translate public endpoint first
    NSString *encoded = [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlStr = [NSString stringWithFormat:@"https://translate.googleapis.com/translate_a/single?client=gtx&sl=zh-CN&tl=%@&dt=t&dt=bd&q=%@", self.targetLanguage, encoded];
    NSURL *url = [NSURL URLWithString:urlStr];

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" forHTTPHeaderField:@"User-Agent"];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.urlSession dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error || !data) {
            // Fallback to MyMemory API if Google fails or is blocked
            [strongSelf requestMyMemoryTranslation:query callback:callback];
            return;
        }

        NSError *jsonError = nil;
        id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if ([root isKindOfClass:[NSArray class]] && [(NSArray *)root count] > 0) {
            NSArray *firstSection = root[0];
            NSMutableString *translated = [NSMutableString string];
            if ([firstSection isKindOfClass:[NSArray class]]) {
                for (id item in firstSection) {
                    if ([item isKindOfClass:[NSArray class]] && [(NSArray *)item count] > 0) {
                        [translated appendString:item[0]];
                    }
                }
            }

            if (translated.length > 0) {
                NSMutableArray<TranslationCandidate *> *candidates = [NSMutableArray array];
                // 1. Natural / Primary translation
                [candidates addObject:[[TranslationCandidate alloc] initWithText:translated style:@"自然推荐" tone:@"natural"]];

                // Check if dictionary breakdown exists in root[1]
                if ([(NSArray *)root count] > 1 && [root[1] isKindOfClass:[NSArray class]]) {
                    NSArray *dictEntries = root[1];
                    for (id d in dictEntries) {
                        if ([d isKindOfClass:[NSArray class]] && [(NSArray *)d count] >= 2) {
                            NSString *pos = d[0];
                            NSArray *synonyms = d[1];
                            for (NSString *syn in synonyms) {
                                if (![syn isEqualToString:translated] && candidates.count < 6) {
                                    [candidates addObject:[[TranslationCandidate alloc] initWithText:syn originalWord:query pos:pos]];
                                }
                            }
                        }
                    }
                }

                // Add local vocabulary if any
                NSArray *vocab = [[LocalDictionary sharedDictionary] lookupVocabularyForSentence:query];
                [candidates addObjectsFromArray:vocab];

                [strongSelf.cache setObject:candidates forKey:query];

                dispatch_async(dispatch_get_main_queue(), ^{
                    callback(query, candidates, NO, nil);
                });
                return;
            }
        }

        // Fallback
        [strongSelf requestMyMemoryTranslation:query callback:callback];
    }];
    [task resume];
}

- (void)requestMyMemoryTranslation:(NSString *)query callback:(TranslationCallback)callback {
    NSString *encoded = [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlStr = [NSString stringWithFormat:@"https://api.mymemory.translated.net/get?q=%@&langpair=zh-CN|%@", encoded, self.targetLanguage];
    NSURL *url = [NSURL URLWithString:urlStr];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.urlSession dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error || !data) {
            // Return offline candidates if available
            NSArray *offline = [strongSelf quickOfflineLookup:query];
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(query, offline, YES, error);
            });
            return;
        }

        NSError *jsonErr = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        NSString *translatedText = json[@"responseData"][@"translatedText"];
        
        NSMutableArray<TranslationCandidate *> *candidates = [NSMutableArray array];
        if (translatedText.length > 0) {
            [candidates addObject:[[TranslationCandidate alloc] initWithText:translatedText style:@"推荐翻译" tone:@"natural"]];
        }

        // Matches
        NSArray *matches = json[@"matches"];
        if ([matches isKindOfClass:[NSArray class]]) {
            for (NSDictionary *m in matches) {
                NSString *trans = m[@"translation"];
                if (trans.length > 0 && ![trans isEqualToString:translatedText] && candidates.count < 5) {
                    [candidates addObject:[[TranslationCandidate alloc] initWithText:trans style:@"备选参考" tone:@"casual"]];
                }
            }
        }

        // Add local vocabulary
        NSArray *vocab = [[LocalDictionary sharedDictionary] lookupVocabularyForSentence:query];
        [candidates addObjectsFromArray:vocab];

        if (candidates.count > 0) {
            [strongSelf.cache setObject:candidates forKey:query];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            callback(query, candidates, NO, nil);
        });
    }];
    [task resume];
}

#pragma mark - AI / LLM Multi-Style Translation

- (void)requestLLMTranslation:(NSString *)query callback:(TranslationCallback)callback {
    NSString *endpoint = self.llmApiEndpoint ?: @"https://api.deepseek.com/v1/chat/completions";
    NSURL *url = [NSURL URLWithString:endpoint];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", self.llmApiKey] forHTTPHeaderField:@"Authorization"];

    NSString *systemPrompt = @"You are a professional bilingual translation assistant. Given Chinese text, generate 4 distinct English translation styles (Natural, Formal, Casual, Concise) and key vocabulary. Return JSON format: {\"candidates\": [{\"style\": \"自然地道\", \"text\": \"...\"}, {\"style\": \"商务正式\", \"text\": \"...\"}, {\"style\": \"日常口语\", \"text\": \"...\"}, {\"style\": \"精简短语\", \"text\": \"...\"}], \"vocabulary\": [{\"word\": \"...\", \"pos\": \"...\", \"translation\": \"...\"}]}";

    NSDictionary *body = @{
        @"model": self.llmModelName ?: @"deepseek-chat",
        @"messages": @[
            @{@"role": @"system", @"content": systemPrompt},
            @{@"role": @"user", @"content": query}
        ],
        @"temperature": @0.3,
        @"response_format": @{@"type": @"json_object"}
    };

    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.urlSession dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error || !data) {
            [strongSelf requestOnlineTranslation:query callback:callback];
            return;
        }

        NSError *parseErr = nil;
        NSDictionary *resp = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseErr];
        NSString *content = resp[@"choices"][0][@"message"][@"content"];

        if (content.length > 0) {
            NSData *contentData = [content dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:contentData options:0 error:nil];
            
            NSMutableArray<TranslationCandidate *> *candidates = [NSMutableArray array];
            NSArray *cands = result[@"candidates"];
            if ([cands isKindOfClass:[NSArray class]]) {
                for (NSDictionary *c in cands) {
                    [candidates addObject:[[TranslationCandidate alloc] initWithText:c[@"text"] style:c[@"style"] tone:@"llm"]];
                }
            }

            NSArray *vocabs = result[@"vocabulary"];
            if ([vocabs isKindOfClass:[NSArray class]]) {
                for (NSDictionary *v in vocabs) {
                    [candidates addObject:[[TranslationCandidate alloc] initWithText:v[@"translation"] originalWord:v[@"word"] pos:v[@"pos"]]];
                }
            }

            if (candidates.count > 0) {
                [strongSelf.cache setObject:candidates forKey:query];
                dispatch_async(dispatch_get_main_queue(), ^{
                    callback(query, candidates, NO, nil);
                });
                return;
            }
        }

        // If LLM response failed to parse, fallback to standard online
        [strongSelf requestOnlineTranslation:query callback:callback];
    }];
    [task resume];
}

@end
