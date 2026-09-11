//
//  iTermEditKeyActionWindowController.m
//  iTerm
//
//  Created by George Nachman on 4/7/14.
//
//

#import "iTermEditKeyActionWindowController.h"

#import "DebugLogging.h"
#import "iTerm2SharedARC-Swift.h"
#import "iTermActionsModel.h"
#import "iTermFunctionCallTextFieldDelegate.h"
#import "iTermKeystrokeFormatter.h"
#import "iTermPasteSpecialViewController.h"
#import "iTermPreferences.h"
#import "iTermShortcutInputView.h"
#import "iTermVariableScope.h"
#import "NSArray+iTerm.h"
#import "NSPopUpButton+iTerm.h"
#import "NSScreen+iTerm.h"
#import "NSTextField+iTerm.h"
#import "NSView+iTerm.h"
#import "RegexKitLite.h"

#import <SearchableComboListView/SearchableComboListView-Swift.h>

const CGFloat sideMarginWidth = 40;

static NSString *iTermEditKeyActionLocalizedString(NSString *key, NSString *fallback) {
    return [NSBundle.mainBundle localizedStringForKey:key value:fallback table:nil];
}

@interface iTermEditKeyActionDetailView: NSView
@end

@implementation iTermEditKeyActionDetailView

- (NSView *)hitTest:(NSPoint)point {
    NSView *subview = [super hitTest:point];
    if (subview == self) {
        return nil;
    }
    return subview;
}
@end

@interface iTermEditKeyActionWindowConfiguration: NSObject
@property (nonatomic, readonly) BOOL applyHidden;
@property (nonatomic, readonly) BOOL parameterHidden;
@property (nonatomic, readonly) NSString *helpString;
@property (nonatomic, readonly) BOOL parameterLabelHidden;
@property (nonatomic, readonly) BOOL profilePopupHidden;
@property (nonatomic, readonly) BOOL selectionMovementUnitHidden;
@property (nonatomic, readonly) BOOL profileLabelHidden;
@property (nonatomic, readonly) BOOL menuToSelectPopupHidden;
@property (nonatomic, readonly) BOOL settingToTogglePopupHidden;
@property (nonatomic, readonly) BOOL shortcutFieldDisableKeyRemapping;
@property (nonatomic, readonly) BOOL colorPresetsLabelHidden;
@property (nonatomic, readonly) BOOL colorPresetsPopupHidden;
@property (nonatomic, readonly) BOOL pasteSpecialHidden;
@property (nonatomic, readonly) BOOL snippetsHidden;
@property (nonatomic, readonly) BOOL showSecondary;
@property (nonatomic, readonly) NSString *parameterPlaceholder;
@property (nonatomic, readonly) NSString *parameterLabel;
@property (nonatomic, readonly) iTermFunctionCallTextFieldDelegate *parameterDelegate;
@property (nonatomic, readonly) NSString *parameterValue;
@end

@implementation iTermEditKeyActionWindowConfiguration

