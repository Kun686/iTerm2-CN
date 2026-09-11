//
//  iTermKeyBindingAction.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 3/21/20.
//

#import "iTermKeyBindingAction.h"

#import "DebugLogging.h"
#import "iTerm2SharedARC-Swift.h"
#import "ITAddressBookMgr.h"
#import "iTermPasteSpecialViewController.h"
#import "iTermSnippetsModel.h"
#import "NSArray+iTerm.h"
#import "NSDictionary+iTerm.h"
#import "PTYTextView.h"  // just for PTYTextViewSelectionExtensionUnit
#import "ProfileModel.h"

NSString *const iTermKeyBindingDictionaryKeyAction = @"Action";
NSString *const iTermKeyBindingDictionaryKeyParameter = @"Text";
NSString *const iTermKeyBindingDictionaryKeyLabel = @"Label";
NSString *const iTermKeyBindingDictionaryKeyVersion = @"Version";
NSString *const iTermKeyBindingDictionaryKeyEscaping = @"Escaping";
NSString *const iTermKeyBindingDictionaryKeyApplyMode = @"Apply Mode";


static NSString *GetProfileName(NSString *guid) {
    return [[[ProfileModel sharedInstance] bookmarkWithGuid:guid] objectForKey:KEY_NAME];
}

@implementation iTermKeyBindingAction {
    NSDictionary *_dictionary;
}

+ (NSString *)escapedText:(NSString *)text mode:(iTermSendTextEscaping)escaping {
    NSString *temp = text;
    switch (escaping) {
        case iTermSendTextEscapingNone:
            return text;
        case iTermSendTextEscapingCommon:
            return [temp stringByReplacingCommonlyEscapedCharactersWithControls];
        case iTermSendTextEscapingCompatibility:
            temp = [temp stringByReplacingEscapedChar:'n' withString:@"\n"];
            temp = [temp stringByReplacingEscapedChar:'e' withString:@"\e"];
            temp = [temp stringByReplacingEscapedChar:'a' withString:@"\a"];
            temp = [temp stringByReplacingEscapedChar:'t' withString:@"\t"];
            return temp;
        case iTermSendTextEscapingVimAndCompatibility:
            temp = [temp stringByExpandingVimSpecialCharacters];
            temp = [temp stringByReplacingEscapedChar:'n' withString:@"\n"];
            temp = [temp stringByReplacingEscapedChar:'e' withString:@"\e"];
            temp = [temp stringByReplacingEscapedChar:'a' withString:@"\a"];
            temp = [temp stringByReplacingEscapedChar:'t' withString:@"\t"];
            return temp;
        case iTermSendTextEscapingVim:
            return [temp stringByExpandingVimSpecialCharacters];
    }
    assert(NO);
    return @"";
}


+ (instancetype)fromString:(NSString *)string {
    NSData *decoded = [[NSData alloc] initWithBase64EncodedString:string options:0];
    if (!decoded) {
        return nil;
    }
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:decoded options:0 error:nil];
    if (!dict) {
        return nil;
    }
    return [self withDictionary:dict];
}

