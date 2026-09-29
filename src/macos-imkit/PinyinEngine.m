#import "PinyinEngine.h"

@implementation PinyinCandidate

- (instancetype)initWithChinese:(NSString *)chinese
                        english:(NSString *)english
                         pinyin:(NSString *)pinyin {
    self = [super init];
    if (self) {
        _chinese = [chinese copy];
        _english = [english copy];
        _pinyin = [pinyin copy];
    }
    return self;
}

- (NSString *)displayLabel {
    return [NSString stringWithFormat:@"%@ -> %@", self.chinese, self.english];
}

@end

@interface PinyinEngine ()
@property (nonatomic, strong) NSMutableArray<PinyinCandidate *> *dictionary;
@end

@implementation PinyinEngine

+ (instancetype)sharedEngine {
    static PinyinEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PinyinEngine alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _dictionary = [NSMutableArray array];
        [self loadDefaultDictionary];
    }
    return self;
}

- (void)loadDefaultDictionary {
    NSArray *items = @[
        @[@"nihao", @"你好", @"Hello"],
        @[@"xiexie", @"谢谢", @"Thank you"],
        @[@"kaihui", @"开会", @"Have a meeting"],
        @[@"huiyishi", @"会议室", @"Conference room"],
        @[@"fangan", @"方案", @"Solution / Proposal"],
        @[@"sheji", @"设计", @"Design"],
        @[@"kaifa", @"开发", @"Development / Develop"],
        @[@"ceshi", @"测试", @"Test / Verify"],
        @[@"fabu", @"发布", @"Release / Deploy"],
        @[@"wenti", @"问题", @"Issue / Problem"],
        @[@"jiejue", @"解决", @"Resolve / Fix"],
        @[@"youkong", @"有空", @"Available / Free"],
        @[@"shoudao", @"收到", @"Got it / Acknowledged"],
        @[@"fankui", @"反馈", @"Feedback"],
        @[@"jiezhi", @"截止日期", @"Deadline"],
        @[@"richeng", @"日程", @"Schedule / Agenda"],
        @[@"gaoxing", @"高兴", @"Glad / Pleased"],
        @[@"chashou", @"查收", @"Find attached / Check"],
        @[@"fujian", @"附件", @"Attachment"],
        @[@"daima", @"代码", @"Code / Repository"],
        @[@"laqu", @"拉取", @"Pull / Fetch"]
    ];

    for (NSArray *entry in items) {
        PinyinCandidate *c = [[PinyinCandidate alloc] initWithChinese:entry[1]
                                                              english:entry[2]
                                                               pinyin:entry[0]];
        [self.dictionary addObject:c];
    }
}

- (NSArray<PinyinCandidate *> *)candidatesForPinyin:(NSString *)pinyin {
    NSString *clean = [[pinyin lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (clean.length == 0) return @[];

    NSMutableArray<PinyinCandidate *> *results = [NSMutableArray array];

    // 1. Exact prefix match
    for (PinyinCandidate *c in self.dictionary) {
        if ([c.pinyin hasPrefix:clean]) {
            [results addObject:c];
        }
    }

    // 2. Contains match if few
    if (results.count == 0) {
        for (PinyinCandidate *c in self.dictionary) {
            if ([c.pinyin containsString:clean]) {
                [results addObject:c];
            }
        }
    }

    return results;
}

@end