- (instancetype)initWithTag:(int)tag
       functionCallDelegate:(iTermFunctionCallTextFieldDelegate *)functionCallDelegate
 interpolatedStringDelegate:(iTermFunctionCallTextFieldDelegate *)interpolatedStringDelegate
                    context:(iTermVariablesSuggestionContext)context {
    self = [super init];
    if (self) {
        _parameterHidden = YES;
        _helpString = nil;
        _parameterLabelHidden = YES;
        _profilePopupHidden = YES;
        _selectionMovementUnitHidden = YES;
        _profileLabelHidden = YES;
        _menuToSelectPopupHidden = YES;
        _settingToTogglePopupHidden = YES;
        _shortcutFieldDisableKeyRemapping = NO;
        _colorPresetsLabelHidden = YES;
        _colorPresetsPopupHidden = YES;
        _pasteSpecialHidden = YES;
        _snippetsHidden = YES;
        _showSecondary = NO;
        _applyHidden = YES;

        switch (tag) {
            case KEY_ACTION_SEND_SNIPPET:
                _snippetsHidden = NO;
                _parameterValue = @"";
                _applyHidden = NO;
                break;

            case KEY_ACTION_COMPOSE:
                _parameterHidden = NO;
                _parameterPlaceholder = @"Text for composer";
                break;

            case KEY_ACTION_HEX_CODE:
                _parameterHidden = NO;
                _parameterPlaceholder = @"ex: 0x7f 0x20";
                _applyHidden = NO;
                break;

            case KEY_ACTION_VIM_TEXT:
            case KEY_ACTION_VIM_TEXT_NO_BROADCAST:
                _parameterHidden = NO;
                _helpString = @"Special characters are:\n* \\<1-to-3-digit octal>\n* \\x<1 or 2 digit hex>\n* \\u<4 digit hex>\n* \\b for backspace\n* \\e for esc\n* \\f for formfeed\n* \\n for newline and \\r for return\n* \\t for tab\n* \\\\ and \\\" for literal \\ and \"\n* <C-x> for control key\n* <M-x> for meta key.";
                _parameterPlaceholder = @"Enter value to send. Click help button for special characters.";
                _applyHidden = NO;
                break;

            case KEY_ACTION_TEXT:
                _parameterHidden = NO;
                _parameterPlaceholder = @"Enter value to send";
                _applyHidden = NO;
                break;

            case KEY_ACTION_RUN_COPROCESS:
                _parameterHidden = NO;
                _parameterPlaceholder = @"Enter command to run";
                _applyHidden = NO;
                break;

            case KEY_ACTION_SEND_TMUX_COMMAND:
                _parameterHidden = NO;
                _parameterPlaceholder = @"Enter tmux command";
                break;

            case KEY_ACTION_SELECT_MENU_ITEM:
                _parameterPlaceholder = @"Enter name of menu item";
                _menuToSelectPopupHidden = NO;
                _parameterValue = @"";
                break;

            case KEY_ACTION_ESCAPE_SEQUENCE:
                _parameterHidden = NO;
                _parameterPlaceholder = @"characters to send";
                _parameterLabelHidden = NO;
                _parameterLabel = NSLocalizedStringWithDefaultValue(@"ui.settings.itermeditkeyactionwindowcontroller.esc.74441038", nil, NSBundle.mainBundle, @"Esc+", @"User-facing text in iTermEditKeyActionWindowController (updateViewsAnimated:secondary:).");
                _applyHidden = NO;
                break;

            case KEY_ACTION_SPLIT_VERTICALLY_WITH_PROFILE:
            case KEY_ACTION_SPLIT_HORIZONTALLY_WITH_PROFILE:
            case KEY_ACTION_NEW_TAB_WITH_PROFILE:
            case KEY_ACTION_NEW_WINDOW_WITH_PROFILE:
                _profileLabelHidden = NO;
                _profilePopupHidden = NO;
                _parameterValue = @"";
                break;

            case KEY_ACTION_SET_PROFILE:
                _profileLabelHidden = NO;
                _profilePopupHidden = NO;
                _parameterValue = @"";
                _applyHidden = NO;
                break;

            case KEY_ACTION_LOAD_COLOR_PRESET:
                _colorPresetsLabelHidden = NO;
                _colorPresetsPopupHidden = NO;
                _parameterValue = @"";
                _applyHidden = NO;
                break;

            case KEY_ACTION_DO_NOT_REMAP_MODIFIERS:
                _shortcutFieldDisableKeyRemapping = YES;
                _parameterValue = @"";
                _helpString = @"This action lets you exempt a keystroke from modifier remapping. For example, if you remap ⌘ to ⌥ but you want ⌘-Tab to work as though ⌘ were unmapped just for that keystroke, you would use this action and set the keyboard shortcut to ⌘-Tab";
                _parameterValue = @"";
                break;

            case KEY_ACTION_REMAP_LOCALLY:
                _shortcutFieldDisableKeyRemapping = YES;
                _parameterValue = @"";
                _helpString = @"This action applies modifier remapping but prevents other programs from seeing the keystroke. For example, if you've swapped ⌘ and ^ and want physical ^-tab to switch tabs in iTerm2 instead of triggering the app switcher: bind ^-tab to this action. The system won't see the remapped ⌘-tab (so no app switcher), but iTerm2 receives it and can switch tabs.";
                _parameterValue = @"";
                break;

            case KEY_ACTION_BYPASS:
                _helpString = @"Prevents the keystroke from being sent to the terminal while allowing macOS to handle it normally. For example, if F1 triggers a  macOS Shortcut, binding F1 to Bypass Terminal stops it from sending a control sequence to the terminal but still lets the system shortcut work.";
                break;

            case KEY_ACTION_IGNORE:
                _helpString = @"Prevents the keystroke from having any effect within iTerm2. Modifier remapping remains unaffected.";
                break;

            case KEY_ACTION_NEXT_MRU_TAB:
                _parameterValue = @"";
                _helpString = @"Switches tabs in most-recently-used order, like ⌘-Tab in macOS. Hold a modifier and tap repeatedly to walk back through tab history; release the modifier to commit your selection. A single tap with no modifier held jumps to the previously-selected tab, so binding this to a plain key acts as a toggle between the two most recent tabs.";
                break;

            case KEY_ACTION_PREVIOUS_MRU_TAB:
                _parameterValue = @"";
                _helpString = @"Switches tabs in reverse most-recently-used order. Hold a modifier and tap repeatedly to walk forward through tab history (oldest first); release the modifier to commit your selection. A single tap with no modifier held jumps to the least-recently-used tab.";
                break;

            case KEY_ACTION_FIND_REGEX:
                _parameterHidden = NO;
                _parameterPlaceholder = @"Regular Expression";
                _applyHidden = NO;
                break;

            case KEY_ACTION_COPY_MODE:
                _parameterHidden = NO;
                _parameterPlaceholder = @"Copy Mode Commands";
                _applyHidden = NO;
                _helpString = @"Enter copy mode commands to move cursor, toggle selection, and so on. This key binding enters Copy Mode and then acts as though you had pressed the keys listed here. [See a list of all the commands](https://iterm2.com/documentation-copymode.html). Use vim syntax for control, option, and function keys (e.g., `<C-x>` or `<Up>`.";
                break;

            case KEY_ACTION_TOGGLE_SETTING:
                _parameterPlaceholder = @"Enter name of menu item";
                _settingToTogglePopupHidden = NO;
                _parameterValue = @"";
                break;

            case KEY_ACTION_INVOKE_SCRIPT_FUNCTION:
                _parameterHidden = NO;
                _parameterPlaceholder = @"Function Call";
                if (functionCallDelegate) {
                    _parameterDelegate = functionCallDelegate;
                } else {
                    _parameterDelegate =
                    [[iTermFunctionCallTextFieldDelegate alloc] initWithPathSource:[iTermVariableHistory pathSourceForContext:context]
                                                                       passthrough:nil
                                                                     functionsOnly:YES];
                }
                _applyHidden = NO;
                break;

            case KEY_ACTION_PASTE_SPECIAL_FROM_SELECTION:
            case KEY_ACTION_PASTE_SPECIAL:
                _pasteSpecialHidden = NO;
                _parameterValue = @"";
                _applyHidden = NO;
                break;

            case KEY_ACTION_MOVE_END_OF_SELECTION_LEFT:
            case KEY_ACTION_MOVE_END_OF_SELECTION_RIGHT:
            case KEY_ACTION_MOVE_START_OF_SELECTION_LEFT:
            case KEY_ACTION_MOVE_START_OF_SELECTION_RIGHT:
                _parameterValue = @"";
                _selectionMovementUnitHidden = NO;
                _parameterValue = @"";
                break;

            case KEY_ACTION_SEQUENCE:
                _showSecondary = YES;
                _parameterValue = @"";
                break;

            case KEY_ACTION_COPY_INTERPOLATED_STRING:
                _parameterHidden = NO;
                _parameterPlaceholder = @"Enter interpolated string (evaluated in session context)";
                if (interpolatedStringDelegate) {
                    _parameterDelegate = interpolatedStringDelegate;
                } else {
                    _parameterDelegate =
                    [[iTermFunctionCallTextFieldDelegate alloc] initWithPathSource:[iTermVariableHistory pathSourceForContext:context]
                                                                       passthrough:nil
                                                                     functionsOnly:NO];
                }
                _helpString = @"You can use this to copy information about the current session to the clipboard. [Learn more about interpolated strings](https://iterm2.com/documentation-scripting-fundamentals.html)";
                break;

            case KEY_ACTION_SCROLL_END:
            case KEY_ACTION_SCROLL_HOME:
            case KEY_ACTION_SCROLL_LINE_DOWN:
            case KEY_ACTION_SCROLL_LINE_UP:
            case KEY_ACTION_SCROLL_PAGE_DOWN:
            case KEY_ACTION_SCROLL_PAGE_UP:
            case KEY_ACTION_SEND_C_H_BACKSPACE:
            case KEY_ACTION_SEND_C_QM_BACKSPACE:
            case KEY_ACTION_DECREASE_HEIGHT:
            case KEY_ACTION_INCREASE_HEIGHT:
            case KEY_ACTION_DECREASE_WIDTH:
            case KEY_ACTION_INCREASE_WIDTH:
            case KEY_ACTION_TOGGLE_MOUSE_REPORTING:
            case KEY_ACTION_PASTE_OR_SEND:
            case KEY_ACTION_ALERT_ON_NEXT_MARK:
            case KEY_ACTION_COPY_OR_SEND:
                _parameterValue = @"";
                break;

            default:
                _parameterValue = @"";
                break;
        }
    }
    return self;
}

@end

@interface iTermEditKeyActionWindowController () <
    iTermKeyActionSequenceTableViewControllerDelegate,
    iTermPasteSpecialViewControllerDelegate,
    iTermSearchableComboViewDelegate,
    iTermShortcutInputViewDelegate,
    NSTextFieldDelegate>

@property(nonatomic, assign) BOOL ok;

@end

@implementation iTermEditKeyActionWindowController {
    IBOutlet NSView *_detail;
    IBOutlet NSView *_secondaryComboViewContainer;
    IBOutlet NSTextField *_secondaryActionLabel;
    IBOutlet NSView *_sequenceContainer;
    iTermSearchableComboView *_secondaryComboView;
    IBOutlet iTermKeyActionSequenceTableViewController *_sequenceTableViewController;

    IBOutlet iTermShortcutInputView *_shortcutField;
    IBOutlet NSTextField *_keyboardShortcutLabel;
    IBOutlet NSTextField *_touchBarLabel;
    IBOutlet NSView *_comboViewContainer;
    iTermSearchableComboView *_comboView;
    IBOutlet NSTextField *_parameter;
    IBOutlet NSTextField *_parameterLabel;
    IBOutlet NSPopUpButton *_profilePopup;
    IBOutlet NSPopUpButton *_selectionMovementUnit;
    IBOutlet iTermMenuItemPopupView *_menuToSelectPopup;
    IBOutlet iTermSettingPopupView *_settingToTogglePopup;
    IBOutlet NSTextField *_profileLabel;
    IBOutlet NSTextField *_colorPresetsLabel;
    IBOutlet NSPopUpButton *_colorPresetsPopup;
    IBOutlet NSPopUpButton *_snippetsPopup;
    IBOutlet NSView *_pasteSpecialViewContainer;
    IBOutlet NSButton *_okButton;
    NSPopUpButton *_applyButton;
    IBOutlet NSButton *_helpButton;
    IBOutlet NSTextField *_errorLabel;
    iTermEditKeyActionWindowConfiguration *_config;

    iTermPasteSpecialViewController *_pasteSpecialViewController;
    iTermFunctionCallTextFieldDelegate *_functionCallDelegate;
    iTermFunctionCallTextFieldDelegate *_interpolatedStringDelegate;
    iTermFunctionCallTextFieldDelegate *_labelDelegate;
}