- (NSString *)stringValue {
    NSDictionary *dict = [self dictionaryValue];
    if (!dict) {
        return nil;
    }
    NSData *json = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    if (!json) {
        return nil;
    }
    NSData *data = [json base64EncodedDataWithOptions:0];
    if (!data) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (instancetype)withDictionary:(NSDictionary *)dictionary {
    return [[self alloc] initWithDictionary:dictionary];
}

+ (instancetype)withAction:(KEY_ACTION)action
                 parameter:(NSString *)parameter
                  escaping:(iTermSendTextEscaping)escaping
                 applyMode:(iTermActionApplyMode)applyMode {
    return [[self alloc] initWithDictionary:@{ iTermKeyBindingDictionaryKeyAction: @(action),
                                               iTermKeyBindingDictionaryKeyParameter: parameter ?: @"",
                                               iTermKeyBindingDictionaryKeyVersion: @2,
                                               iTermKeyBindingDictionaryKeyEscaping: @(escaping),
                                               iTermKeyBindingDictionaryKeyApplyMode: @(applyMode)
    }];
}

+ (instancetype)withAction:(KEY_ACTION)action
                 parameter:(NSString *)parameter
                     label:(NSString *)label
                  escaping:(iTermSendTextEscaping)escaping
                 applyMode:(iTermActionApplyMode)applyMode {
    if (label) {
        return [[self alloc] initWithDictionary:@{ iTermKeyBindingDictionaryKeyAction: @(action),
                                                   iTermKeyBindingDictionaryKeyParameter: parameter ?: @"",
                                                   iTermKeyBindingDictionaryKeyLabel: label,
                                                   iTermKeyBindingDictionaryKeyVersion: @2,
                                                   iTermKeyBindingDictionaryKeyEscaping: @(escaping),
                                                   iTermKeyBindingDictionaryKeyApplyMode: @(applyMode)
        }];
    } else {
        return [[self alloc] initWithDictionary:@{ iTermKeyBindingDictionaryKeyAction: @(action),
                                                   iTermKeyBindingDictionaryKeyParameter: parameter ?: @"",
                                                   iTermKeyBindingDictionaryKeyVersion: @2,
                                                   iTermKeyBindingDictionaryKeyEscaping: @(escaping),
                                                   iTermKeyBindingDictionaryKeyApplyMode: @(applyMode)
        }];
    }
}

+ (NSString *)stringForSelectionMovementUnit:(PTYTextViewSelectionExtensionUnit)unit {
    switch (unit) {
        case kPTYTextViewSelectionExtensionUnitLine:
            return NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.by_line.4336aa4e", nil, NSBundle.mainBundle, @"By Line", @"Selection movement unit.");
        case kPTYTextViewSelectionExtensionUnitCharacter:
            return NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.by_character.cb408196", nil, NSBundle.mainBundle, @"By Character", @"Selection movement unit.");
        case kPTYTextViewSelectionExtensionUnitWord:
            return NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.by_word.0c427b55", nil, NSBundle.mainBundle, @"By Word", @"Selection movement unit.");
        case kPTYTextViewSelectionExtensionUnitBigWord:
            return NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.by_word.9bc5ed38", nil, NSBundle.mainBundle, @"By WORD", @"Selection movement unit. WORD is the Vim concept.");
        case kPTYTextViewSelectionExtensionUnitMark:
            return NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.by_mark.5cc4083a", nil, NSBundle.mainBundle, @"By Mark", @"Selection movement unit.");
    }
    XLog(@"Unrecognized selection movement unit %@", @(unit));
    return @"";
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if (dictionary != nil && ![dictionary isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    self = [super init];
    if (self) {
        _keyAction = [dictionary[iTermKeyBindingDictionaryKeyAction] intValue];
        _parameter = [dictionary[iTermKeyBindingDictionaryKeyParameter] ?: @"" copy];
        _label = [dictionary[iTermKeyBindingDictionaryKeyLabel] ?: @"" copy];
        _applyMode = [dictionary[iTermKeyBindingDictionaryKeyApplyMode] unsignedIntegerValue];

        const int version = [dictionary[iTermKeyBindingDictionaryKeyVersion] intValue];
        if (version == 0) {
            _escaping = iTermSendTextEscapingCompatibility;
        } else if (version == 1) {
            _escaping = iTermSendTextEscapingCommon;
        } else {
            _escaping = [dictionary[iTermKeyBindingDictionaryKeyEscaping] unsignedIntegerValue];
        }
        _dictionary = [dictionary copy];
    }
    return self;
}

- (NSDictionary *)dictionaryValue {
    if (_dictionary) {
        return _dictionary;
    }
    // This is complicated because it wants to avoid changing the dictionary unless it is necessary.
    int version;
    id escaping;
    switch (_escaping) {
        case iTermSendTextEscapingCompatibility:
            version = 0;
            escaping = [NSNull null];
            break;
        case iTermSendTextEscapingCommon:
            version = 1;
            escaping = [NSNull null];
            break;
        default:
            version = 2;
            escaping = @(_escaping);
            break;
    }
    NSDictionary *temp = @{ iTermKeyBindingDictionaryKeyAction: @(_keyAction),
                            iTermKeyBindingDictionaryKeyParameter: _parameter ?: @"",
                            iTermKeyBindingDictionaryKeyLabel: _label ?: [NSNull null],
                            iTermKeyBindingDictionaryKeyVersion: @(version),
                            iTermKeyBindingDictionaryKeyEscaping: escaping,
                            iTermKeyBindingDictionaryKeyApplyMode: @(_applyMode)
    };
    return [temp dictionaryByRemovingNullValues];
}

- (iTermSendTextEscaping)vimEscaping {
    switch (_escaping) {
        case iTermSendTextEscapingNone:
        case iTermSendTextEscapingCommon:
        case iTermSendTextEscapingVim:
            return iTermSendTextEscapingVim;
        case iTermSendTextEscapingCompatibility:
        case iTermSendTextEscapingVimAndCompatibility:
            return iTermSendTextEscapingVimAndCompatibility;
    }
}

- (NSString *)displayName {
    NSString *actionString = nil;

    switch (_keyAction) {
        case KEY_ACTION_MOVE_TAB_LEFT:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.move_tab_left.42478433", nil, NSBundle.mainBundle, @"Move Tab Left", @"Key-binding action name.");
            break;
        case KEY_ACTION_MOVE_TAB_RIGHT:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.move_tab_right.8b396b2f", nil, NSBundle.mainBundle, @"Move Tab Right", @"Key-binding action name.");
            break;
        case KEY_ACTION_NEXT_MRU_TAB:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.cycle_tabs_forward.b32ee6f9", nil, NSBundle.mainBundle, @"Cycle Tabs Forward", @"Key-binding action name.");
            break;
        case KEY_ACTION_PREVIOUS_MRU_TAB:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.cycle_tabs_backward.749377ea", nil, NSBundle.mainBundle, @"Cycle Tabs Backward", @"Key-binding action name.");
            break;
        case KEY_ACTION_NEXT_PANE:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.next_pane.1dd89542", nil, NSBundle.mainBundle, @"Next Pane", @"Key-binding action name.");
            break;
        case KEY_ACTION_PREVIOUS_PANE:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.previous_pane.b8a94609", nil, NSBundle.mainBundle, @"Previous Pane", @"Key-binding action name.");
            break;
        case KEY_ACTION_NEXT_SESSION:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.next_tab.a9426fb3", nil, NSBundle.mainBundle, @"Next Tab", @"Key-binding action name.");
            break;
        case KEY_ACTION_NEXT_WINDOW:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.next_window.95bf685f", nil, NSBundle.mainBundle, @"Next Window", @"Key-binding action name.");
            break;
        case KEY_ACTION_PREVIOUS_SESSION:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.previous_tab.80f06bdc", nil, NSBundle.mainBundle, @"Previous Tab", @"Key-binding action name.");
            break;
        case KEY_ACTION_PREVIOUS_WINDOW:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.previous_window.4c8b1a6d", nil, NSBundle.mainBundle, @"Previous Window", @"Key-binding action name.");
            break;
        case KEY_ACTION_SCROLL_END:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.scroll_to_end.ca74a991", nil, NSBundle.mainBundle, @"Scroll To End", @"Key-binding action name.");
            break;
        case KEY_ACTION_SCROLL_HOME:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.scroll_to_top.81fcba37", nil, NSBundle.mainBundle, @"Scroll To Top", @"Key-binding action name.");
            break;
        case KEY_ACTION_SCROLL_LINE_DOWN:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.scroll_one_line_down.64145602", nil, NSBundle.mainBundle, @"Scroll One Line Down", @"Key-binding action name.");
            break;
        case KEY_ACTION_SCROLL_LINE_UP:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.scroll_one_line_up.1f23d92d", nil, NSBundle.mainBundle, @"Scroll One Line Up", @"Key-binding action name.");
            break;
        case KEY_ACTION_SCROLL_PAGE_DOWN:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.scroll_one_page_down.c5172032", nil, NSBundle.mainBundle, @"Scroll One Page Down", @"Key-binding action name.");
            break;
        case KEY_ACTION_SCROLL_PAGE_UP:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.scroll_one_page_up.002851cd", nil, NSBundle.mainBundle, @"Scroll One Page Up", @"Key-binding action name.");
            break;
        case KEY_ACTION_ESCAPE_SEQUENCE:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.send.9327d569", nil, NSBundle.mainBundle, @"Send ^[ %@", @"Key-binding action summary. Preserve the escape notation and placeholder."), _parameter];
            break;
        case KEY_ACTION_HEX_CODE:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.send_hex_codes.ae255749", nil, NSBundle.mainBundle, @"Send Hex Codes: %@", @"Key-binding action summary. Preserve the placeholder."), _parameter];
            break;
        case KEY_ACTION_VIM_TEXT:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.send.7b2f6b4e", nil, NSBundle.mainBundle, @"Send: \"%@\"", @"Key-binding action summary. Preserve the placeholder."), _parameter];
            break;
        case KEY_ACTION_VIM_TEXT_NO_BROADCAST:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.send_no_broadcast.24f39209", nil, NSBundle.mainBundle, @"Send (no broadcast): \"%@\"", @"Key-binding action summary. Preserve the placeholder."), _parameter];
            break;
        case KEY_ACTION_TEXT:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.send.7b2f6b4e", nil, NSBundle.mainBundle, @"Send: \"%@\"", @"Key-binding action summary. Preserve the placeholder."), _parameter];
            break;
        case KEY_ACTION_SEND_SNIPPET: {
            iTermSnippet *snippet = [[iTermSnippetsModel sharedInstance] snippetWithActionKey:_parameter];
            if (snippet) {
                actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.send_snippet.186b12f4", nil, NSBundle.mainBundle, @"Send Snippet “%@”", @"Key-binding action summary. Preserve the placeholder."), snippet.displayTitle];
            } else {
                actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.send_deleted_snippet_no_action.4c2fc4ad", nil, NSBundle.mainBundle, @"Send Deleted Snippet (no action)", @"Key-binding action name.");
            }
            break;
        }
        case KEY_ACTION_COMPOSE:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.compose.4712ae1a", nil, NSBundle.mainBundle, @"Compose “%@”", @"Key-binding action summary. Preserve the placeholder."), _parameter];
            break;
        case KEY_ACTION_SEND_TMUX_COMMAND:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.tmux.e1bd14ba", nil, NSBundle.mainBundle, @"tmux: %@", @"Key-binding action summary. Preserve the product name and placeholder."), _parameter];
            break;
        case KEY_ACTION_RUN_COPROCESS:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.run_coprocess.fa0ddee1", nil, NSBundle.mainBundle, @"Run Coprocess \"%@\"", @"Key-binding action summary. Preserve the placeholder."),
                            _parameter];
            break;
        case KEY_ACTION_SELECT_MENU_ITEM: {
            NSArray *parts = [_parameter componentsSeparatedByString:@"\n"];
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.select_menu_item.a31db23f", nil, NSBundle.mainBundle, @"Select Menu Item “%@”", @"Key-binding action summary. Preserve the placeholder."), parts.firstObject];
            break;
        }
        case KEY_ACTION_NEW_WINDOW_WITH_PROFILE:
            if ([[ProfileModel sharedInstance] bookmarkWithGuid:_parameter]) {
                actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.new_window_with_profile.8937cbe6", nil, NSBundle.mainBundle, @"New Window with \"%@\" Profile", @"Key-binding action summary. Preserve the placeholder."), GetProfileName(_parameter)];
            } else {
                actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.new_window_with_unavailable_profile.f9a61f65", nil, NSBundle.mainBundle, @"New Window with unavailable Profile", @"Key-binding action name.");
            }
            break;
        case KEY_ACTION_NEW_TAB_WITH_PROFILE:
            if ([[ProfileModel sharedInstance] bookmarkWithGuid:_parameter]) {
                actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.new_tab_with_profile.818dbd1f", nil, NSBundle.mainBundle, @"New Tab with \"%@\" Profile", @"Key-binding action summary. Preserve the placeholder."), GetProfileName(_parameter)];
            } else {
                actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.new_tab_with_unavailable_profile.bf8f8411", nil, NSBundle.mainBundle, @"New Tab with unavailable Profile", @"Key-binding action name.");
            }
            break;
        case KEY_ACTION_SPLIT_HORIZONTALLY_WITH_PROFILE:
            if ([[ProfileModel sharedInstance] bookmarkWithGuid:_parameter]) {
                actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.split_horizontally_with_profile.975f68dc", nil, NSBundle.mainBundle, @"Split Horizontally with \"%@\" Profile", @"Key-binding action summary. Preserve the placeholder."), GetProfileName(_parameter)];
            } else {
                actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.split_horizontally_with_unavailable_profile.2182e913", nil, NSBundle.mainBundle, @"Split Horizontally with unavailable Profile", @"Key-binding action name.");
            }
            break;
        case KEY_ACTION_SPLIT_VERTICALLY_WITH_PROFILE:
            if ([[ProfileModel sharedInstance] bookmarkWithGuid:_parameter]) {
                actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.split_vertically_with_profile.311acdfb", nil, NSBundle.mainBundle, @"Split Vertically with \"%@\" Profile", @"Key-binding action summary. Preserve the placeholder."), GetProfileName(_parameter)];
            } else {
                actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.split_vertically_with_unavailable_profile.9566c2d5", nil, NSBundle.mainBundle, @"Split Vertically with unavailable Profile", @"Key-binding action name.");
            }
            break;
        case KEY_ACTION_SET_PROFILE:
            if ([[ProfileModel sharedInstance] bookmarkWithGuid:_parameter]) {
                actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.change_profile_to.e5b0b9ee", nil, NSBundle.mainBundle, @"Change Profile to \"%@\"", @"Key-binding action summary. Preserve the placeholder."), GetProfileName(_parameter)];
            } else {
                actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.change_profile_to_unavailable_profile.97d7234c", nil, NSBundle.mainBundle, @"Change Profile to unavailable profile", @"Key-binding action name.");
            }
            break;
        case KEY_ACTION_LOAD_COLOR_PRESET:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.load_color_preset.d37293c7", nil, NSBundle.mainBundle, @"Load Color Preset \"%@\"", @"Key-binding action summary. Preserve the placeholder."), _parameter];
            break;
        case KEY_ACTION_SEND_C_H_BACKSPACE:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.send_h_backspace.7cf14960", nil, NSBundle.mainBundle, @"Send ^H Backspace", @"Key-binding action name. Preserve the control notation.");
            break;
        case KEY_ACTION_SEND_C_QM_BACKSPACE:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.send_backspace.b17426b3", nil, NSBundle.mainBundle, @"Send ^? Backspace", @"Key-binding action name. Preserve the control notation.");
            break;
        case KEY_ACTION_IGNORE:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.ignore.fce77c34", nil, NSBundle.mainBundle, @"Ignore", @"Key-binding action name.");
            break;
        case KEY_ACTION_BYPASS:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.bypass_terminal.27a888be", nil, NSBundle.mainBundle, @"Bypass Terminal", @"Key-binding action name.");
            break;
        case KEY_ACTION_IR_FORWARD:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.unsupported_command.99c5ba0b", nil, NSBundle.mainBundle, @"Unsupported Command", @"Key-binding action name.");
            break;
        case KEY_ACTION_IR_BACKWARD:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.start_instant_replay.6c86b391", nil, NSBundle.mainBundle, @"Start Instant Replay", @"Key-binding action name.");
            break;
        case KEY_ACTION_SELECT_PANE_LEFT:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.select_split_pane_on_left.da872877", nil, NSBundle.mainBundle, @"Select Split Pane on Left", @"Key-binding action name.");
            break;
        case KEY_ACTION_SELECT_PANE_RIGHT:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.select_split_pane_on_right.baf27ce7", nil, NSBundle.mainBundle, @"Select Split Pane on Right", @"Key-binding action name.");
            break;
        case KEY_ACTION_SELECT_PANE_ABOVE:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.select_split_pane_above.b60f03fb", nil, NSBundle.mainBundle, @"Select Split Pane Above", @"Key-binding action name.");
            break;
        case KEY_ACTION_SELECT_PANE_BELOW:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.select_split_pane_below.2bd6f4a7", nil, NSBundle.mainBundle, @"Select Split Pane Below", @"Key-binding action name.");
            break;
        case KEY_ACTION_DO_NOT_REMAP_MODIFIERS:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.do_not_remap_modifiers.9756b026", nil, NSBundle.mainBundle, @"Do Not Remap Modifiers", @"Key-binding action name.");
            break;
        case KEY_ACTION_REMAP_LOCALLY:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.remap_modifiers_in_iterm2_only.19633a74", nil, NSBundle.mainBundle, @"Remap Modifiers in iTerm2 Only", @"Key-binding action name.");
            break;
        case KEY_ACTION_TOGGLE_FULLSCREEN:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.toggle_fullscreen.4fdafad2", nil, NSBundle.mainBundle, @"Toggle Fullscreen", @"Key-binding action name.");
            break;
        case KEY_ACTION_TOGGLE_HOTKEY_WINDOW_PINNING:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.toggle_pin_hotkey_window.37c3862a", nil, NSBundle.mainBundle, @"Toggle Pin Hotkey Window", @"Key-binding action name.");
            break;
        case KEY_ACTION_UNDO:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.undo.a8283ade", nil, NSBundle.mainBundle, @"Undo", @"Key-binding action name.");
            break;
        case KEY_ACTION_FIND_REGEX:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.find_regex.8c2369d8", nil, NSBundle.mainBundle, @"Find Regex “%@”", @"Key-binding action summary. Preserve the placeholder."), _parameter];
            break;
        case KEY_FIND_AGAIN_DOWN:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.find_again_down.98179375", nil, NSBundle.mainBundle, @"Find Again Down", @"Key-binding action name.");
            break;
        case KEY_FIND_AGAIN_UP:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.find_again_up.a4731f6f", nil, NSBundle.mainBundle, @"Find Again Up", @"Key-binding action name.");
            break;
        case KEY_ACTION_PASTE_SPECIAL_FROM_SELECTION: {
            NSString *pasteDetails =
                [iTermPasteSpecialViewController descriptionForCodedSettings:_parameter];
            if (pasteDetails.length) {
                actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.paste_from_selection.61ccb434", nil, NSBundle.mainBundle, @"Paste from Selection: %@", @"Key-binding action summary. Preserve the placeholder."), pasteDetails];
            } else {
                actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.paste_from_selection.6307d5f3", nil, NSBundle.mainBundle, @"Paste from Selection", @"Key-binding action name.");
            }
            break;
        }
        case KEY_ACTION_PASTE_SPECIAL: {
            NSString *pasteDetails =
                [iTermPasteSpecialViewController descriptionForCodedSettings:_parameter];
            if (pasteDetails.length) {
                actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.paste.73421a3f", nil, NSBundle.mainBundle, @"Paste: %@", @"Key-binding action summary. Preserve the placeholder."), pasteDetails];
            } else {
                actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.paste.f3380f7b", nil, NSBundle.mainBundle, @"Paste", @"Key-binding action name.");
            }
            break;
        }
        case KEY_ACTION_MOVE_END_OF_SELECTION_LEFT:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.move_end_of_selection_left.36b97619", nil, NSBundle.mainBundle, @"Move End of Selection Left %@", @"Key-binding action summary. Preserve the placeholder."),
                            [self.class stringForSelectionMovementUnit:_parameter.integerValue]];
            break;
        case KEY_ACTION_MOVE_END_OF_SELECTION_RIGHT:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.move_end_of_selection_right.fa00d0e6", nil, NSBundle.mainBundle, @"Move End of Selection Right %@", @"Key-binding action summary. Preserve the placeholder."),
                            [self.class stringForSelectionMovementUnit:_parameter.integerValue]];
            break;
        case KEY_ACTION_MOVE_START_OF_SELECTION_LEFT:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.move_start_of_selection_left.7750e946", nil, NSBundle.mainBundle, @"Move Start of Selection Left %@", @"Key-binding action summary. Preserve the placeholder."),
                            [self.class stringForSelectionMovementUnit:_parameter.integerValue]];
            break;
        case KEY_ACTION_MOVE_START_OF_SELECTION_RIGHT:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.move_start_of_selection_right.89927be0", nil, NSBundle.mainBundle, @"Move Start of Selection Right %@", @"Key-binding action summary. Preserve the placeholder."),
                            [self.class stringForSelectionMovementUnit:_parameter.integerValue]];
            break;

        case KEY_ACTION_DECREASE_HEIGHT:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.decrease_height.08015d85", nil, NSBundle.mainBundle, @"Decrease Height", @"Key-binding action name.");
            break;
        case KEY_ACTION_INCREASE_HEIGHT:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.increase_height.7dfa9645", nil, NSBundle.mainBundle, @"Increase Height", @"Key-binding action name.");
            break;

        case KEY_ACTION_DECREASE_WIDTH:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.decrease_width.d5c88ec3", nil, NSBundle.mainBundle, @"Decrease Width", @"Key-binding action name.");
            break;
        case KEY_ACTION_INCREASE_WIDTH:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.increase_width.09496d0d", nil, NSBundle.mainBundle, @"Increase Width", @"Key-binding action name.");
            break;

        case KEY_ACTION_SWAP_PANE_LEFT:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.swap_with_split_pane_on_left.4e404f60", nil, NSBundle.mainBundle, @"Swap With Split Pane on Left", @"Key-binding action name.");
            break;
        case KEY_ACTION_SWAP_PANE_RIGHT:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.swap_with_split_pane_on_right.81e944b5", nil, NSBundle.mainBundle, @"Swap With Split Pane on Right", @"Key-binding action name.");
            break;
        case KEY_ACTION_SWAP_PANE_ABOVE:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.swap_with_split_pane_above.2449d669", nil, NSBundle.mainBundle, @"Swap With Split Pane Above", @"Key-binding action name.");
            break;
        case KEY_ACTION_SWAP_PANE_BELOW:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.swap_with_split_pane_below.c5868c4c", nil, NSBundle.mainBundle, @"Swap With Split Pane Below", @"Key-binding action name.");
            break;
        case KEY_ACTION_TOGGLE_MOUSE_REPORTING:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.toggle_mouse_reporting.d753135a", nil, NSBundle.mainBundle, @"Toggle Mouse Reporting", @"Key-binding action name.");
            break;
        case KEY_ACTION_INVOKE_SCRIPT_FUNCTION:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.call.92b9a55f", nil, NSBundle.mainBundle, @"Call %@", @"Key-binding action summary. Preserve the placeholder."), _parameter];
            break;
        case KEY_ACTION_DUPLICATE_TAB:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.duplicate_tab.57d3ddba", nil, NSBundle.mainBundle, @"Duplicate Tab", @"Key-binding action name.");
            break;
        case KEY_ACTION_SEQUENCE: {
            NSArray<NSString *> *names = [[_parameter keyBindingActionsFromSequenceParameter] mapWithBlock:^id _Nullable(iTermKeyBindingAction * _Nonnull action) {
                return [action displayName];
            }];
            return [names componentsJoinedByString:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.then.6b6fbf17", nil, NSBundle.mainBundle, @", then ", @"Separator between sequential key-binding action names.")];
        }
        default:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.unknown_action_id_d.e2fe4b6a", nil, NSBundle.mainBundle, @"Unknown Action ID %d", @"Unknown key-binding action summary. Preserve the placeholder."), _keyAction];
            break;
        case KEY_ACTION_MOVE_TO_SPLIT_PANE:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.move_to_split_pane.e1c492f3", nil, NSBundle.mainBundle, @"Move to Split Pane", @"Key-binding action name.");
            break;
        case KEY_ACTION_SWAP_WITH_NEXT_PANE:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.swap_with_next_pane.5b677b49", nil, NSBundle.mainBundle, @"Swap with Next Pane", @"Key-binding action name.");
            break;
        case KEY_ACTION_SWAP_WITH_PREVIOUS_PANE:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.swap_with_previous_pane.b97eb72a", nil, NSBundle.mainBundle, @"Swap with Previous Pane", @"Key-binding action name.");
            break;
        case KEY_ACTION_COPY_OR_SEND:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.copy_selection_or_send_c.4be313bd", nil, NSBundle.mainBundle, @"Copy Selection or Send ^C", @"Key-binding action name. Preserve the control notation.");
            break;
        case KEY_ACTION_PASTE_OR_SEND:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.paste_or_send_v.4aca639b", nil, NSBundle.mainBundle, @"Paste or Send ^V", @"Key-binding action name. Preserve the control notation.");
            break;
        case KEY_ACTION_ALERT_ON_NEXT_MARK:
            actionString = NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.alert_on_next_mark.a46bce90", nil, NSBundle.mainBundle, @"Alert on Next Mark", @"Key-binding action name.");
            break;
        case KEY_ACTION_COPY_INTERPOLATED_STRING:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.copy_interpolated_string.f2c24722", nil, NSBundle.mainBundle, @"Copy Interpolated String “%@”", @"Key-binding action summary. Preserve the placeholder."), _parameter];
            break;
        case KEY_ACTION_COPY_MODE:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.copy_mode.0d6f5b64", nil, NSBundle.mainBundle, @"Copy mode: %@", @"Key-binding action summary. Preserve the placeholder."), _parameter];
            break;
        case KEY_ACTION_TOGGLE_SETTING:
            actionString = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.toggle.c43c797d", nil, NSBundle.mainBundle, @"Toggle %@", @"Key-binding action summary. Preserve the placeholder."), self.toggleSettingLabel];
            break;
    }

    switch (self.applyMode) {
        case iTermActionApplyModeCurrentSession:
            return actionString;
        case iTermActionApplyModeAllSessions:
            return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.in_all_sessions.1abd8a1a", nil, NSBundle.mainBundle, @"In all sessions, %@", @"Key-binding apply-mode summary. Preserve the placeholder."), actionString];
        case iTermActionApplyModeUnfocusedSessions:
            return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.in_unfocused_sessions.4058c7aa", nil, NSBundle.mainBundle, @"In unfocused sessions, %@", @"Key-binding apply-mode summary. Preserve the placeholder."), actionString];
        case iTermActionApplyModeAllInWindow:
            return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.in_all_sessions_in_the_window.04bae524", nil, NSBundle.mainBundle, @"In all sessions in the window, %@", @"Key-binding apply-mode summary. Preserve the placeholder."), actionString];
        case iTermActionApplyModeAllInTab:
            return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.in_all_sessions_in_the_tab.8e2d4c2c", nil, NSBundle.mainBundle, @"In all sessions in the tab, %@", @"Key-binding apply-mode summary. Preserve the placeholder."), actionString];
        case iTermActionApplyModeBroadcasting:
            return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.keyboard.itermkeybindingaction.in_all_broadcasted_to_sessions.cff82dc9", nil, NSBundle.mainBundle, @"In all broadcasted-to sessions, %@", @"Key-binding apply-mode summary. Preserve the placeholder."), actionString];
    }
    return actionString;
}

