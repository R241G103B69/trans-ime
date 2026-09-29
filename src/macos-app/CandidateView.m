#import "CandidateView.h"

@interface CandidateRowView : NSView
@property (nonatomic, strong) TranslationCandidate *candidate;
@property (nonatomic, assign) NSInteger indexNumber;
@property (nonatomic, assign) BOOL isSelected;
@property (nonatomic, copy) void (^onClick)(void);
@property (nonatomic, strong) NSTrackingArea *trackingArea;
@end

@implementation CandidateRowView

- (instancetype)initWithCandidate:(TranslationCandidate *)candidate indexNumber:(NSInteger)indexNumber {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _candidate = candidate;
        _indexNumber = indexNumber;
        _isSelected = NO;
        self.wantsLayer = YES;
        self.layer.cornerRadius = 8.0;
    }
    return self;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.trackingArea) {
        [self removeTrackingArea:self.trackingArea];
    }
    self.trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                    options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways)
                                                      owner:self
                                                   userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

- (void)mouseEntered:(NSEvent *)event {
    self.isSelected = YES;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event {
    // Keep selection or revert
    [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)event {
    if (self.onClick) {
        self.onClick();
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    if (self.isSelected) {
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.12] setFill];
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:8 yRadius:8];
        [path fill];

        // Accent indicator on left
        [[NSColor colorWithCalibratedRed:0.22 green:0.55 blue:0.98 alpha:1.0] setFill];
        NSRect bar = NSMakeRect(4, 6, 3, self.bounds.size.height - 12);
        [[NSBezierPath bezierPathWithRoundedRect:bar xRadius:1.5 yRadius:1.5] fill];
    }

    CGFloat x = 18.0;
    CGFloat midY = self.bounds.size.height / 2.0;

    // 1. Number Badge [1]
    NSString *numStr = [NSString stringWithFormat:@"%ld", (long)self.indexNumber];
    NSDictionary *numAttr = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightBold],
        NSForegroundColorAttributeName: self.isSelected ? [NSColor whiteColor] : [NSColor secondaryLabelColor]
    };
    NSRect numBadgeRect = NSMakeRect(x, midY - 9, 18, 18);
    [[NSColor colorWithCalibratedWhite:0.3 alpha:0.3] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:numBadgeRect xRadius:4 yRadius:4] fill];
    NSSize numSize = [numStr sizeWithAttributes:numAttr];
    [numStr drawAtPoint:NSMakePoint(numBadgeRect.origin.x + (18 - numSize.width)/2.0, numBadgeRect.origin.y + (18 - numSize.height)/2.0) withAttributes:numAttr];

    x += 26.0;

    // 2. Style Tag (e.g. "自然推荐", "商务正式", "词汇: 动词")
    NSString *tagStr = self.candidate.style ?: @"推荐";
    NSColor *tagBgColor = [NSColor colorWithCalibratedRed:0.18 green:0.35 blue:0.65 alpha:0.35];
    NSColor *tagTextColor = [NSColor colorWithCalibratedRed:0.45 green:0.75 blue:1.0 alpha:1.0];

    if (self.candidate.isVocabulary) {
        tagBgColor = [NSColor colorWithCalibratedRed:0.55 green:0.25 blue:0.65 alpha:0.35];
        tagTextColor = [NSColor colorWithCalibratedRed:0.85 green:0.55 blue:0.95 alpha:1.0];
    } else if ([self.candidate.tone isEqualToString:@"formal"]) {
        tagBgColor = [NSColor colorWithCalibratedRed:0.15 green:0.50 blue:0.35 alpha:0.35];
        tagTextColor = [NSColor colorWithCalibratedRed:0.40 green:0.85 blue:0.60 alpha:1.0];
    }

    NSDictionary *tagAttr = @{
        NSFontAttributeName: [NSFont systemFontOfSize:10 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: tagTextColor
    };
    NSSize tagSize = [tagStr sizeWithAttributes:tagAttr];
    NSRect tagRect = NSMakeRect(x, midY - 9, tagSize.width + 10, 18);
    [tagBgColor setFill];
    [[NSBezierPath bezierPathWithRoundedRect:tagRect xRadius:4 yRadius:4] fill];
    [tagStr drawAtPoint:NSMakePoint(tagRect.origin.x + 5, tagRect.origin.y + (18 - tagSize.height)/2.0) withAttributes:tagAttr];

    x += tagRect.size.width + 10.0;

    // 3. English Translation Text
    NSString *eng = self.candidate.text ?: @"";
    if (self.candidate.isVocabulary && self.candidate.originalWord.length > 0) {
        eng = [NSString stringWithFormat:@"%@  ·  %@", self.candidate.text, self.candidate.originalWord];
    }

    NSDictionary *engAttr = @{
        NSFontAttributeName: [NSFont systemFontOfSize:13.5 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: self.isSelected ? [NSColor whiteColor] : [NSColor labelColor]
    };
    NSSize engSize = [eng sizeWithAttributes:engAttr];
    CGFloat maxW = self.bounds.size.width - x - 12;
    [eng drawWithRect:NSMakeRect(x, midY - engSize.height / 2.0, maxW, engSize.height)
              options:NSStringDrawingTruncatesLastVisibleLine
           attributes:engAttr];
}

@end

@interface CandidateView ()
@property (nonatomic, strong) NSMutableArray<CandidateRowView *> *rowViews;
@end

@implementation CandidateView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _rowViews = [NSMutableArray array];
        _candidates = @[];
        _selectedIndex = 0;
    }
    return self;
}