- (instancetype)initWithContext:(iTermVariablesSuggestionContext)context
                           mode:(iTermEditKeyActionWindowControllerMode)mode
                    profileType:(ProfileType)profileType {
    self = [super initWithWindowNibName:@"iTermEditKeyActionWindowController" owner:self];
    if (self) {
        _profileType = profileType;
        _suggestContext = context;
        _mode = mode;
    }
    return self;
}

- (NSArray<iTermSearchableComboViewGroup *> *)groupsForPrimary:(BOOL)primary {
    NSArray<iTermSearchableComboViewGroup *> *groups = @[
        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.general.c910d474", @"General") items:[@[
            primary ? [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.ignore.fce77c34", @"Ignore") tag:KEY_ACTION_IGNORE] : [NSNull null],
            primary ? [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.bypass_terminal.27a888be", @"Bypass Terminal") tag:KEY_ACTION_BYPASS] : [NSNull null],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.select_menu_item.4ad59c3b", @"Select Menu Item...") tag:KEY_ACTION_SELECT_MENU_ITEM],
        ] arrayByRemovingNulls]]
    ];
    if (self.mode == iTermEditKeyActionWindowControllerModeKeyboardShortcut) {
        groups = [groups arrayByAddingObjectsFromArray:[@[
            primary ? [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.modifier_remapping.0be8e046", @"Modifier Remapping") items:@[
                [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.do_not_remap_modifiers.9756b026", @"Do Not Remap Modifiers") tag:KEY_ACTION_DO_NOT_REMAP_MODIFIERS],
                [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.remap_modifiers_in_iterm2_only.19633a74", @"Remap Modifiers in iTerm2 Only") tag:KEY_ACTION_REMAP_LOCALLY],
            ]] : [NSNull null],
            [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.recent_tabs.ea3eb622", @"Recent Tabs") items:@[
                [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.cycle_tabs_forward.b32ee6f9", @"Cycle Tabs Forward") tag:KEY_ACTION_NEXT_MRU_TAB],
                [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.cycle_tabs_backward.749377ea", @"Cycle Tabs Backward") tag:KEY_ACTION_PREVIOUS_MRU_TAB],
            ]],
        ] arrayByRemovingNulls]];
    }

    const BOOL hideTerminalOnlyItems = (_profileType & ProfileTypeTerminal) == 0;
    groups = [groups arrayByAddingObjectsFromArray:[@[
        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.miscellaneous.5cb0b426", @"Miscellaneous") items:[@[
            hideTerminalOnlyItems ? [NSNull null] : [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.run_coprocess.e6f8b4f5", @"Run Coprocess") tag:KEY_ACTION_RUN_COPROCESS],
            hideTerminalOnlyItems ? [NSNull null] : [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.start_instant_replay.6c86b391", @"Start Instant Replay") tag:KEY_ACTION_IR_BACKWARD],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.undo.a8283ade", @"Undo") tag:KEY_ACTION_UNDO],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.send_tmux_command.e1023a0c", @"Send tmux Command") tag:KEY_ACTION_SEND_TMUX_COMMAND],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.alert_on_next_mark.a46bce90", @"Alert on Next Mark") tag:KEY_ACTION_ALERT_ON_NEXT_MARK],
        ] arrayByRemovingNulls]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.new_tab_or_window.85e30380", @"New Tab or Window") items:@[
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.new_window_with_profile.7dc20476", @"New Window with Profile") tag:KEY_ACTION_NEW_WINDOW_WITH_PROFILE],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.new_tab_with_profile.6fed2410", @"New Tab with Profile") tag:KEY_ACTION_NEW_TAB_WITH_PROFILE],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.duplicate_tab.57d3ddba", @"Duplicate Tab") tag:KEY_ACTION_DUPLICATE_TAB],
        ]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.split.32afaa78", @"Split") items:@[
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.split_horizontally_with_profile.c80d9e4d", @"Split Horizontally with Profile") tag:KEY_ACTION_SPLIT_HORIZONTALLY_WITH_PROFILE],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.split_vertically_with_profile.5f101ec2", @"Split Vertically with Profile") tag:KEY_ACTION_SPLIT_VERTICALLY_WITH_PROFILE],
        ]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.profile.d696a35b", @"Profile") items:[@[
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.change_profile.d30d5c8c", @"Change Profile") tag:KEY_ACTION_SET_PROFILE],
            hideTerminalOnlyItems ? [NSNull null] : [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.load_color_preset.27aef6ea", @"Load Color Preset") tag:KEY_ACTION_LOAD_COLOR_PRESET],
        ] arrayByRemovingNulls]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.navigate_tabs.55d1e24c", @"Navigate Tabs") items:@[
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.next_tab.a9426fb3", @"Next Tab") tag:KEY_ACTION_NEXT_SESSION],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.previous_tab.80f06bdc", @"Previous Tab") tag:KEY_ACTION_PREVIOUS_SESSION],
        ]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.reorder_tabs.ee7f3fff", @"Reorder Tabs") items:@[
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.move_tab_left.42478433", @"Move Tab Left") tag:KEY_ACTION_MOVE_TAB_LEFT],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.move_tab_right.8b396b2f", @"Move Tab Right") tag:KEY_ACTION_MOVE_TAB_RIGHT],
        ]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.navigate_windows.92a0a6c7", @"Navigate Windows") items:@[
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.next_window.95bf685f", @"Next Window") tag:KEY_ACTION_NEXT_WINDOW],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.previous_window.4c8b1a6d", @"Previous Window") tag:KEY_ACTION_PREVIOUS_WINDOW],
        ]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.navigate_panes.7dfa2f22", @"Navigate Panes") items:@[
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.next_pane.1dd89542", @"Next Pane") tag:KEY_ACTION_NEXT_PANE],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.previous_pane.b8a94609", @"Previous Pane") tag:KEY_ACTION_PREVIOUS_PANE],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.select_split_pane_above.b60f03fb", @"Select Split Pane Above") tag:KEY_ACTION_SELECT_PANE_ABOVE],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.select_split_pane_below.2bd6f4a7", @"Select Split Pane Below") tag:KEY_ACTION_SELECT_PANE_BELOW],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.select_split_pane_on_left.af0703d1", @"Select Split Pane On Left") tag:KEY_ACTION_SELECT_PANE_LEFT],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.select_split_pane_on_right.8668336b", @"Select Split Pane On Right") tag:KEY_ACTION_SELECT_PANE_RIGHT],
        ]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.resize_pane.56342e5a", @"Resize Pane") items:@[
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.decrease_height.08015d85", @"Decrease Height") tag:KEY_ACTION_DECREASE_HEIGHT],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.increase_height.7dfa9645", @"Increase Height") tag:KEY_ACTION_INCREASE_HEIGHT],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.decrease_width.d5c88ec3", @"Decrease Width") tag:KEY_ACTION_DECREASE_WIDTH],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.increase_width.09496d0d", @"Increase Width") tag:KEY_ACTION_INCREASE_WIDTH],
        ]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.scroll.291873e3", @"Scroll") items:@[
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.scroll_to_end.c92e937c", @"Scroll to End") tag:KEY_ACTION_SCROLL_END],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.scroll_to_top.01004372", @"Scroll to Top") tag:KEY_ACTION_SCROLL_HOME],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.scroll_one_line_down.64145602", @"Scroll One Line Down") tag:KEY_ACTION_SCROLL_LINE_DOWN],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.scroll_one_line_up.1f23d92d", @"Scroll One Line Up") tag:KEY_ACTION_SCROLL_LINE_UP],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.scroll_one_page_down.c5172032", @"Scroll One Page Down") tag:KEY_ACTION_SCROLL_PAGE_DOWN],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.scroll_one_page_up.002851cd", @"Scroll One Page Up") tag:KEY_ACTION_SCROLL_PAGE_UP],
        ]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.split_panes.aaa052df", @"Split Panes") items:@[
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.swap_with_split_pane_above.2449d669", @"Swap With Split Pane Above") tag:KEY_ACTION_SWAP_PANE_ABOVE],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.swap_with_split_pane_below.c5868c4c", @"Swap With Split Pane Below") tag:KEY_ACTION_SWAP_PANE_BELOW],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.swap_with_split_pane_on_left.4e404f60", @"Swap With Split Pane on Left") tag:KEY_ACTION_SWAP_PANE_LEFT],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.swap_with_split_pane_on_right.81e944b5", @"Swap With Split Pane on Right") tag:KEY_ACTION_SWAP_PANE_RIGHT],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.swap_with_next_pane.e447408a", @"Swap With Next Pane") tag:KEY_ACTION_SWAP_WITH_NEXT_PANE],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.swap_with_previous_pane.66e117f4", @"Swap With Previous Pane") tag:KEY_ACTION_SWAP_WITH_PREVIOUS_PANE],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.move_session_to_split_pane.3b6be9b4", @"Move Session to Split Pane") tag:KEY_ACTION_MOVE_TO_SPLIT_PANE],
        ]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.send_keystrokes.753376a2", @"Send Keystrokes") items:[@[
            hideTerminalOnlyItems ? [NSNull null] : [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.send_h_backspace.7cf14960", @"Send ^H Backspace") tag:KEY_ACTION_SEND_C_H_BACKSPACE],
            hideTerminalOnlyItems ? [NSNull null] : [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.send_backspace.b17426b3", @"Send ^? Backspace") tag:KEY_ACTION_SEND_C_QM_BACKSPACE],
            hideTerminalOnlyItems ? [NSNull null] : [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.send_escape_sequence.cf8a3420", @"Send Escape Sequence") tag:KEY_ACTION_ESCAPE_SEQUENCE],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.send_hex_code.e7e29904", @"Send Hex Code") tag:KEY_ACTION_HEX_CODE],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.send_text.b4e1af54", @"Send Text") tag:KEY_ACTION_TEXT],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.send_text_with_vim_special_chars.fe6989e2", @"Send Text with “vim” Special Chars") tag:KEY_ACTION_VIM_TEXT],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.send_text_without_broadcasting.f6e30ff3", @"Send Text without Broadcasting") tag:KEY_ACTION_VIM_TEXT_NO_BROADCAST],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.send_snippet.9edb9820", @"Send Snippet") tag:KEY_ACTION_SEND_SNIPPET],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.compose.b9b7a47d", @"Compose…") tag:KEY_ACTION_COMPOSE],
        ] arrayByRemovingNulls]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.search.49c266ba", @"Search") items:[@[
            hideTerminalOnlyItems ? [NSNull null] : [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.find_regular_expression.01f50631", @"Find Regular Expression…") tag:KEY_ACTION_FIND_REGEX],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.find_again_down.98179375", @"Find Again Down") tag:KEY_FIND_AGAIN_DOWN],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.find_again_up.a4731f6f", @"Find Again Up") tag:KEY_FIND_AGAIN_UP],
        ] arrayByRemovingNulls]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.pasteboard.cce4bba7", @"Pasteboard") items:@[
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.paste.805011e7", @"Paste…") tag:KEY_ACTION_PASTE_SPECIAL],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.paste_from_selection.496fc8aa", @"Paste from Selection…") tag:KEY_ACTION_PASTE_SPECIAL_FROM_SELECTION],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.copy_or_send_c.ecde979a", @"Copy or Send ^C") tag:KEY_ACTION_COPY_OR_SEND],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.paste_or_send_v.4aca639b", @"Paste or Send ^V") tag:KEY_ACTION_PASTE_OR_SEND],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.copy_interpolated_string.a95c2c53", @"Copy Interpolated String") tag:KEY_ACTION_COPY_INTERPOLATED_STRING],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.copy_mode_commands.a820620d", @"Copy Mode Commands") tag:KEY_ACTION_COPY_MODE],
        ]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.toggles.420d9aec", @"Toggles") items:[@[
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.toggle_fullscreen.4fdafad2", @"Toggle Fullscreen") tag:KEY_ACTION_TOGGLE_FULLSCREEN],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.toggle_pin_hotkey_window.37c3862a", @"Toggle Pin Hotkey Window") tag:KEY_ACTION_TOGGLE_HOTKEY_WINDOW_PINNING],
            hideTerminalOnlyItems ? [NSNull null] : [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.keyboard.itermkeybindingaction.toggle_mouse_reporting.d753135a", @"Toggle Mouse Reporting") tag:KEY_ACTION_TOGGLE_MOUSE_REPORTING],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.toggle_setting.31b25d9a", @"Toggle Setting") tag:KEY_ACTION_TOGGLE_SETTING],
        ] arrayByRemovingNulls]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.selection.ca406707", @"Selection") items:@[
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.move_start_of_selection_back.5af02a0b", @"Move Start of Selection Back") tag:KEY_ACTION_MOVE_START_OF_SELECTION_LEFT],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.move_start_of_selection_forward.060e8376", @"Move Start of Selection Forward") tag:KEY_ACTION_MOVE_START_OF_SELECTION_RIGHT],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.move_end_of_selection_back.195d4fd3", @"Move End of Selection Back") tag:KEY_ACTION_MOVE_END_OF_SELECTION_LEFT],
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.move_end_of_selection_forward.b7a2b472", @"Move End of Selection Forward") tag:KEY_ACTION_MOVE_END_OF_SELECTION_RIGHT],
        ]],

        [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.scripting.01846401", @"Scripting") items:@[
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.invoke_script_function.225d35cc", @"Invoke Script Function…") tag:KEY_ACTION_INVOKE_SCRIPT_FUNCTION],
        ]],

        primary ? [[iTermSearchableComboViewGroup alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.composition.47fca483", @"Composition") items:@[
            [[iTermSearchableComboViewItem alloc] initWithLabel:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.sequence.5181d985", @"Sequence…") tag:KEY_ACTION_SEQUENCE],
        ]] : [NSNull null],
    ] arrayByRemovingNulls]];
    return groups;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    _sequenceTableViewController.delegate = self;
    _menuToSelectPopup.delegate = self;
    _settingToTogglePopup.delegate = self;

    switch (self.mode) {
        case iTermEditKeyActionWindowControllerModeKeyboardShortcut:
            break;
        case iTermEditKeyActionWindowControllerModeTouchBarItem:
            _touchBarLabel.placeholderString = NSLocalizedStringWithDefaultValue(@"ui.settings.itermeditkeyactionwindowcontroller.label_to_show_in_touch_bar.ec1f85aa", nil, NSBundle.mainBundle, @"Label to show in Touch Bar", @"User-facing text in iTermEditKeyActionWindowController (windowDidLoad).");
            break;
        case iTermEditKeyActionWindowControllerModeUnbound:
            _touchBarLabel.placeholderString = self.titleIsInterpolated ? NSLocalizedStringWithDefaultValue(@"ui.settings.itermeditkeyactionwindowcontroller.title_interpolated_string.7b57f42b", nil, NSBundle.mainBundle, @"Title (Interpolated String)", @"User-facing text in iTermEditKeyActionWindowController (windowDidLoad).") : NSLocalizedStringWithDefaultValue(@"ui.settings.itermeditkeyactionwindowcontroller.title.7e8cd205", nil, NSBundle.mainBundle, @"Title", @"User-facing text in iTermEditKeyActionWindowController (windowDidLoad).");
            break;
    }

    _comboView = [[iTermSearchableComboView alloc] initWithGroups:[self groupsForPrimary:YES]
                                                     defaultTitle:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.select_action.2d3a9d3a", @"Select Action…")];
    [_comboViewContainer addSubview:_comboView];
    _comboView.frame = _comboViewContainer.bounds;
    _comboView.delegate = self;

    _secondaryComboView = [[iTermSearchableComboView alloc] initWithGroups:[self groupsForPrimary:NO]
                                                              defaultTitle:iTermEditKeyActionLocalizedString(@"ui.settings.itermeditkeyactionwindowcontroller.select_action.2d3a9d3a", @"Select Action…")];
    [_secondaryComboViewContainer addSubview:_secondaryComboView];
    _secondaryComboView.frame = _secondaryComboViewContainer.bounds;
    _secondaryComboView.delegate = self;

    // For some reason, the first item is checked by default. Make sure every
    // item is unchecked before making a selection.
    NSString *formattedString = @"";
    if (self.currentKeystroke) {
        formattedString = [iTermKeystrokeFormatter stringForKeystroke:self.currentKeystroke];
    }
    _shortcutField.stringValue = formattedString;
    _touchBarLabel.stringValue = self.label ?: @"";
    _okButton.enabled = [self shouldEnableOK];
    (void)[_comboView selectItemWithTag:self.action];

    _applyButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_applyButton addItemWithTitle:NSLocalizedStringWithDefaultValue(@"ui.settings.itermeditkeyactionwindowcontroller.apply_to_current_session.a4599bb4", nil, NSBundle.mainBundle, @"Apply to current session", @"User-facing text in iTermEditKeyActionWindowController (windowDidLoad).")];
    _applyButton.menu.itemArray.lastObject.tag = iTermActionApplyModeCurrentSession;
    [_applyButton addItemWithTitle:NSLocalizedStringWithDefaultValue(@"ui.settings.itermeditkeyactionwindowcontroller.apply_to_all_sessions.4fc28dad", nil, NSBundle.mainBundle, @"Apply to all sessions", @"User-facing text in iTermEditKeyActionWindowController (windowDidLoad).")];
    _applyButton.menu.itemArray.lastObject.tag = iTermActionApplyModeAllSessions;
    [_applyButton addItemWithTitle:NSLocalizedStringWithDefaultValue(@"ui.settings.itermeditkeyactionwindowcontroller.apply_to_all_sessions_except_current.82593cdf", nil, NSBundle.mainBundle, @"Apply to all sessions except current", @"User-facing text in iTermEditKeyActionWindowController (windowDidLoad).")];
    _applyButton.menu.itemArray.lastObject.tag = iTermActionApplyModeUnfocusedSessions;
    [_applyButton addItemWithTitle:NSLocalizedStringWithDefaultValue(@"ui.settings.itermeditkeyactionwindowcontroller.apply_to_all_sessions_in_window.7de152f1", nil, NSBundle.mainBundle, @"Apply to all sessions in window", @"User-facing text in iTermEditKeyActionWindowController (windowDidLoad).")];
    _applyButton.menu.itemArray.lastObject.tag = iTermActionApplyModeAllInWindow;
    [_applyButton addItemWithTitle:NSLocalizedStringWithDefaultValue(@"ui.settings.itermeditkeyactionwindowcontroller.apply_to_all_sessions_in_tab.9ae7ab60", nil, NSBundle.mainBundle, @"Apply to all sessions in tab", @"User-facing text in iTermEditKeyActionWindowController (windowDidLoad).")];
    _applyButton.menu.itemArray.lastObject.tag = iTermActionApplyModeAllInTab;
    [_applyButton addItemWithTitle:NSLocalizedStringWithDefaultValue(@"ui.settings.itermeditkeyactionwindowcontroller.apply_to_broadcasted_to_sessions.d60824bc", nil, NSBundle.mainBundle, @"Apply to broadcasted-to sessions", @"User-facing text in iTermEditKeyActionWindowController (windowDidLoad).")];
    _applyButton.menu.itemArray.lastObject.tag = iTermActionApplyModeBroadcasting;

    _applyButton.target = self;
    _applyButton.action = @selector(parameterDidChange:);
    [_detail addSubview:_applyButton];

    [self loadParameter:self.parameterValue
                 action:self.action
              applyMode:self.applyMode
              secondary:NO];
}

