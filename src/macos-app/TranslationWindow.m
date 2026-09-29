#import "TranslationWindow.h"
#import "TextOutputManager.h"

@interface CustomInputField : NSTextField
@property (nonatomic, copy) void (^onCommit)(void);
@property (nonatomic, copy) void (^onEscape)(void);
@property (nonatomic, copy) void (^onUpArrow)(void);
@property (nonatomic, copy) void (^onDownArrow)(void);
@property (nonatomic, copy) void (^onNumberKey)(NSInteger number);
@end

@implementation CustomInputField

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    if (event.modifierFlags & NSEventModifierFlagCommand) {
        NSString *chars = event.charactersIgnoringModifiers;
        if (chars.length == 1) {
            unichar c = [chars characterAtIndex:0];
            if (c >= '1' && c <= '7') {
                if (self.onNumberKey) {
                    self.onNumberKey(c - '0');
                    return YES;
                }
            }
        }
    }
    return [super performKeyEquivalent:event];
}

@end

@interface TranslationWindow ()
@property (nonatomic, strong) NSArray<TranslationCandidate *> *currentCandidates;
@end

@implementation TranslationWindow

+ (instancetype)sharedWindow {
    static TranslationWindow *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TranslationWindow alloc] init];
    });
    return instance;
}

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 560, 360);
    self = [super initWithContentRect:frame
                            styleMask:(NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel)
                              backing:NSBackingStoreBuffered
                                defer:NO];
    if (self) {
        self.level = NSFloatingWindowLevel;
        self.opaque = NO;
        self.backgroundColor = [NSColor clearColor];
        self.hasShadow = YES;
        self.movableByWindowBackground = YES;

        [self setupUI];
    }
    return self;
}

- (BOOL)canBecomeKeyWindow {
    return YES;
}

- (BOOL)canBecomeMainWindow {
    return YES;
}

- (void)setupUI {
    NSRect bounds = self.contentView.bounds;

    // Visual Effect (Frosted Glass) Background
    self.visualEffectView = [[NSVisualEffectView alloc] initWithFrame:bounds];
    self.visualEffectView.material = NSVisualEffectMaterialHUDWindow;
    self.visualEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.visualEffectView.state = NSVisualEffectStateActive;
    self.visualEffectView.wantsLayer = YES;
    self.visualEffectView.layer.cornerRadius = 16.0;
    self.visualEffectView.layer.masksToBounds = YES;
    self.visualEffectView.layer.borderWidth = 1.0;
    self.visualEffectView.layer.borderColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.18].CGColor;
    [self.contentView addSubview:self.visualEffectView];

    // Header Label / Icon
    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, bounds.size.height - 34, 300, 20)];
    titleLabel.stringValue = @"TransType 译打 · 智能翻译输入法";
    titleLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    titleLabel.textColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
    titleLabel.bezeled = NO;
    titleLabel.drawsBackground = NO;
    titleLabel.editable = NO;
    titleLabel.selectable = NO;
    [self.visualEffectView addSubview:titleLabel];

    // Input Field
    CustomInputField *input = [[CustomInputField alloc] initWithFrame:NSMakeRect(18, bounds.size.height - 82, bounds.size.width - 36, 40)];
    input.placeholderString = @"输入中文或拼音，如：今天下午开会 / 您明天是否有空...";
    input.font = [NSFont systemFontOfSize:16 weight:NSFontWeightMedium];
    input.focusRingType = NSFocusRingTypeNone;
    input.bezeled = NO;
    input.drawsBackground = YES;
    input.backgroundColor = [NSColor colorWithCalibratedWhite:0.15 alpha:0.4];
    input.wantsLayer = YES;
    input.layer.cornerRadius = 10.0;
    input.delegate = self;
    self.inputField = input;
    [self.visualEffectView addSubview:input];

    __weak typeof(self) weakSelf = self;
    input.onCommit = ^{
        [weakSelf commitCurrentSelection];
    };
    input.onEscape = ^{
        [weakSelf dismissWindow];
    };
    input.onUpArrow = ^{
        [weakSelf.candidateView selectPrevious];
    };
    input.onDownArrow = ^{
        [weakSelf.candidateView selectNext];
    };
    input.onNumberKey = ^(NSInteger number) {
        [weakSelf selectCandidateByNumber:number];
    };

    // Candidates View
    self.candidateView = [[CandidateView alloc] initWithFrame:NSMakeRect(18, 42, bounds.size.width - 36, bounds.size.height - 134)];
    self.candidateView.delegate = self;
    [self.visualEffectView addSubview:self.candidateView];

    // Bottom Status / Hint Bar
    self.statusBar = [[NSTextField alloc] initWithFrame:NSMakeRect(18, 12, bounds.size.width - 36, 20)];
    self.statusBar.stringValue = @"[↵] 确认首选 · [⌘1-7] 选词上屏 · [↑/↓] 切换 · [ESC] 取消";
    self.statusBar.font = [NSFont systemFontOfSize:11 weight:NSFontWeightRegular];
    self.statusBar.textColor = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
    self.statusBar.bezeled = NO;
    self.statusBar.drawsBackground = NO;
    self.statusBar.editable = NO;
    self.statusBar.selectable = NO;
    [self.visualEffectView addSubview:self.statusBar];
}