- (void)updateCandidates:(NSArray<TranslationCandidate *> *)candidates {
    _candidates = [candidates copy];
    _selectedIndex = 0;

    for (NSView *v in self.subviews) {
        [v removeFromSuperview];
    }
    [self.rowViews removeAllObjects];

    CGFloat rowH = 34.0;
    CGFloat spacing = 4.0;
    NSInteger count = MIN((NSInteger)candidates.count, 7);

    for (NSInteger i = 0; i < count; i++) {
        TranslationCandidate *cand = candidates[i];
        CandidateRowView *row = [[CandidateRowView alloc] initWithCandidate:cand indexNumber:(i + 1)];
        row.isSelected = (i == self.selectedIndex);

        __weak typeof(self) weakSelf = self;
        row.onClick = ^{
            [weakSelf selectIndexAndCommit:i];
        };

        [self.rowViews addObject:row];
        [self addSubview:row];
    }

    [self layoutRows];
    [self setNeedsDisplay:YES];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    [super resizeSubviewsWithOldSize:oldSize];
    [self layoutRows];
}

- (void)layoutRows {
    CGFloat rowH = 34.0;
    CGFloat spacing = 4.0;
    CGFloat w = self.bounds.size.width;
    NSInteger count = self.rowViews.count;

    for (NSInteger i = 0; i < count; i++) {
        CandidateRowView *row = self.rowViews[i];
        // In macOS flipped coordinates vs normal: by default 0 is at bottom
        CGFloat y = self.bounds.size.height - (i + 1) * (rowH + spacing);
        row.frame = NSMakeRect(0, y, w, rowH);
    }
}

- (void)selectNext {
    if (self.candidates.count == 0) return;
    self.selectedIndex = (self.selectedIndex + 1) % MIN((NSInteger)self.candidates.count, 7);
    [self refreshSelection];
}

- (void)selectPrevious {
    if (self.candidates.count == 0) return;
    self.selectedIndex = (self.selectedIndex - 1 + MIN((NSInteger)self.candidates.count, 7)) % MIN((NSInteger)self.candidates.count, 7);
    [self refreshSelection];
}

- (void)refreshSelection {
    for (NSInteger i = 0; i < self.rowViews.count; i++) {
        self.rowViews[i].isSelected = (i == self.selectedIndex);
        [self.rowViews[i] setNeedsDisplay:YES];
    }
}

- (void)selectIndexAndCommit:(NSInteger)index {
    if (index >= 0 && index < self.candidates.count) {
        self.selectedIndex = index;
        [self refreshSelection];
        if ([self.delegate respondsToSelector:@selector(didSelectCandidate:index:)]) {
            [self.delegate didSelectCandidate:self.candidates[index] index:index];
        }
    }
}

- (nullable TranslationCandidate *)selectedCandidate {
    if (self.selectedIndex >= 0 && self.selectedIndex < self.candidates.count) {
        return self.candidates[self.selectedIndex];
    }
    return nil;
}

- (nullable TranslationCandidate *)candidateAtIndex:(NSInteger)index {
    if (index >= 0 && index < self.candidates.count) {
        return self.candidates[index];
    }
    return nil;
}

@end