- (void)loadParameter:(NSString *)parameterValue
               action:(KEY_ACTION)action
            applyMode:(iTermActionApplyMode)applyMode
            secondary:(BOOL)secondary {
    _parameter.stringValue = parameterValue ?: @"";
    if (action == KEY_ACTION_SELECT_MENU_ITEM) {
        [_menuToSelectPopup reloadData];
        [_menuToSelectPopup restoreParameter:parameterValue ?: @""];
    } else if (action == KEY_ACTION_TOGGLE_SETTING) {
        [_settingToTogglePopup reloadData];
        [_settingToTogglePopup selectItemWithIdentifier:parameterValue ?: @""];
    }

    if (_pasteSpecialViewController == nil) {
        _pasteSpecialViewController = [[iTermPasteSpecialViewController alloc] init];
        _pasteSpecialViewController.profileType = _profileType;
        [_pasteSpecialViewController view];
    }

    [self updateViewsAnimated:NO secondary:secondary];

    if (!_profilePopup.isHidden) {
        [_profilePopup populateWithProfilesSelectingGuid:parameterValue ?: @""
                                            profileTypes:_profileType];
    }
    if (!_colorPresetsPopup.isHidden) {
        [_colorPresetsPopup loadColorPresetsSelecting:parameterValue ?: @""];
    }
    if (!_snippetsPopup.isHidden) {
        [_snippetsPopup populateWithSnippetsSelectingActionKey:parameterValue ?: @""];
    }
    if (!_selectionMovementUnit.isHidden) {
        [_selectionMovementUnit selectItemWithTag:[parameterValue ?: @"" integerValue]];
    }
    if (!_secondaryComboViewContainer.isHidden && !secondary) {
        [_sequenceTableViewController setActions:[parameterValue ?: @"" keyBindingActionsFromSequenceParameter]];
    }
    if (self.action == KEY_ACTION_PASTE_SPECIAL ||
        self.action == KEY_ACTION_PASTE_SPECIAL_FROM_SELECTION) {
        [_pasteSpecialViewController loadSettingsFromString:parameterValue ?: @""];
    } else {
        // Set a few defaults; otherwise everything is reasonable.
        _pasteSpecialViewController.numberOfSpacesPerTab = [iTermPreferences intForKey:kPreferenceKeyPasteSpecialSpacesPerTab];
        _pasteSpecialViewController.shouldRemoveNewlines = NO;
        _pasteSpecialViewController.shouldBase64Encode = NO;
        _pasteSpecialViewController.shouldWaitForPrompt = NO;
        _pasteSpecialViewController.shouldEscapeShellCharsWithBackslash = NO;
    }
    _pasteSpecialViewController.view.frame = _pasteSpecialViewController.view.bounds;
    _pasteSpecialViewController.delegate = self;
    NSRect theFrame = _pasteSpecialViewContainer.frame;
    CGFloat originalHeight = theFrame.size.height;
    theFrame.size = _pasteSpecialViewController.view.bounds.size;
    theFrame.origin.y -= (theFrame.size.height - originalHeight);
    _pasteSpecialViewContainer.frame = theFrame;
    if (_pasteSpecialViewController.view.superview == nil) {
        [_pasteSpecialViewContainer addSubview:_pasteSpecialViewController.view];
    }
    _applyMode = applyMode;
    [_applyButton selectItemWithTag:applyMode];
    [self updateError];
}

