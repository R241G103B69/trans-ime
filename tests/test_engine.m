#import <Foundation/Foundation.h>
#import "LocalDictionary.h"
#import "TranslationEngine.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"=== Running TransType Unit Tests ===");

        NSString *dictPath = @"/Users/a255255255/.gemini/antigravity/scratch/trans-ime/src/macos-app/Resources/dictionary.json";
        LocalDictionary *dict = [LocalDictionary sharedDictionary];
        [dict loadFromJSONPath:dictPath];

        // Test 1: Exact Sentence Match
        NSLog(@"\n--- Test 1: Exact Sentence Match ---");
        NSString *query1 = @"今天下午三点在会议室开会";
        MatchResult *res1 = [dict search:query1];
        assert(res1 != nil);
        assert(res1.isExactSentenceMatch == YES);
        assert(res1.sentenceCandidates.count >= 4);
        NSLog(@"[PASS] Found %lu sentence candidates for '%@'", (unsigned long)res1.sentenceCandidates.count, query1);
        for (NSInteger i = 0; i < res1.sentenceCandidates.count; i++) {
            TranslationCandidate *c = res1.sentenceCandidates[i];
            NSLog(@"  Candidate %ld [%@]: %@", (long)(i + 1), c.style, c.text);
        }
        assert([res1.sentenceCandidates[0].text containsString:@"Meeting in the conference room"]);

        // Test 2: Keywords / Vocabulary Extraction
        NSLog(@"\n--- Test 2: Keywords & Vocabulary Extraction ---");
        assert(res1.vocabularyCandidates.count > 0);
        NSLog(@"[PASS] Extracted %lu vocabulary alternatives:", (unsigned long)res1.vocabularyCandidates.count);
        for (TranslationCandidate *v in res1.vocabularyCandidates) {
            NSLog(@"  Vocab: %@ -> %@ (%@)", v.originalWord, v.text, v.style);
        }

        // Test 3: Vocabulary Direct Query
        NSLog(@"\n--- Test 3: Sentence with Embedded Vocab ---");
        NSString *query3 = @"我们需要尽快确定新的设计方案与技术架构";
        MatchResult *res3 = [dict search:query3];
        assert(res3 != nil);
        NSLog(@"[PASS] Embedded vocab candidates for '%@':", query3);
        BOOL foundFangan = NO;
        for (TranslationCandidate *c in res3.vocabularyCandidates) {
            NSLog(@"  Embedded Vocab: %@ -> %@", c.originalWord, c.text);
            if ([c.originalWord isEqualToString:@"方案"]) foundFangan = YES;
        }
        assert(foundFangan == YES);

        // Test 4: Pinyin Query
        NSLog(@"\n--- Test 4: Pinyin Query ---");
        NSArray<TranslationCandidate *> *pyList = [dict searchByPinyin:@"nihao"];
        assert(pyList.count > 0);
        NSLog(@"[PASS] Pinyin match for 'nihao': %@", pyList[0].text);
        assert([pyList[0].text containsString:@"Hello"]);

        // Test 5: Quick Offline Lookup in TranslationEngine
        NSLog(@"\n--- Test 5: TranslationEngine Offline Lookup & Cache ---");
        TranslationEngine *engine = [TranslationEngine sharedEngine];
        NSArray<TranslationCandidate *> *engineCands = [engine quickOfflineLookup:@"很高兴认识你"];
        assert(engineCands.count > 0);
        NSLog(@"[PASS] Engine quick lookup returned %lu candidates", (unsigned long)engineCands.count);
        assert([engineCands[0].text containsString:@"Nice to meet you"]);

        // Test 6: Second call should hit in-memory cache
        NSArray<TranslationCandidate *> *cachedCands = [engine quickOfflineLookup:@"很高兴认识你"];
        assert(cachedCands == engineCands);
        NSLog(@"[PASS] Memory cache hit verified!");

        NSLog(@"\n=== ALL 6 UNIT TESTS PASSED SUCCESSFULLY! ===");
    }
    return 0;
}
