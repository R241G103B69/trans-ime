#import "TransInputController.h"

@implementation TransInputController

- (instancetype)initWithServer:(IMKServer *)server delegate:(id)delegate client:(id)inputClient {
    self = [super initWithServer:server delegate:delegate client:inputClient];
    if (self) {
        _compositionBuffer = [NSMutableString string];
        _currentCandidates = @[];

        // Initialize candidate window attached to this server
        _candidatesWindow = [[IMKCandidates alloc] initWithServer:server
                                                        panelType:kIMKSingleRowSteppingCandidatePanel
                                                            styleType:kIMKMain];
        [_candidatesWindow setDismissesAutomatically:YES];
    }
    return self;
}

- (BOOL)handleEvent:(NSEvent *)event client:(id)sender {
    if (event.type != NSEventTypeKeyDown) {
        return NO;
    }

    NSString *characters = event.characters;
    unsigned short keyCode = event.keyCode;

    // Check modifier flags (ignore if Command or Control is pressed)
    if ((event.modifierFlags & NSEventModifierFlagCommand) ||
        (event.modifierFlags & NSEventModifierFlagControl)) {
        return NO;
    }

    // 1. Backspace (KeyCode 51)
    if (keyCode == 51) {
        if (self.compositionBuffer.length > 0) {
            [self.compositionBuffer deleteCharactersInRange:NSMakeRange(self.compositionBuffer.length - 1, 1)];
            [self updateCompositionStateWithClient:sender];
            return YES;
        }
        return NO;
    }

    // 2. Space key (KeyCode 49) -> Commit Candidate 1 English
    if (keyCode == 49) {
        if (self.currentCandidates.count > 0) {
            [self commitCandidate:self.currentCandidates[0] client:sender];
            return YES;
        } else if (self.compositionBuffer.length > 0) {
            // Commit raw buffer as English
            [self commitRawBufferWithClient:sender];
            return YES;
        }
        return NO;
    }

    // 3. Return key (KeyCode 36) -> Commit raw buffer
    if (keyCode == 36) {
        if (self.compositionBuffer.length > 0) {
            [self commitRawBufferWithClient:sender];
            return YES;
        }
        return NO;
    }

    // 4. Number keys 1-9 -> Commit selected candidate's English
    if (characters.length == 1) {
        unichar c = [characters characterAtIndex:0];
        if (c >= '1' && c <= '9' && self.currentCandidates.count > 0) {
            NSInteger index = c - '1';
            if (index < self.currentCandidates.count) {
                [self commitCandidate:self.currentCandidates[index] client:sender];
                return YES;
            }
        }
    }

    // 5. Letter keys a-z -> Append to pinyin buffer
    if (characters.length == 1) {
        unichar c = [characters characterAtIndex:0];
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) {
            [self.compositionBuffer appendString:[characters lowercaseString]];
            [self updateCompositionStateWithClient:sender];
            return YES;
        }
    }

    return NO;
}

- (void)updateCompositionStateWithClient:(id)sender {
    if (self.compositionBuffer.length == 0) {
        [self.candidatesWindow hide];
        self.currentCandidates = @[];
        // Clear marked text in client application
        [sender setMarkedText:@""
               selectionRange:NSMakeRange(0, 0)
             replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
        return;
    }

    // Update marked text on client application
    NSDictionary *attr = @{
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
    };
    NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:self.compositionBuffer attributes:attr];
    [sender setMarkedText:attrStr
           selectionRange:NSMakeRange(self.compositionBuffer.length, 0)
         replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

    // Query candidates
    self.currentCandidates = [[PinyinEngine sharedEngine] candidatesForPinyin:self.compositionBuffer];

    if (self.currentCandidates.count > 0) {
        NSMutableArray<NSString *> *displayLabels = [NSMutableArray array];
        for (PinyinCandidate *c in self.currentCandidates) {
            [displayLabels addObject:[c displayLabel]];
        }
        [self.candidatesWindow updateCandidates];
        [self.candidatesWindow show:kIMKLocateCandidatesBelowHint];
    } else {
        [self.candidatesWindow hide];
    }
}

- (NSArray *)candidates:(id)sender {
    NSMutableArray<NSString *> *labels = [NSMutableArray array];
    for (PinyinCandidate *c in self.currentCandidates) {
        [labels addObject:[c displayLabel]];
    }
    return labels;
}

- (void)candidateSelected:(NSAttributedString *)candidateString {
    // Called when user clicks a candidate in IMKCandidates window
    NSString *label = [candidateString string];
    for (PinyinCandidate *c in self.currentCandidates) {
        if ([[c displayLabel] isEqualToString:label]) {
            [self commitCandidate:c client:[self client]];
            break;
        }
    }
}

- (void)commitCandidate:(PinyinCandidate *)candidate client:(id)client {
    // Core Translation Feature:
    // User typed pinyin -> saw Chinese -> selected candidate -> English text is inserted!
    NSString *englishText = candidate.english;

    [client insertText:englishText replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

    [self.compositionBuffer setString:@""];
    self.currentCandidates = @[];
    [self.candidatesWindow hide];
}

- (void)commitRawBufferWithClient:(id)client {
    NSString *raw = [self.compositionBuffer copy];
    [client insertText:raw replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    [self.compositionBuffer setString:@""];
    self.currentCandidates = @[];
    [self.candidatesWindow hide];
}

- (void)deactivateServer:(id)sender {
    [self.compositionBuffer setString:@""];
    self.currentCandidates = @[];
    [self.candidatesWindow hide];
    [super deactivateServer:sender];
}

@end