- (void)setAction:(KEY_ACTION)keyAction parameter:(NSString *)parameter applyMode:(iTermActionApplyMode)applyMode {
    [self setAction:keyAction];
    _parameterValue = [parameter copy];
    _applyMode = applyMode;
}

- (void)setAction:(int)action {
    if (action == KEY_ACTION_IR_FORWARD) {
        action = KEY_ACTION_IGNORE;
    }
    _action = action;
}

- (iTermAction *)unboundAction {
    return [[iTermAction alloc] initWithTitle:self.label
                                       action:self.action
                                    parameter:self.parameterValue
                                     escaping:self.escaping
                                    applyMode:self.applyMode
                                      version:[iTermAction currentVersion]];
}

- (iTermKeystrokeOrTouchbarItem *)keystrokeOrTouchbarItem {
    switch (_mode) {
        case iTermEditKeyActionWindowControllerModeKeyboardShortcut:
            return [iTermOr first:self.currentKeystroke];
        case iTermEditKeyActionWindowControllerModeTouchBarItem:
            return [iTermOr second:[[iTermTouchbarItem alloc] initWithIdentifier:self.touchBarItemID]];
        case iTermEditKeyActionWindowControllerModeUnbound:
            return nil;
    }
}

#pragma mark - iTermShortcutInputViewDelegate