- (BOOL)sendsText {
    switch (self.keyAction) {
        case KEY_ACTION_ESCAPE_SEQUENCE:
        case KEY_ACTION_HEX_CODE:
        case KEY_ACTION_TEXT:
        case KEY_ACTION_SEND_SNIPPET:
        case KEY_ACTION_COMPOSE:
        case KEY_ACTION_SEND_TMUX_COMMAND:
        case KEY_ACTION_VIM_TEXT:
        case KEY_ACTION_VIM_TEXT_NO_BROADCAST:
        case KEY_ACTION_RUN_COPROCESS:
        case KEY_ACTION_SEND_C_H_BACKSPACE:
        case KEY_ACTION_SEND_C_QM_BACKSPACE:
        case KEY_ACTION_PASTE_SPECIAL:
        case KEY_ACTION_PASTE_SPECIAL_FROM_SELECTION:
        case KEY_ACTION_COPY_OR_SEND:
        case KEY_ACTION_PASTE_OR_SEND:
            return YES;
            
        case KEY_ACTION_IGNORE:
        case KEY_ACTION_BYPASS:
        case KEY_ACTION_INVALID:
        case KEY_ACTION_NEXT_SESSION:
        case KEY_ACTION_NEXT_WINDOW:
        case KEY_ACTION_PREVIOUS_SESSION:
        case KEY_ACTION_PREVIOUS_WINDOW:
        case KEY_ACTION_SCROLL_END:
        case KEY_ACTION_SCROLL_HOME:
        case KEY_ACTION_SCROLL_LINE_DOWN:
        case KEY_ACTION_SCROLL_LINE_UP:
        case KEY_ACTION_SCROLL_PAGE_DOWN:
        case KEY_ACTION_SCROLL_PAGE_UP:
        case KEY_ACTION_IR_FORWARD:
        case KEY_ACTION_IR_BACKWARD:
        case KEY_ACTION_SELECT_PANE_LEFT:
        case KEY_ACTION_SELECT_PANE_RIGHT:
        case KEY_ACTION_SELECT_PANE_ABOVE:
        case KEY_ACTION_SELECT_PANE_BELOW:
        case KEY_ACTION_DO_NOT_REMAP_MODIFIERS:
        case KEY_ACTION_TOGGLE_FULLSCREEN:
        case KEY_ACTION_REMAP_LOCALLY:
        case KEY_ACTION_SELECT_MENU_ITEM:
        case KEY_ACTION_NEW_WINDOW_WITH_PROFILE:
        case KEY_ACTION_NEW_TAB_WITH_PROFILE:
        case KEY_ACTION_SPLIT_HORIZONTALLY_WITH_PROFILE:
        case KEY_ACTION_SPLIT_VERTICALLY_WITH_PROFILE:
        case KEY_ACTION_NEXT_PANE:
        case KEY_ACTION_PREVIOUS_PANE:
        case KEY_ACTION_NEXT_MRU_TAB:
        case KEY_ACTION_MOVE_TAB_LEFT:
        case KEY_ACTION_MOVE_TAB_RIGHT:
        case KEY_ACTION_FIND_REGEX:
        case KEY_ACTION_SET_PROFILE:
        case KEY_ACTION_PREVIOUS_MRU_TAB:
        case KEY_ACTION_LOAD_COLOR_PRESET:
        case KEY_ACTION_TOGGLE_HOTKEY_WINDOW_PINNING:
        case KEY_ACTION_UNDO:
        case KEY_ACTION_MOVE_END_OF_SELECTION_LEFT:
        case KEY_ACTION_MOVE_END_OF_SELECTION_RIGHT:
        case KEY_ACTION_MOVE_START_OF_SELECTION_LEFT:
        case KEY_ACTION_MOVE_START_OF_SELECTION_RIGHT:
        case KEY_ACTION_DECREASE_HEIGHT:
        case KEY_ACTION_INCREASE_HEIGHT:
        case KEY_ACTION_DECREASE_WIDTH:
        case KEY_ACTION_INCREASE_WIDTH:
        case KEY_ACTION_SWAP_PANE_LEFT:
        case KEY_ACTION_SWAP_PANE_RIGHT:
        case KEY_ACTION_SWAP_PANE_ABOVE:
        case KEY_ACTION_SWAP_PANE_BELOW:
        case KEY_FIND_AGAIN_DOWN:
        case KEY_FIND_AGAIN_UP:
        case KEY_ACTION_TOGGLE_MOUSE_REPORTING:
        case KEY_ACTION_INVOKE_SCRIPT_FUNCTION:
        case KEY_ACTION_DUPLICATE_TAB:
        case KEY_ACTION_MOVE_TO_SPLIT_PANE:
        case KEY_ACTION_SWAP_WITH_NEXT_PANE:
        case KEY_ACTION_SWAP_WITH_PREVIOUS_PANE:
        case KEY_ACTION_ALERT_ON_NEXT_MARK:
        case KEY_ACTION_COPY_INTERPOLATED_STRING:
        case KEY_ACTION_COPY_MODE:
        case KEY_ACTION_TOGGLE_SETTING:
            break;

        case KEY_ACTION_SEQUENCE:
            return [[self.parameter keyBindingActionsFromSequenceParameter] anyWithBlock:^BOOL(iTermKeyBindingAction *action) {
                return action.sendsText;
            }];
    }
    return NO;
}

