#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PinyinCandidate : NSObject
@property (nonatomic, copy) NSString *chinese;
@property (nonatomic, copy) NSString *english;
@property (nonatomic, copy) NSString *pinyin;

- (instancetype)initWithChinese:(NSString *)chinese
                        english:(NSString *)english
                         pinyin:(NSString *)pinyin;

/// Label displayed in the IME candidate window
- (NSString *)displayLabel;
@end

@interface PinyinEngine : NSObject

+ (instancetype)sharedEngine;
- (NSArray<PinyinCandidate *> *)candidatesForPinyin:(NSString *)pinyin;

@end

NS_ASSUME_NONNULL_END