// Note: This is called directly by iTermHotKeyController when the action requires key remapping
// to be disabled so the shortcut can be input properly. In this case, |view| will be nil.
- (void)shortcutInputView:(iTermShortcutInputView *)view didReceiveKeyPressEvent:(NSEvent *)event {
    self.currentKeystroke = view.shortcut.keystroke;
    _okButton.enabled = [self shouldEnableOK];
}

- (void)setMode:(iTermEditKeyActionWindowControllerMode)mode {
    assert(NO);
}

#pragma mark - Private

- (void)updateViewsAnimated:(BOOL)animated secondary:(BOOL)secondary {
    switch (self.mode) {
        case iTermEditKeyActionWindowControllerModeUnbound:
            _keyboardShortcutLabel.stringValue = NSLocalizedStringWithDefaultValue(@"ui.settings.itermeditkeyactionwindowcontroller.title.7e8cd205", nil, NSBundle.mainBundle, @"Title", @"User-facing text in iTermEditKeyActionWindowController (updateViewsAnimated:secondary:).");
            if (self.titleIsInterpolated) {
                if (!_labelDelegate) {
                    _labelDelegate = [[iTermFunctionCallTextFieldDelegate alloc] initWithPathSource:[iTermVariableHistory pathSourceForContext:iTermVariablesSuggestionContextSession]
                                                                                        passthrough:self
                                                                                      functionsOnly:NO];
                }
                _touchBarLabel.delegate = _labelDelegate;
            } else {
                _touchBarLabel.delegate = self;
            }
            _touchBarLabel.hidden = NO;
            _shortcutField.hidden = YES;
            break;
        case iTermEditKeyActionWindowControllerModeTouchBarItem:
            _keyboardShortcutLabel.stringValue = NSLocalizedStringWithDefaultValue(@"ui.settings.itermeditkeyactionwindowcontroller.touch_bar_label.ec9d8d97", nil, NSBundle.mainBundle, @"Touch Bar Label", @"User-facing text in iTermEditKeyActionWindowController (updateViewsAnimated:secondary:).");
            _touchBarLabel.delegate = self;
            _touchBarLabel.hidden = NO;
            _shortcutField.hidden = YES;
            break;
        case iTermEditKeyActionWindowControllerModeKeyboardShortcut:
            _keyboardShortcutLabel.stringValue = NSLocalizedStringWithDefaultValue(@"ui.settings.itermeditkeyactionwindowcontroller.keyboard_shortcut.922b8703", nil, NSBundle.mainBundle, @"Keyboard Shortcut:", @"User-facing text in iTermEditKeyActionWindowController (updateViewsAnimated:secondary:).");
            _touchBarLabel.hidden = YES;
            _shortcutField.hidden = NO;
            break;
    }

    const int tag = secondary ? _secondaryComboView.selectedTag : _comboView.selectedTag;
    iTermEditKeyActionWindowConfiguration *config = [[iTermEditKeyActionWindowConfiguration alloc] initWithTag:tag
                                                                                          functionCallDelegate:_functionCallDelegate
                                                                                    interpolatedStringDelegate:_interpolatedStringDelegate
                                                                                                       context:_suggestContext];
    _config = config;
    if (config.parameterPlaceholder) {
        [_parameter.cell setPlaceholderString:config.parameterPlaceholder];
    }
    if (config.parameterLabel) {
        _parameterLabel.stringValue = config.parameterLabel;
    }
    if (config.parameterValue) {
        _parameter.stringValue = config.parameterValue;
    }
    if (config.parameterDelegate.functionsOnly) {
        _functionCallDelegate = config.parameterDelegate;
        _functionCallDelegate.passthrough = self;
    } else {
        _functionCallDelegate = nil;
    }
    if (config.parameterDelegate && !config.parameterDelegate.functionsOnly) {
        _interpolatedStringDelegate = config.parameterDelegate;
        _interpolatedStringDelegate.passthrough = self;
    } else {
        _interpolatedStringDelegate = nil;
    }
    _parameter.delegate = config.parameterDelegate ?: self;
    [_parameter setHidden:config.parameterHidden];
    _helpButton.hidden = config.helpString == nil;
    [_parameterLabel setHidden:config.parameterLabelHidden];
    [_profilePopup setHidden:config.profilePopupHidden];
    if (!config.profilePopupHidden) {
        [_profilePopup populateWithProfilesSelectingGuid:config.parameterValue ?: @""
                                            profileTypes:_profileType];
    }
    [_selectionMovementUnit setHidden:config.selectionMovementUnitHidden];
    [_profileLabel setHidden:config.profileLabelHidden];
    [_menuToSelectPopup setHidden:config.menuToSelectPopupHidden];
    [_settingToTogglePopup setHidden:config.settingToTogglePopupHidden];
    _shortcutField.disableKeyRemapping = config.shortcutFieldDisableKeyRemapping;
    [_colorPresetsLabel setHidden:config.colorPresetsLabelHidden];
    [_colorPresetsPopup setHidden:config.colorPresetsPopupHidden];
    [_snippetsPopup setHidden:config.snippetsHidden];
    [self setPasteSpecialHidden:config.pasteSpecialHidden];
    if (!secondary) {
        if (config.showSecondary) {
            NSRect frame = _detail.frame;
            frame.origin.x = NSMaxX(_sequenceContainer.frame) + 8;
            _detail.frame = frame;

        } else {
            NSRect frame = _detail.frame;
            frame.origin.x = NSMinX(_sequenceContainer.frame);
            _detail.frame = frame;
        }
        _sequenceContainer.hidden = !config.showSecondary;
        _secondaryActionLabel.hidden = !config.showSecondary;
        _secondaryComboViewContainer.hidden = !config.showSecondary;
    }
    if (_sequenceTableViewController.hasSelection) {
        (void)[_secondaryComboView selectItemWithTag:_sequenceTableViewController.selectedItem.keyAction];
    }
    _secondaryActionLabel.labelEnabled = _sequenceTableViewController.hasSelection;
    _secondaryComboView.enabled = _sequenceTableViewController.hasSelection;
    if (!_sequenceTableViewController.hasSelection) {
        (void)[_secondaryComboView selectItemWithTag:-1];
    }
    _applyButton.hidden = config.applyHidden;
    if (config.applyHidden) {
        [_applyButton selectItemWithTag:iTermActionApplyModeCurrentSession];
    } else {
        [_applyButton sizeToFit];
        NSRect applyButtonFrame = _applyButton.frame;
        applyButtonFrame.origin.x = [self desiredMinXForApplyButton];
        applyButtonFrame.origin.y = [self desiredYOriginForApplyButton];
        applyButtonFrame.size.width = _comboViewContainer.frame.size.width;
        _applyButton.frame = applyButtonFrame;
        _applyButton.autoresizingMask = 0;
    }
    [self updateFrameAnimated:animated];
}