- (BOOL)isActionable {
    switch (self.keyAction) {
        case KEY_ACTION_DO_NOT_REMAP_MODIFIERS:
        case KEY_ACTION_REMAP_LOCALLY:
        case KEY_ACTION_BYPASS:
            return NO;

        case KEY_ACTION_IGNORE:
        case KEY_ACTION_ESCAPE_SEQUENCE:
        case KEY_ACTION_HEX_CODE:
        case KEY_ACTION_TEXT:
        case KEY_ACTION_VIM_TEXT:
        case KEY_ACTION_VIM_TEXT_NO_BROADCAST:
        case KEY_ACTION_SEND_SNIPPET:
        case KEY_ACTION_COMPOSE:
        case KEY_ACTION_SEND_TMUX_COMMAND:
        case KEY_ACTION_RUN_COPROCESS:
        case KEY_ACTION_SEND_C_H_BACKSPACE:
        case KEY_ACTION_SEND_C_QM_BACKSPACE:
        case KEY_ACTION_INVALID:
        case KEY_ACTION_NEXT_SESSION:
        case KEY_ACTION_NEXT_WINDOW:
        case KEY_ACTION_PREVIOUS_SESSION:
        case KEY_ACTION_PREVIOUS_WINDOW:
        case KEY_ACTION_SCROLL_END:
        case KEY_ACTION_SCROLL_HOME:
        case KEY_ACTION_SCROLL_LINE_DOWN:
        case KEY_ACTION_SCROLL_LINE_UP:
        case KEY_ACTION_SCROLL_PAGE_DOWN:
        case KEY_ACTION_SCROLL_PAGE_UP:
        case KEY_ACTION_IR_FORWARD:
        case KEY_ACTION_IR_BACKWARD:
        case KEY_ACTION_SELECT_PANE_LEFT:
        case KEY_ACTION_SELECT_PANE_RIGHT:
        case KEY_ACTION_SELECT_PANE_ABOVE:
        case KEY_ACTION_SELECT_PANE_BELOW:
        case KEY_ACTION_TOGGLE_FULLSCREEN:
        case KEY_ACTION_SELECT_MENU_ITEM:
        case KEY_ACTION_NEW_WINDOW_WITH_PROFILE:
        case KEY_ACTION_NEW_TAB_WITH_PROFILE:
        case KEY_ACTION_SPLIT_HORIZONTALLY_WITH_PROFILE:
        case KEY_ACTION_SPLIT_VERTICALLY_WITH_PROFILE:
        case KEY_ACTION_NEXT_PANE:
        case KEY_ACTION_PREVIOUS_PANE:
        case KEY_ACTION_NEXT_MRU_TAB:
        case KEY_ACTION_MOVE_TAB_LEFT:
        case KEY_ACTION_MOVE_TAB_RIGHT:
        case KEY_ACTION_FIND_REGEX:
        case KEY_ACTION_SET_PROFILE:
        case KEY_ACTION_PREVIOUS_MRU_TAB:
        case KEY_ACTION_LOAD_COLOR_PRESET:
        case KEY_ACTION_PASTE_SPECIAL:
        case KEY_ACTION_PASTE_SPECIAL_FROM_SELECTION:
        case KEY_ACTION_TOGGLE_HOTKEY_WINDOW_PINNING:
        case KEY_ACTION_UNDO:
        case KEY_ACTION_MOVE_END_OF_SELECTION_LEFT:
        case KEY_ACTION_MOVE_END_OF_SELECTION_RIGHT:
        case KEY_ACTION_MOVE_START_OF_SELECTION_LEFT:
        case KEY_ACTION_MOVE_START_OF_SELECTION_RIGHT:
        case KEY_ACTION_DECREASE_HEIGHT:
        case KEY_ACTION_INCREASE_HEIGHT:
        case KEY_ACTION_DECREASE_WIDTH:
        case KEY_ACTION_INCREASE_WIDTH:
        case KEY_ACTION_SWAP_PANE_LEFT:
        case KEY_ACTION_SWAP_PANE_RIGHT:
        case KEY_ACTION_SWAP_PANE_ABOVE:
        case KEY_ACTION_SWAP_PANE_BELOW:
        case KEY_FIND_AGAIN_DOWN:
        case KEY_FIND_AGAIN_UP:
        case KEY_ACTION_TOGGLE_MOUSE_REPORTING:
        case KEY_ACTION_INVOKE_SCRIPT_FUNCTION:
        case KEY_ACTION_DUPLICATE_TAB:
        case KEY_ACTION_MOVE_TO_SPLIT_PANE:
        case KEY_ACTION_SWAP_WITH_NEXT_PANE:
        case KEY_ACTION_SWAP_WITH_PREVIOUS_PANE:
        case KEY_ACTION_COPY_OR_SEND:
        case KEY_ACTION_PASTE_OR_SEND:
        case KEY_ACTION_ALERT_ON_NEXT_MARK:
        case KEY_ACTION_COPY_INTERPOLATED_STRING:
        case KEY_ACTION_COPY_MODE:
        case KEY_ACTION_TOGGLE_SETTING:
            break;

        case KEY_ACTION_SEQUENCE:
            return [[self.parameter keyBindingActionsFromSequenceParameter] anyWithBlock:^BOOL(iTermKeyBindingAction *action) {
                return action.isActionable;
            }];
    }
    return YES;
}

