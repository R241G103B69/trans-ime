#import "AppDelegate.h"
#import "TranslationWindow.h"
#import "LocalDictionary.h"
#import "TranslationEngine.h"
#import <Carbon/Carbon.h>

static OSStatus HotKeyHandler(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
    EventHotKeyID hkID;
    GetEventParameter(theEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(hkID), NULL, &hkID);
    if (hkID.id == 1) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[TranslationWindow sharedWindow] toggleWindow];
        });
    }
    return noErr;
}

@implementation AppDelegate {
    EventHotKeyRef _hotKeyRef;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSLog(@"[TransType] Application launched successfully.");

    // 1. Hide from Dock and run as MenuBar accessory
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    // 2. Load Local Dictionary
    NSString *dictPath = [[NSBundle mainBundle] pathForResource:@"dictionary" ofType:@"json"];
    if (!dictPath) {
        // Fallback for development / command-line execution
        NSString *currentDir = [[NSFileManager defaultManager] currentDirectoryPath];
        dictPath = [currentDir stringByAppendingPathComponent:@"src/macos-app/Resources/dictionary.json"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dictPath]) {
            dictPath = @"/Users/a255255255/.gemini/antigravity/scratch/trans-ime/src/macos-app/Resources/dictionary.json";
        }
    }
    [[LocalDictionary sharedDictionary] loadFromJSONPath:dictPath];

    // 3. Setup Status Bar Item
    [self setupStatusBar];

    // 4. Register Global Hotkey: Option + Space
    [self registerGlobalHotkey];

    // 5. Pre-warm window
    [TranslationWindow sharedWindow];
}

- (void)setupStatusBar {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"[译] TransType";

    NSMenu *menu = [[NSMenu alloc] init];

    NSMenuItem *showItem = [[NSMenuItem alloc] initWithTitle:@"呼出翻译输入法 (⌥ Space)"
                                                      action:@selector(showTranslationWindow)
                                               keyEquivalent:@""];
    [menu addItem:showItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *langItem = [[NSMenuItem alloc] initWithTitle:@"输出语言: 英语 (English)"
                                                      action:nil
                                               keyEquivalent:@""];
    langItem.enabled = NO;
    [menu addItem:langItem];

    NSMenuItem *statusDesc = [[NSMenuItem alloc] initWithTitle:@"核心功能: 输入中文选词 -> 自动输出英文"
                                                        action:nil
                                                 keyEquivalent:@""];
    statusDesc.enabled = NO;
    [menu addItem:statusDesc];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"退出 TransType"
                                                      action:@selector(quitApp)
                                               keyEquivalent:@"q"];
    [menu addItem:quitItem];

    self.statusItem.menu = menu;
}

- (void)registerGlobalHotkey {
    EventTypeSpec eventType;
    eventType.eventClass = kEventClassKeyboard;
    eventType.eventKind = kEventHotKeyPressed;

    InstallApplicationEventHandler(&HotKeyHandler, 1, &eventType, NULL, NULL);

    EventHotKeyID hotKeyID;
    hotKeyID.signature = 'TRNS';
    hotKeyID.id = 1;

    // Option + Space: optionKey modifier = 0x0800, Space keycode = 49 (0x31)
    UInt32 hotKeyCode = 49;
    UInt32 hotKeyModifiers = optionKey;

    OSStatus status = RegisterEventHotKey(hotKeyCode, hotKeyModifiers, hotKeyID, GetApplicationEventTarget(), 0, &_hotKeyRef);
    if (status == noErr) {
        NSLog(@"[TransType] Global HotKey (Option + Space) registered successfully!");
    } else {
        NSLog(@"[TransType] Failed to register global hotkey (status: %d)", status);
    }
}

- (void)showTranslationWindow {
    [[TranslationWindow sharedWindow] presentWindow];
}

- (void)quitApp {
    [NSApp terminate:nil];
}

@end