- (CGFloat)desiredMinXForApplyButton {
    return NSMinX(_shortcutField.frame) - NSMinX(_keyboardShortcutLabel.frame) - 4;
}

- (CGFloat)desiredYOriginForApplyButton {
    NSView *lowestView = [[[_detail subviews] filteredArrayUsingBlock:^BOOL(__kindof NSView *view) {
        return !view.isHidden && view != _applyButton;
    }] minWithBlock:^NSComparisonResult(__kindof NSView *lhs, __kindof NSView *rhs) {
        return [@(NSMinY(lhs.frame)) compare:@(NSMinY(rhs.frame))];
    }];
    CGFloat bottom;
    if (lowestView) {
        bottom = NSMinY(lowestView.frame);
    } else {
        NSRect actionFrame = [_detail convertRect:_comboViewContainer.bounds fromView:_comboViewContainer];
        bottom = NSMinY(actionFrame);
    }
    return bottom - _applyButton.frame.size.height - 4;
}

- (BOOL)anyAccessoryVisible {
    return (!_sequenceContainer.isHidden ||
            [self anyNonSequenceAccessoryVisible]);
}

- (BOOL)anyNonSequenceAccessoryVisible {
    return (!_parameter.isHidden ||
            !_profilePopup.isHidden ||
            !_menuToSelectPopup.isHidden ||
            !_settingToTogglePopup.isHidden ||
            !_colorPresetsPopup.isHidden ||
            !_snippetsPopup.isHidden ||
            !_pasteSpecialViewContainer.isHidden ||
            !_parameterLabel.isHidden ||
            !_selectionMovementUnit.isHidden);
}

- (void)updateFrameAnimated:(BOOL)animated {
    NSRect rect = self.window.frame;
    rect.size = [self desiredSize];
    if (animated) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.window setFrame:rect display:YES animate:YES];
        });
    } else {
        [self.window setFrame:rect display:YES animate:NO];
    }
}

//    Side margin                     Side margin
//    |                               |
//   |-|                             |-|
//   +---------------------------------+
//   |                                 |
//   |  Keyboard shortcut: [        ]  |
//   |             Action: [v Popup ]  |  _
//   |         Basic Accessory         |  _|-- Basic accessory height
//   |                                 |
//   |                  [Cancel] [OK]  |
//   +---------------------------------+
//      |---------------------------|
//      Normal width excluding margins
//
//   +---------------------------------+  -
//   |                                 |  |
//   |  Keyboard shortcut: [        ]  |  |
//   |             Action: [v Popup ]  |  |-- Height excluding accessory
//   |                                 |  |
//   |                   [Cancel] [OK] |  |
//   +---------------------------------+  -

- (NSSize)desiredSize {
    return NSMakeSize(self.desiredWidthExcludingMargins + sideMarginWidth,
                      self.desiredHeight);
}

- (CGFloat)desiredWidthExcludingMargins {
    CGFloat normalWidthExcludingMargins = 402;
    if (!_helpButton.isHidden) {
        normalWidthExcludingMargins += _helpButton.frame.size.width + 6;
    }
    if (!_secondaryComboViewContainer.isHidden) {
        return NSMaxX(_detail.frame) - NSMinX(_sequenceContainer.frame);
    }
    if (!_pasteSpecialViewContainer.hidden) {
        return MAX(normalWidthExcludingMargins,
                   _pasteSpecialViewController.view.frame.size.width);
    }
    if (!_parameter.isHidden) {
        return NSMaxX(_parameter.frame);
    }
    return normalWidthExcludingMargins;
}

- (CGFloat)desiredHeight {
    const CGFloat heightExcludingAccessory = 126;
    return heightExcludingAccessory + [self accessoryHeight];
}

- (CGFloat)accessoryHeight {
    CGFloat height = 0;
    if (!_applyButton.isHidden) {
        height += _applyButton.frame.size.height + 4;
    }
    if (![self anyAccessoryVisible]) {
        return height;
    }
    if (!_sequenceContainer.isHidden) {
        height += MAX(NSHeight(_sequenceContainer.frame), self.nonSequenceAccessoryHeight);
        return height;
    }
    return height + [self nonSequenceAccessoryHeight];
}

- (CGFloat)nonSequenceAccessoryHeight {
    if (![self anyNonSequenceAccessoryVisible]) {
        return 0;
    }
    if (!_parameter.isHidden) {
        if (_errorLabel.isHidden) {
            return NSHeight(_parameter.frame);
        } else {
            return NSMaxY(_parameter.frame) - NSMinY(_errorLabel.frame);
        }
    }
    if (!_pasteSpecialViewContainer.isHidden) {
        return _pasteSpecialViewController.view.frame.size.height;
    }
    const CGFloat basicAccessoryHeight = 31;
    return basicAccessoryHeight;
}

- (void)setPasteSpecialHidden:(BOOL)hidden {
    _pasteSpecialViewContainer.hidden = hidden;
}

- (BOOL)shouldEnableOK {
    switch (self.mode) {
        case iTermEditKeyActionWindowControllerModeUnbound:
            break;
        case iTermEditKeyActionWindowControllerModeTouchBarItem:
            if (!_touchBarLabel.stringValue.length) {
                return NO;
            }
            break;
        case iTermEditKeyActionWindowControllerModeKeyboardShortcut:
            if (!self.currentKeystroke) {
                return NO;
            }
            break;
    }
    return YES;
}

#pragma mark - Actions

- (IBAction)help:(id)sender {
    [[NSView castFrom:sender] it_showWarningWithMarkdown:_config.helpString];
}


- (IBAction)parameterDidChange:(id)sender {
    if (!_secondaryComboViewContainer.isHidden) {
        [_sequenceTableViewController reloadCurrentItem:[self secondaryAction]];
    }
    [self updateError];
}

- (IBAction)ok:(id)sender {
    switch (self.mode) {
        case iTermEditKeyActionWindowControllerModeUnbound:
            self.label = _touchBarLabel.stringValue ?: @"";
            break;
        case iTermEditKeyActionWindowControllerModeTouchBarItem:
            if (!_touchBarLabel.stringValue.length) {
                DLog(@"Beep: empty touch bar label");
                NSBeep();
                return;
            }
            self.label = _touchBarLabel.stringValue;
            break;
        case iTermEditKeyActionWindowControllerModeKeyboardShortcut:
            if (!self.currentKeystroke) {
                DLog(@"Beep: no key combo");
                NSBeep();
                return;
            }
            break;
    }

    const KEY_ACTION keyAction = _comboView.selectedTag;
    const BOOL secondary = !_secondaryComboViewContainer.hidden;
    const BOOL hasApplyMode = !secondary && !_applyButton.isHidden;
    [self setAction:keyAction
          parameter:[self parameterValueForAction:keyAction]
          applyMode:hasApplyMode ? _applyButton.selectedTag : iTermActionApplyModeCurrentSession];

    self.ok = YES;
    [self.window.sheetParent endSheet:self.window];
}