@end

@implementation NSString(iTermKeyBindingAction)

+ (instancetype)parameterForKeyBindingActionSequence:(NSArray<iTermKeyBindingAction *> *)actions {
    NSArray<NSDictionary *> *dicts = [actions mapWithBlock:^id _Nullable(iTermKeyBindingAction * _Nonnull action) {
        return action.dictionaryValue;
    }];
    NSData *data = [NSJSONSerialization dataWithJSONObject:dicts options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

- (NSArray<iTermKeyBindingAction *> *)keyBindingActionsFromSequenceParameter {
    NSArray<NSDictionary *> *dicts = [NSJSONSerialization JSONObjectWithData:[self dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    if (![dicts isKindOfClass:[NSArray class]]) {
        return @[];
    }
    return [dicts mapWithBlock:^id _Nullable(NSDictionary * _Nonnull dict) {
        if (![dict isKindOfClass:[NSDictionary class]]) {
            return nil;
        }
        return [iTermKeyBindingAction withDictionary:dict];
    }];
}

@end

@implementation iTermKeyBindingAction(ParameterHelper)

- (NSDictionary *)toggleSettingDict {
    NSData *data = [self.parameter dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        return nil;
    }
    NSDictionary *dict = [NSDictionary castFrom:[NSJSONSerialization JSONObjectWithData:data
                                                                                options:0
                                                                                  error:nil]];
    if (!dict) {
        return nil;
    }
    return dict;
}

- (NSString *)toggleSettingKey {
    return [NSString castFrom:self.toggleSettingDict[@"key"]];
}

- (NSString *)toggleSettingLabel {
    return [NSString castFrom:self.toggleSettingDict[@"label"]];
}

- (BOOL)toggleSettingIsProfile {
    return [[NSNumber castFrom:self.toggleSettingDict[@"isProfile"]] boolValue];
}

+ (NSString *)toggleSettingParameterForKey:(NSString *)key
                                 isProfile:(BOOL)isProfile
                                     label:(NSString *)label {
    NSDictionary *dict = @{ @"key": key,
                            @"isProfile": @(isProfile),
                            @"label": label };
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    if (!data) {
        return @"";
    }
    return [data stringWithEncoding:NSUTF8StringEncoding] ?: @"";
}

@end
