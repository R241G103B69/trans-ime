#import <Foundation/Foundation.h>
#import "LocalDictionary.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^TranslationCallback)(NSString *query,
                                   NSArray<TranslationCandidate *> *candidates,
                                   BOOL fromCache,
                                   NSError * _Nullable error);

@interface TranslationEngine : NSObject

@property (nonatomic, copy) NSString *targetLanguage; // default "en"
@property (nonatomic, copy, nullable) NSString *llmApiKey;
@property (nonatomic, copy, nullable) NSString *llmApiEndpoint; // default "https://api.deepseek.com/v1" or similar
@property (nonatomic, copy, nullable) NSString *llmModelName;   // e.g. "deepseek-chat"
@property (nonatomic, assign) BOOL enableLLM;

+ (instancetype)sharedEngine;

/// Request translation with automatic debounce and cache lookup
- (void)translate:(NSString *)chineseText
     debounceMs:(NSInteger)debounceMs
       callback:(TranslationCallback)callback;

/// Synchronous / fast offline lookup
- (NSArray<TranslationCandidate *> *)quickOfflineLookup:(NSString *)chineseText;

/// Clear in-memory cache
- (void)clearCache;

@end

NS_ASSUME_NONNULL_END