- (NSString *)parameterValueForAction:(KEY_ACTION)action {
    switch (action) {
        case KEY_ACTION_SELECT_MENU_ITEM:
            return _menuToSelectPopup.selectedParameter;
        case KEY_ACTION_TOGGLE_SETTING:
            return _settingToTogglePopup.selectedIdentifier;

        case KEY_ACTION_SPLIT_HORIZONTALLY_WITH_PROFILE:
        case KEY_ACTION_SPLIT_VERTICALLY_WITH_PROFILE:
        case KEY_ACTION_NEW_TAB_WITH_PROFILE:
        case KEY_ACTION_NEW_WINDOW_WITH_PROFILE:
        case KEY_ACTION_SET_PROFILE:
            return [[_profilePopup selectedItem] representedObject];

        case KEY_ACTION_LOAD_COLOR_PRESET:
            return [[_colorPresetsPopup selectedItem] title];

        case KEY_ACTION_SEND_SNIPPET:
            return [[_snippetsPopup selectedItem] representedObject];

        case KEY_ACTION_PASTE_SPECIAL_FROM_SELECTION:
        case KEY_ACTION_PASTE_SPECIAL:
            return [_pasteSpecialViewController stringEncodedSettings];

        case KEY_ACTION_MOVE_END_OF_SELECTION_LEFT:
        case KEY_ACTION_MOVE_END_OF_SELECTION_RIGHT:
        case KEY_ACTION_MOVE_START_OF_SELECTION_LEFT:
        case KEY_ACTION_MOVE_START_OF_SELECTION_RIGHT:
            return [@(_selectionMovementUnit.selectedTag) description];

        case KEY_ACTION_COMPOSE:
        default:
            return [_parameter stringValue];

        case KEY_ACTION_SEQUENCE:
            return [NSString parameterForKeyBindingActionSequence:_sequenceTableViewController.actions];
    }
    return @"";
}

- (IBAction)cancel:(id)sender {
    self.ok = NO;
    [self.window.sheetParent endSheet:self.window];
}

#pragma mark - iTermSearchableComboViewDelegate

- (iTermKeyBindingAction *)secondaryAction {
    const KEY_ACTION action = _secondaryComboView.selectedTag;
    return [iTermKeyBindingAction withAction:action
                                   parameter:[self parameterValueForAction:action]
                                    escaping:self.escaping
                                   applyMode:_applyButton.isHidden ? iTermActionApplyModeCurrentSession : _applyButton.selectedTag];
}

- (void)searchableComboView:(iTermSearchableComboView *)view didSelectItem:(iTermSearchableComboViewItem *)didSelectItem {
    if (view == _comboView) {
        _parameterValue = @"";
    }
    if (view == _comboView || view == _secondaryComboView) {
        NSString *guid = [[_profilePopup selectedItem] representedObject];
        [_profilePopup populateWithProfilesSelectingGuid:guid
                                            profileTypes:_profileType];
        [_colorPresetsPopup loadColorPresetsSelecting:_colorPresetsPopup.selectedItem.representedObject];
        [_snippetsPopup populateWithSnippetsSelectingActionKey:_snippetsPopup.selectedItem.representedObject];
        [_menuToSelectPopup reloadData];
        [_settingToTogglePopup reloadData];
        const BOOL secondary = (view == _secondaryComboView);
        if (secondary) {
            [_sequenceTableViewController setActionForCurrentItem:view.selectedTag];
        }
        [self updateViewsAnimated:YES secondary:secondary];
        if (!_secondaryComboViewContainer.isHidden) {
            [_sequenceTableViewController reloadCurrentItem:[self secondaryAction]];
        }
    } else if (view == _menuToSelectPopup.comboView && view != nil) {
        [_sequenceTableViewController reloadCurrentItem:[self secondaryAction]];
    } else if (view == _settingToTogglePopup.comboView && view != nil) {
        [_sequenceTableViewController reloadCurrentItem:[self secondaryAction]];
    }
    [self updateError];
}

- (void)updateSyntaxErrorsForCopyMode {
    iTermVimKeyParser *parser = [[iTermVimKeyParser alloc] initWithString:_parameter.stringValue];
    NSError *error = nil;
    [parser eventsWithError:&error];
    if (error) {
        self.error = error.localizedDescription;
    } else {
        self.error = nil;
    }
}

- (void)setError:(NSString *)errorString {
    if (!errorString) {
        _errorLabel.hidden = YES;

        NSRect frame = _parameter.frame;
        const CGFloat maxY = NSMaxY(_parameter.frame);
        frame.origin.y = NSMinY(_errorLabel.frame);
        frame.size.height = maxY - NSMinY(frame);
        _parameter.frame = frame;
    } else {
        _errorLabel.stringValue = errorString;
        _errorLabel.hidden = NO;

        NSRect frame = _parameter.frame;
        const CGFloat maxY = NSMaxY(_parameter.frame);
        frame.origin.y = NSMaxY(_errorLabel.frame) + 4;
        frame.size.height = maxY - NSMinY(frame);
        _parameter.frame = frame;
    }
}
#pragma mark - NSTextEditing

- (void)controlTextDidChange:(NSNotification *)notification {
    _okButton.enabled = [self shouldEnableOK];
    if (!_secondaryComboViewContainer.isHidden) {
        [_sequenceTableViewController reloadCurrentItem:[self secondaryAction]];
    }
    [self updateError];
}

- (void)updateError {
    if (_secondaryComboViewContainer.isHidden) {
        const KEY_ACTION action = _comboView.selectedTag;
        if (action == KEY_ACTION_COPY_MODE) {
            [self updateSyntaxErrorsForCopyMode];
        } else {
            self.error = nil;
        }
    } else {
        const KEY_ACTION action = _secondaryComboView.selectedTag;
        if (action == KEY_ACTION_COPY_MODE) {
            [self updateSyntaxErrorsForCopyMode];
        } else {
            self.error = nil;
        }
    }
}

#pragma mark - iTermKeyActionSequenceTableViewControllerDelegate

- (void)keyActionSequenceTableViewController:(iTermKeyActionSequenceTableViewController *)sender
                          selectionDidChange:(iTermKeyBindingAction *)action {
    [self updateViewsAnimated:NO secondary:YES];
    [self loadParameter:action.parameter
                 action:action.keyAction
              applyMode:action.applyMode
              secondary:YES];
}

- (void)keyActionSequenceTableViewControllerDidChange:(iTermKeyActionSequenceTableViewController *)sender
                                              actions:(NSArray<iTermKeyBindingAction *> * _Nonnull)actions {
    if (sender.hasSelection) {
        iTermKeyBindingAction *action = sender.selectedItem;
        [self loadParameter:action.parameter
                     action:action.keyAction
                  applyMode:_applyMode
                  secondary:YES];
    } else {
        [self updateViewsAnimated:NO secondary:YES];
    }
}

#pragma mark - iTermPasteSpecialViewControllerDelegate

- (void)pasteSpecialViewSpeedDidChange {
    [self parameterDidChange:nil];
}

- (void)pasteSpecialTransformDidChange {
    [self parameterDidChange:nil];
}

@end