- (void)toggleWindow {
    if (self.isVisible) {
        [self dismissWindow];
    } else {
        [self presentWindow];
    }
}

- (void)presentWindow {
    // 1. Capture the currently focused app so we know where to paste English later!
    [[TextOutputManager sharedManager] captureTargetApplication];

    // 2. Center window on main screen
    NSScreen *screen = [NSScreen mainScreen];
    if (screen) {
        NSRect screenRect = screen.visibleFrame;
        CGFloat x = screenRect.origin.x + (screenRect.size.width - self.frame.size.width) / 2.0;
        CGFloat y = screenRect.origin.y + (screenRect.size.height - self.frame.size.height) * 0.65; // Slightly above center
        [self setFrameOrigin:NSMakePoint(x, y)];
    }

    [self makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self makeFirstResponder:self.inputField];

    // Pre-populate with current text or clear
    if (self.inputField.stringValue.length > 0) {
        [self queryTranslation:self.inputField.stringValue];
    }
}

- (void)dismissWindow {
    [self orderOut:nil];
}

#pragma mark - NSTextFieldDelegate & Key Events

- (void)controlTextDidChange:(NSNotification *)obj {
    NSString *query = self.inputField.stringValue;
    [self queryTranslation:query];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(insertNewline:)) {
        [self commitCurrentSelection];
        return YES;
    } else if (commandSelector == @selector(cancelOperation:)) {
        [self dismissWindow];
        return YES;
    } else if (commandSelector == @selector(moveUp:)) {
        [self.candidateView selectPrevious];
        return YES;
    } else if (commandSelector == @selector(moveDown:)) {
        [self.candidateView selectNext];
        return YES;
    }
    return NO;
}

- (void)queryTranslation:(NSString *)query {
    if (query.length == 0) {
        [self.candidateView updateCandidates:@[]];
        self.statusBar.stringValue = @"[↵] 确认首选 · [⌘1-7] 选词上屏 · [↑/↓] 切换 · [ESC] 取消";
        return;
    }

    self.statusBar.stringValue = @"正在智能翻译并拆解词汇...";

    __weak typeof(self) weakSelf = self;
    [[TranslationEngine sharedEngine] translate:query debounceMs:180 callback:^(NSString *q, NSArray<TranslationCandidate *> *candidates, BOOL fromCache, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (![strongSelf.inputField.stringValue isEqualToString:q]) {
            return; // Outdated query response
        }

        strongSelf.currentCandidates = candidates;
        [strongSelf.candidateView updateCandidates:candidates];

        if (candidates.count > 0) {
            strongSelf.statusBar.stringValue = [NSString stringWithFormat:@"匹配到 %lu 个候选翻译 · 按 [↵] 或 [⌘1-%lu] 选词上屏",
                                                (unsigned long)candidates.count,
                                                (unsigned long)MIN(candidates.count, 7)];
        } else {
            strongSelf.statusBar.stringValue = @"未找到候选词 · 请继续输入";
        }
    }];
}

- (void)commitCurrentSelection {
    TranslationCandidate *cand = [self.candidateView selectedCandidate];
    if (cand) {
        [self commitCandidate:cand];
    }
}

- (void)selectCandidateByNumber:(NSInteger)number {
    NSInteger idx = number - 1;
    TranslationCandidate *cand = [self.candidateView candidateAtIndex:idx];
    if (cand) {
        [self commitCandidate:cand];
    }
}

- (void)commitCandidate:(TranslationCandidate *)candidate {
    NSString *englishText = candidate.text;
    NSLog(@"[TranslationWindow] Selected candidate: %@", englishText);

    // Hide our window immediately so previous app gets focus
    [self dismissWindow];

    // Clear input field for next use
    self.inputField.stringValue = @"";
    [self.candidateView updateCandidates:@[]];

    // Commit English to target application!
    [[TextOutputManager sharedManager] commitEnglishText:englishText completion:^(BOOL success) {
        NSLog(@"[TranslationWindow] Committed text successfully: %d", success);
    }];
}

#pragma mark - CandidateViewDelegate

- (void)didSelectCandidate:(TranslationCandidate *)candidate index:(NSInteger)index {
    [self commitCandidate:candidate];
}

@end
