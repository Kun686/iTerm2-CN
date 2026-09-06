//
//  iTermTextViewContextMenuHelper.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 8/30/20.
//

#import "iTermTextViewContextMenuHelper.h"

#import "DebugLogging.h"
#import "NSDictionary+iTerm.h"
#import "NSURL+iTerm.h"
#import "SCPPath.h"
#import "SmartSelectionController.h"
#import "VT100RemoteHost.h"
#import "VT100ScreenMark.h"
#import "iTerm2SharedARC-Swift.h"
#import "iTermAPIHelper.h"
#import "iTermAdvancedSettingsModel.h"
#import "iTermApplication.h"
#import "iTermContextMenuUtilities.h"
#import "iTermImageInfo.h"
#import "iTermPreferences.h"
#import "iTermScriptFunctionCall.h"
#import "iTermSelection.h"
#import "iTermTextExtractor.h"
#import "iTermURLActionHelper.h"
#import "iTermVariableScope.h"
#import "iTermVariableScope+Session.h"
#import "iTermVariableScope+Tab.h"
#import "NSColor+iTerm.h"
#import "NSJSONSerialization+iTerm.h"
#import "NSStringITerm.h"
#import "RegexKitLite.h"
#import "URLAction.h"
#import "PTYWindow.h"
#import "WindowControllerInterface.h"

const int kMaxSelectedTextLengthForCustomActions = 400;

@interface iTermTextViewContextMenuHelper()<NSMenuItemValidation>
@end
@implementation iTermTextViewContextMenuHelper

- (instancetype)initWithURLActionHelper:(iTermURLActionHelper *)urlActionHelper {
    self = [super init];
    if (self) {
        _urlActionHelper = urlActionHelper;
    }
    return self;
}

- (NSDictionary<NSNumber *, NSString *> *)smartSelectionActionSelectorDictionary {
    // The selector's name must begin with contextMenuAction to
    // pass validateMenuItem.
    return @{ @(kOpenFileContextMenuAction): NSStringFromSelector(@selector(contextMenuActionOpenFile:)),
              @(kOpenUrlContextMenuAction): NSStringFromSelector(@selector(contextMenuActionOpenURL:)),
              @(kRunCommandContextMenuAction): NSStringFromSelector(@selector(contextMenuActionRunCommand:)),
              @(kRunCoprocessContextMenuAction): NSStringFromSelector(@selector(contextMenuActionRunCoprocess:)),
              @(kSendTextContextMenuAction): NSStringFromSelector(@selector(contextMenuActionSendText:)),
              @(kRunCommandInWindowContextMenuAction): NSStringFromSelector(@selector(contextMenuActionRunCommandInWindow:)),
              @(kCopyContextMenuAction): NSStringFromSelector(@selector(contextMenuActionCopy:))
    };
}

- (void)applyWindowAppearanceToMenu:(NSMenu *)menu {
    NSWindow *nsWindow = [self.delegate contextMenuViewForMenu:self].window;
    id<PTYWindow> window = nsWindow.ptyWindow;
    if (window.it_terminalWindowUseMinimalStyle) {
        NSColor *bgColor = window.it_terminalWindowDecorationBackgroundColor;
        NSAppearanceName name = bgColor.perceivedBrightness < 0.5 ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua;
        menu.appearance = [NSAppearance appearanceNamed:name];
    } else {
        menu.appearance = nsWindow.appearance;
    }
}

// This method is called by control-click or by clicking the hamburger icon in the session title bar.
// Two-finger tap (or presumably right click with a mouse) would go through mouseUp->
// PointerController->openContextMenuWithEvent.
- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    if (theEvent) {
        // Control-click
        if ([iTermPreferences boolForKey:kPreferenceKeyControlLeftClickBypassesContextMenu] &&
            [self.delegate contextMenuIsMouseEventReportable:self forEvent:theEvent]) {
            return nil;
        }
        NSPoint clickPoint = [self.delegate contextMenu:self clickPoint:theEvent allowRightMarginOverflow:NO];
        _validationClickPoint = VT100GridCoordMake(clickPoint.x, clickPoint.y);

        NSMenu *menu = [self contextMenuWithEvent:theEvent];
        menu.delegate = self;
        [self applyWindowAppearanceToMenu:menu];
        return menu;
    }
    // Hamburger icon in session title view.
    _validationClickPoint = VT100GridCoordMake(-1, -1);
    NSMenu *menu = [self titleBarMenu];
    _savedSelectedText = [self.delegate contextMenuSelectedText:self capped:0].copy;
    menu.delegate = self;
    [self applyWindowAppearanceToMenu:menu];
    return menu;
}

- (void)openContextMenuAt:(VT100GridCoord)clickPoint event:(NSEvent *)event {
    _validationClickPoint = clickPoint;
    NSMenu *menu = [self contextMenuWithEvent:event];
    menu.delegate = self;
    [self applyWindowAppearanceToMenu:menu];
    NSView *view = [self.delegate contextMenuViewForMenu:self];
    [NSMenu popUpContextMenu:menu withEvent:event forView:view];
    _validationClickPoint = VT100GridCoordMake(-1, -1);
}

- (id<VT100ScreenMarkReading>)markForClick:(NSEvent *)event requireMargin:(BOOL)requireMargin {
    NSPoint locationInWindow = [event locationInWindow];
    if (requireMargin && locationInWindow.x >= [iTermPreferences sideMargins]) {
        return nil;
    }
    iTermOffscreenCommandLine *offscreenCommandLine =
        [self.delegate contextMenu:self offscreenCommandLineForClickAt:event.locationInWindow];
    if (offscreenCommandLine) {
        return nil;
    }
    const NSPoint clickPoint = [self.delegate contextMenu:self
                                               clickPoint:event
                                 allowRightMarginOverflow:NO];
    const int y = clickPoint.y;
    if (requireMargin) {
        return [self.delegate contextMenu:self markOnLine:y];
    } else {
        return [self.delegate contextMenu:self markAtCoord:VT100GridCoordMake(clickPoint.x, clickPoint.y)];
    }
}

- (NSMenu *)timestampContextMenuWithEvent:(NSEvent *)event
                                 baseline:(NSTimeInterval)baseline
                              clickedTime:(NSTimeInterval)clickedTime {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.contextual_menu.3db60c37", nil, NSBundle.mainBundle, @"Contextual Menu", @"User-facing text in iTermTextViewContextMenuHelper (timestampContextMenuWithEvent:baseline:clickedTime:).")];

    if (baseline != clickedTime) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.set_baseline_for_relative_timestamps.47b7b001", nil, NSBundle.mainBundle, @"Set Baseline for Relative Timestamps", @"User-facing text in iTermTextViewContextMenuHelper (timestampContextMenuWithEvent:baseline:clickedTime:).")
                                                      action:@selector(setTimestampBaseline:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = @(clickedTime);
        [menu addItem:item];
    }
    if (baseline != 0) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.disable_relative_timestamps.dd2d457e", nil, NSBundle.mainBundle, @"Disable Relative Timestamps", @"User-facing text in iTermTextViewContextMenuHelper (timestampContextMenuWithEvent:baseline:clickedTime:).")
                                                      action:@selector(setTimestampBaseline:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = @0;
        [menu addItem:item];
    }
    return menu;
}

- (void)setTimestampBaseline:(NSMenuItem *)sender {
    [self.delegate contextMenuSetTimestampBaseline:[sender.representedObject doubleValue]];
}

- (NSMenu *)contextMenuWithEvent:(NSEvent *)event {
    NSTimeInterval baseline = 0;
    NSTimeInterval clickedTime = 0;
    if ([self.delegate contextMenuClickIsOnTimestamps:event
                                      currentBaseline:&baseline
                                          clickedTime:&clickedTime]) {
        return [self timestampContextMenuWithEvent:event
                                          baseline:baseline
                                       clickedTime:clickedTime];
    }
    const NSPoint clickPoint = [self.delegate contextMenu:self
                                               clickPoint:event
                                 allowRightMarginOverflow:NO];
    const int x = clickPoint.x;
    const int y = clickPoint.y;

    const VT100GridCoord coord = VT100GridCoordMake(x, y);
    id<iTermImageInfoReading> imageInfo = [self.delegate contextMenu:self imageInfoAtCoord:coord];

    const long long overflow = [self.delegate contextMenuTotalScrollbackOverflow:self];
    iTermSelection *selection = [self.delegate contextMenuSelection:self];
    const BOOL clickedInExistingSelection = [selection containsAbsCoord:VT100GridAbsCoordMake(x, y + overflow)];
    if (!imageInfo &&
        !clickedInExistingSelection) {
        // Didn't click on selection.
        // Save the selection and do a smart selection. If we don't like the result, restore it.
        iTermSelection *savedSelection = [selection copy];
        [_urlActionHelper smartSelectWithEvent:event];
        NSCharacterSet *nonWhiteSpaceSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
        NSString *text = [[self.delegate contextMenuSelectedText:self capped:0] copy];
        if (!text ||
            !text.length ||
            [text rangeOfCharacterFromSet:nonWhiteSpaceSet].location == NSNotFound) {
            // If all we selected was white space, undo it.
            [self.delegate contextMenu:self setSelection:savedSelection];
            _savedSelectedText = [[self.delegate contextMenuSelectedText:self capped:0] copy];
        } else {
            _savedSelectedText = text;
        }
    } else if (clickedInExistingSelection && [self.delegate contextMenuSelectionIsShort:self]) {
        _savedSelectedText = [[self.delegate contextMenuSelectedText:self capped:0] copy];
    }
    NSMenu *contextMenu = [self menuAtCoord:coord];

    id<VT100ScreenMarkReading> mark = [self.delegate contextMenu:self markOnLine:y];
    // The mark's first line is a command line the user ran, and -[mark description]
    // embeds it too, so redact both the mark and the command argument.
    RLog(@"contextMenuWithEvent:%@ x=%d, mark=%@, mark command=%@", event, x, RLogRedact(mark, mark.redactedDescription), RLogRedact([mark firstLineOfCommand], @([mark firstLineOfCommand].length)));
    [self addFoldUnfoldMenuItemForLine:y contextMenu:contextMenu];
    if (mark.name) {
        NSMenuItem *nameItem = [[NSMenuItem alloc] initWithTitle:mark.name action:nil keyEquivalent:@""];

        NSMenuItem *removeItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.remove_named_mark.ec1bc64e", nil, NSBundle.mainBundle, @"Remove Named Mark", @"User-facing text in iTermTextViewContextMenuHelper (contextMenuWithEvent:).") action:@selector(removeNamedMark:) keyEquivalent:@""];
        removeItem.target = self;
        removeItem.representedObject = mark;

        [contextMenu insertItem:nameItem atIndex:0];
        [contextMenu insertItem:removeItem atIndex:1];
        [contextMenu insertItem:[NSMenuItem separatorItem] atIndex:2];
    }
    if (mark && mark.hasNonEmptyCommand) {
        NSMenuItem *markItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.command_info.34a20e57", nil, NSBundle.mainBundle, @"Command Info", @"User-facing text in iTermTextViewContextMenuHelper (contextMenuWithEvent:).")
                                                          action:@selector(revealCommandInfo:)
                                                   keyEquivalent:@""];
        markItem.target = self;
        markItem.representedObject = mark;
        [contextMenu insertItem:markItem atIndex:0];
        NSInteger nextIndex = 1;
#if DEBUG
        NSMenuItem *aidItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.aid_parent.a8ef37d8", nil, NSBundle.mainBundle, @"aid: %@ (parent: %@)", @"User-facing text in iTermTextViewContextMenuHelper (initWithTitle)."),
                                                                 mark.aid ?: @"(none)",
                                                                 mark.parentAid ?: @"(none)"]
                                                         action:nil
                                                  keyEquivalent:@""];
        aidItem.enabled = NO;
        [contextMenu insertItem:aidItem atIndex:nextIndex++];
#endif
        [contextMenu insertItem:[NSMenuItem separatorItem] atIndex:nextIndex];
    }
    return contextMenu;
}

- (void)addFoldUnfoldMenuItemForLine:(int)y contextMenu:(NSMenu *)contextMenu {
    id<iTermFoldMarkReading> foldMark = [self.delegate contextMenuFoldAtLine:y];
    id<VT100ScreenMarkReading> mark = [self.delegate contextMenuCommandWithOutputAtLine:y];

    if (foldMark) {
        NSMenuItem *markItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.unfold.ae11429c", nil, NSBundle.mainBundle, @"Unfold", @"User-facing text in iTermTextViewContextMenuHelper (addFoldUnfoldMenuItemForLine:contextMenu:).")
                                                          action:@selector(unfoldMark:)
                                                   keyEquivalent:@""];
        markItem.target = self;
        markItem.representedObject = foldMark;
        [contextMenu insertItem:markItem atIndex:0];
        [contextMenu insertItem:[NSMenuItem separatorItem] atIndex:1];
    } else if (mark && mark.hasNonEmptyCommand && [self.delegate contextMenu:self markShouldBeFoldable:mark]) {
        NSMenuItem *markItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.fold.92c122b5", nil, NSBundle.mainBundle, @"Fold", @"User-facing text in iTermTextViewContextMenuHelper (addFoldUnfoldMenuItemForLine:contextMenu:).")
                                                          action:@selector(foldCommandMark:)
                                                   keyEquivalent:@""];
        markItem.target = self;
        markItem.representedObject = mark;
        [contextMenu insertItem:markItem atIndex:0];
        [contextMenu insertItem:[NSMenuItem separatorItem] atIndex:1];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if ([item action] == @selector(downloadWithSCP:)) {
        if (![self.delegate contextMenuSelectionIsReasonable:self])  {
            return NO;
        }
        __block BOOL result = NO;
        iTermSelection *selection = [self.delegate contextMenuSelection:self];
        const BOOL valid =
        [self.delegate contextMenu:self withRelativeCoord:selection.lastAbsRange.coordRange.start block:^(VT100GridCoord coord) {
            const BOOL haveShortSelection = [self.delegate contextMenuSelectionIsShort:self];
            NSString *selectedText = [self.delegate contextMenuSelectedText:self capped:0];
            result = (haveShortSelection &&
                      [selection hasSelection] &&
                      [self.delegate contextMenu:self scpPathForFile:selectedText onLine:coord.y] != nil);
        }];
        return (valid && result);
    }
    if ([item action] == @selector(restartSession:)) {
        return [self.delegate contextMenuSessionCanBeRestarted:self];
    }
    // Disable move/swap when the pane is locked or the window's layout is locked.
    if ([item action] == @selector(movePane:) ||
        [item action] == @selector(swapSessions:)) {
        return ![self.delegate contextMenuIsLocked:self] && ![self.delegate contextMenuWindowIsLayoutLocked:self];
    }
    // These change the window's layout (split a pane or close a pane), so disable
    // them when the window's layout is locked.
    if ([item action] == @selector(splitTextViewVertically:) ||
        [item action] == @selector(splitTextViewHorizontally:) ||
        [item action] == @selector(closeTextViewSession:)) {
        return ![self.delegate contextMenuWindowIsLayoutLocked:self];
    }
    if ([item action] == @selector(toggleBroadcastingInput:) ||
        [item action] == @selector(toggleLock:) ||
        [item action] == @selector(lockAllInTab:) ||
        [item action] == @selector(unlockAllInTab:) ||
        [item action] == @selector(editTextViewSession:) ||
        [item action] == @selector(clearTextViewBuffer:) ||
        [item action] == @selector(reRunCommand:) ||
        [item action] == @selector(saveImageAs:) ||
        [item action] == @selector(copyImage:) ||
        [item action] == @selector(openImage:) ||
        [item action] == @selector(togglePauseAnimatingImage:) ||
        [item action] == @selector(inspectImage:) ||
        [item action] == @selector(apiMenuItem:) ||
        [item action] == @selector(copyLinkAddress:) ||
        [item action] == @selector(copyDetectedURL:) ||
        [item action] == @selector(copyString:) ||
        [item action] == @selector(copyData:) ||
        [item action] == @selector(replaceWithPrettyJSON:) ||
        [item action] == @selector(replaceWithBase64Decoded:) ||
        [item action] == @selector(replaceWithBase64Encoded:) ||
        [item action] == @selector(revealCommandInfo:) ||
        [item action] == @selector(removeNamedMark:)) {
        return YES;
    }
    if ([item action] == @selector(stopCoprocess:)) {
        return [self.delegate contextMenuHasCoprocess:self];
    }
    if ([item action] == @selector(bury:)) {
        return [self.delegate contextMenuCanBurySession:self];
    }
    if ([item action] == @selector(selectCommandOutput:)) {
        id<VT100ScreenMarkReading> commandMark = [item representedObject];
        return [self.delegate contextMenu:self hasOutputForCommandMark:commandMark];
    }
    if ([item action] == @selector(openURLInVerticalSplitPane:) ||
        [item action] == @selector(openURLInHorizontalSplitPane:)) {
        // These explicitly split the current window, so disable them when its
        // layout is locked (parallel to the greyed-out Split Pane menu items).
        iTermSelection *selection = [self.delegate contextMenuSelection:self];
        return selection.hasSelection && ![self.delegate contextMenuWindowIsLayoutLocked:self];
    }
    if ([item action] == @selector(sendSelection:) ||
        [item action] == @selector(addNote:) ||
        [item action] == @selector(mail:) ||
        [item action] == @selector(browse:) ||
        [item action] == @selector(quickLook:) ||
        [item action] == @selector(searchInBrowser:) ||
        [item action] == @selector(addTrigger:) ||
        [item action] == @selector(saveSelectionAsSnippet:)) {
        iTermSelection *selection = [self.delegate contextMenuSelection:self];
        return selection.hasSelection;
    }

    if ([item action] == @selector(showNotes:)) {
        if (self.validationClickPoint.x < 0) {
            return NO;
        }
        const VT100GridCoordRange range = VT100GridCoordRangeMake(_validationClickPoint.x,
                                                                  _validationClickPoint.y,
                                                                  _validationClickPoint.x + 1,
                                                                  _validationClickPoint.y);
        return [self.delegate contextMenu:self hasOpenAnnotationInRange:range];
    }
    if (item.action == @selector(foldCommandMark:) || item.action == @selector(unfoldMark:)) {
        return YES;
    }
    if (item.action == @selector(setTimestampBaseline:)) {
        return YES;
    }
    if ([self.smartSelectionActionSelectorDictionary.allValues containsObject:NSStringFromSelector(item.action)]) {
        return YES;
    }

    return NO;
}

#pragma mark - Private


- (NSMenu *)menuAtCoord:(VT100GridCoord)coord {
    NSMenu *theMenu;

    // Allocate a menu
    theMenu = [[NSMenu alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.contextual_menu.3db60c37", nil, NSBundle.mainBundle, @"Contextual Menu", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:).")];
    id<iTermImageInfoReading> imageInfo = [self.delegate contextMenu:self imageInfoAtCoord:coord];
    if (imageInfo) {
        // Show context menu for an image.
        NSArray *entryDicts;
        if (imageInfo.broken) {
            entryDicts =
                @[ @{ @"title": @"Save File As…",
                      @"selector": NSStringFromSelector(@selector(saveImageAs:)) },
                   @{ @"title": @"Copy File",
                      @"selector": NSStringFromSelector(@selector(copyImage:)) },
                   @{ @"title": @"Open File",
                      @"selector": NSStringFromSelector(@selector(openImage:)) },
                   @{ @"title": @"Inspect",
                      @"selector": NSStringFromSelector(@selector(inspectImage:)) } ];
        } else {
            entryDicts =
                @[ @{ @"title": @"Save Image As…",
                      @"selector": NSStringFromSelector(@selector(saveImageAs:)) },
                   @{ @"title": @"Copy Image",
                      @"selector": NSStringFromSelector(@selector(copyImage:)) },
                   @{ @"title": @"Open Image",
                      @"selector": NSStringFromSelector(@selector(openImage:)) },
                   @{ @"title": @"Inspect",
                      @"selector": NSStringFromSelector(@selector(inspectImage:)) } ];
        }
        if (imageInfo.animated || imageInfo.paused) {
            NSString *selector = NSStringFromSelector(@selector(togglePauseAnimatingImage:));
            if (imageInfo.paused) {
                entryDicts = [entryDicts arrayByAddingObject:@{ @"title": @"Resume Animating",
                                                                @"selector": selector }];
            } else {
                entryDicts = [entryDicts arrayByAddingObject:@{ @"title": @"Stop Animating",
                                                                @"selector": selector }];
            }
        }
        for (NSDictionary *entryDict in entryDicts) {
            NSMenuItem *item;

            item = [[NSMenuItem alloc] initWithTitle:entryDict[@"title"]
                                              action:NSSelectorFromString(entryDict[@"selector"])
                                       keyEquivalent:@""];
            [item setRepresentedObject:imageInfo];
            item.target = self;
            [theMenu addItem:item];
        }
        return theMenu;
    }

    const BOOL haveShortSelection = [self.delegate contextMenuSelectionIsShort:self];
    NSString *shortSelectedText = nil;
    {
        BOOL needSeparator = NO;
        if (haveShortSelection) {
            shortSelectedText = [self.delegate contextMenuSelectedText:self capped:0];
            NSArray<iTermTuple<NSString *, NSString *> *> *synonyms = [shortSelectedText helpfulSynonyms];
            needSeparator = synonyms.count > 0;
            for (iTermTuple<NSString *, NSString *> *tuple in synonyms) {
                NSMenuItem *theItem = [[NSMenuItem alloc] init];
                theItem.title = tuple.firstObject;
                theItem.representedObject = tuple.secondObject;
                theItem.target = self;
                theItem.action = @selector(copyString:);
                [theMenu addItem:theItem];
            }
            if ([iTermContextMenuUtilities addMenuItemForColors:shortSelectedText menu:theMenu index:theMenu.itemArray.count]) {
                needSeparator = YES;
            }
            const NSInteger initialCount = theMenu.itemArray.count;
            if ([iTermContextMenuUtilities addMenuItemForBase64Encoded:shortSelectedText menu:theMenu index:theMenu.itemArray.count selector:@selector(copyData:) target:nil] > initialCount) {
                needSeparator = YES;
            }
        }
        if ([self.delegate contextMenuSelectionIsReasonable:self]) {
            NSString *text = [self.delegate contextMenuSelectedText:self capped:0];
            NSInteger initialCount = theMenu.itemArray.count;
            [iTermContextMenuUtilities addMenuItemsForNumericConversions:text menu:theMenu index:theMenu.itemArray.count selector:@selector(copyString:) target:nil];

            NSString *unstrippedSelectedText = [self.delegate contextMenuUnstrippedSelectedText:self capped:0];
            if ([iTermContextMenuUtilities addMenuItemsToCopyBase64:unstrippedSelectedText
                                                               menu:theMenu
                                                              index:theMenu.itemArray.count
                                                  selectorForString:@selector(copyString:)
                                                    selectorForData:@selector(copyData:)
                                                             target:self] > initialCount) {
                needSeparator = YES;
            }

            NSArray<iTermSelectionReplacement *> *replacements = [self.delegate contextMenuSelectionReplacements:self];
            if (replacements.count > 0){
                [theMenu addItem:[NSMenuItem separatorItem]];
            }
            for (iTermSelectionReplacement *replacement in replacements) {
                NSMenuItem *item = [[NSMenuItem alloc] init];
                item.target = self;
                item.representedObject = replacement;
                [theMenu addItem:item];
                needSeparator = YES;

                switch (replacement.kind) {
                    case iTermSelectionReplacementKindJson:
                        item.title = NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.replace_with_pretty_printed_json.8c2a8480", nil, NSBundle.mainBundle, @"Replace with Pretty-Printed JSON", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:).");
                        item.action = @selector(replaceWithPrettyJSON:);
                        break;

                    case iTermSelectionReplacementKindBase64Decode:
                        item.title = NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.replace_with_base64_decoded_value.e1eb2c47", nil, NSBundle.mainBundle, @"Replace with Base64-Decoded Value", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:).");
                        item.action = @selector(replaceWithBase64Decoded:);
                        break;

                    case iTermSelectionReplacementKindBase64Encode:
                        item.title = NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.replace_with_base64_encoded_value.c55f5c61", nil, NSBundle.mainBundle, @"Replace with Base64-Encoded Value", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:).");
                        item.action = @selector(replaceWithBase64Encoded:);
                        break;
                }
            }
        }
        if (needSeparator) {
            [theMenu addItem:[NSMenuItem separatorItem]];
        }
    }
    iTermSelection *selection = [self.delegate contextMenuSelection:self];
    if (selection.length == 1) {
        iTermSubSelection *sub = selection.allSubSelections.firstObject;
        [self.delegate contextMenu:self withRelativeCoord:sub.absRange.coordRange.start block:^(VT100GridCoord coord) {
            iTermTextExtractor *extractor = [self.delegate contextMenuTextExtractor:self];
            const screen_char_t c = [extractor characterAt:coord];
            NSString *description = ScreenCharDescription(c);
            if (description) {
                iTermExternalAttribute *ea = [extractor externalAttributesAt:coord];
                if (ea) {
                    description = [NSString stringWithFormat:@"%@; %@", description, [ea humanReadableDescription]];
                }
                NSMenuItem *theItem = [[NSMenuItem alloc] init];
                theItem.title = description;
                [theMenu addItem:theItem];
            }
        }];
    }

    // Menu items for acting on text selections
    const BOOL sshIntegrationDownload = [self.delegate contextMenuWillDownloadWithSSHIntegrationOnAbsLine:selection.lastAbsRange.coordRange.start.y];

    __block NSString *scpTitle = sshIntegrationDownload ? NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.download_using_ssh_integration.7694fa3e", nil, NSBundle.mainBundle, @"Download using SSH Integration", @"User-facing text in iTermTextViewContextMenuHelper (source UI).") : NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.download_with_scp.81fd4e9c", nil, NSBundle.mainBundle, @"Download with scp", @"User-facing text in iTermTextViewContextMenuHelper (source UI).");
    if (haveShortSelection) {
        [self.delegate contextMenu:self withRelativeCoord:selection.lastAbsRange.coordRange.start block:^(VT100GridCoord coord) {
            SCPPath *scpPath = [self.delegate contextMenu:self scpPathForFile:shortSelectedText onLine:coord.y];
            if (scpPath) {
                scpTitle = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.download_from.c5d90404", nil, NSBundle.mainBundle, @"Download %@ from %@", @"User-facing context menu item with download method and host."),
                            sshIntegrationDownload ? NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.using_ssh_integration.483a4c6a", nil, NSBundle.mainBundle, @"using SSH Integration", @"Download method shown in a context menu item.") : NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.with_scp.f1fba50c", nil, NSBundle.mainBundle, @"with scp", @"Download method shown in a context menu item."),
                            scpPath.hostname];
            }
        }];
    }

    void (^add)(NSString *, SEL) = ^(NSString *title, SEL selector) {
        [theMenu addItemWithTitle:title
                         action:selector
                    keyEquivalent:@""];
        [[theMenu itemAtIndex:[theMenu numberOfItems] - 1] setTarget:self];
    };
    add(scpTitle, @selector(downloadWithSCP:));
    if (shortSelectedText) {
        add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.open_selection_as_url.5f192591", nil, NSBundle.mainBundle, @"Open Selection as URL", @"User-facing context menu item."), @selector(browse:));
        if ([[NSWorkspace sharedWorkspace] it_urlIsConditionallyLocallyOpenable:[NSURL URLWithString:shortSelectedText]]) {
            add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.open_url_in_vertical_split_pane.c9610769", nil, NSBundle.mainBundle, @"Open URL in Vertical Split Pane", @"User-facing context menu item."), @selector(openURLInVerticalSplitPane:));
            add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.open_url_in_horizontal_split_pane.519c1047", nil, NSBundle.mainBundle, @"Open URL in Horizontal Split Pane", @"User-facing context menu item."), @selector(openURLInHorizontalSplitPane:));
            [theMenu addItem:[NSMenuItem separatorItem]];
        }
    }
    if (shortSelectedText && [self.delegate contextMenu:self canQuickLookURL:[NSURL URLWithUserSuppliedString:shortSelectedText]]) {
        add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.quick_look_link.0fe62800", nil, NSBundle.mainBundle, @"Quick Look Link", @"User-facing context menu item."), @selector(quickLook:));
    }
    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.search_the_web_for_selection.6ddad810", nil, NSBundle.mainBundle, @"Search the Web for Selection", @"User-facing context menu item."), @selector(searchInBrowser:));

    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.send_email_to_selected_address.a26f27a1", nil, NSBundle.mainBundle, @"Send Email to Selected Address", @"User-facing context menu item."), @selector(mail:));
    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.add_trigger.f2bbdcd6", nil, NSBundle.mainBundle, @"Add Trigger…", @"User-facing context menu item."), @selector(addTrigger:));

    // Separator
    [theMenu addItem:[NSMenuItem separatorItem]];

    // Custom actions
    if ([selection hasSelection] &&
        [selection length] < kMaxSelectedTextLengthForCustomActions &&
        coord.y >= 0) {
        NSString *selectedText = [self.delegate contextMenuSelectedText:self capped:1024];
        if ([self addCustomActionsToMenu:theMenu matchingText:selectedText line:coord.y]) {
            [theMenu addItem:[NSMenuItem separatorItem]];
        }
    }

    if ([self addAPIProvidedMenuItems:theMenu]) {
        [theMenu addItem:[NSMenuItem separatorItem]];
    }

    // Split pane options
    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.split_pane_vertically.d35bb6bf", nil, NSBundle.mainBundle, @"Split Pane Vertically", @"User-facing context menu item."), @selector(splitTextViewVertically:));
    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.split_pane_horizontally.764a93a1", nil, NSBundle.mainBundle, @"Split Pane Horizontally", @"User-facing context menu item."), @selector(splitTextViewHorizontally:));
    if ([iTermPreferences boolForKey:kPreferenceKeyMenuActionImages]) {
        NSInteger n = theMenu.numberOfItems;
        theMenu.itemArray[n - 2].image = [NSImage imageWithSystemSymbolName:@"square.split.2x1.fill"
                                                   accessibilityDescription:nil];
        theMenu.itemArray[n - 1].image = [NSImage imageWithSystemSymbolName:@"square.split.1x2.fill"
                                                   accessibilityDescription:nil];
    }

    // Separator
    [theMenu addItem:[NSMenuItem separatorItem]];

    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.move_session_to_split_pane.3b6be9b4", nil, NSBundle.mainBundle, @"Move Session to Split Pane", @"User-facing context menu item."), @selector(movePane:));
    if ([self.delegate contextMenuCurrentTabHasMultipleSessions:self]) {
        NSMenuItem *item = [theMenu addItemWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.move_session_to_tab.9a738481", nil, NSBundle.mainBundle, @"Move Session to Tab", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:).")
                                              action:@selector(moveSessionToTab:)
                                       keyEquivalent:@""];
        item.representedObject = [self.delegate contextMenuSessionScope:self].ID;
    }
    [theMenu addItemWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.move_session_to_window.15636019", nil, NSBundle.mainBundle, @"Move Session to Window", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:).")
                     action:@selector(moveSessionToWindow:)
                keyEquivalent:@""];
    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.swap_with_session.642b9b09", nil, NSBundle.mainBundle, @"Swap With Session…", @"User-facing context menu item."), @selector(swapSessions:));

    // Separator
    [theMenu addItem:[NSMenuItem separatorItem]];

    // Copy,  paste, and save
    [theMenu addItemWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.copy",
                                                                nil,
                                                                [NSBundle bundleForClass:[self class]],
                                                                @"Copy",
                                                                @"Context menu item")
                     action:@selector(copy:) keyEquivalent:@""];

    // Don't attempt to extract a URL from invalid coordinates (-1,-1) if opened from the session titlebar
    if (coord.x >= 0 && coord.y >= 0) {
        iTermTextExtractor *extractor = [self.delegate contextMenuTextExtractor:self];
        NSString *urlID;
        NSURL *url = [extractor urlOfHypertextLinkAt:coord urlId:&urlID target:nil];
        if (url) {
            NSMenuItem *item = [theMenu addItemWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.copy_link_address.c8270401", nil, NSBundle.mainBundle, @"Copy Link Address", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:).") action:@selector(copyLinkAddress:) keyEquivalent:@""];
            item.target = self;
            item.representedObject = url;
        } else {
            // Offer to copy the URL that ⌘-click would open, stitching hard newlines
            // out of wrapped URLs so a clean link can be pasted elsewhere. Only shown
            // when there's genuinely a URL under the cursor.
            NSURL *detectedURL = [_urlActionHelper urlForCopyAtCoord:coord];
            if (detectedURL) {
                NSMenuItem *item = [theMenu addItemWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.copy_url.b26d1037", nil, NSBundle.mainBundle, @"Copy URL", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:).") action:@selector(copyDetectedURL:) keyEquivalent:@""];
                item.target = self;
                item.representedObject = detectedURL;
            }
        }
    }
    
    [theMenu addItemWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.paste",
                                                                nil,
                                                                [NSBundle bundleForClass:[self class]],
                                                                @"Paste",
                                                                @"Context menu item")
                     action:@selector(paste:) keyEquivalent:@""];
    [theMenu addItemWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.save",
                                                                nil,
                                                                [NSBundle bundleForClass:[self class]],
                                                                @"Save",
                                                                @"Context menu item")
                     action:@selector(saveDocumentAs:) keyEquivalent:@""];

    // Separator
    [theMenu addItem:[NSMenuItem separatorItem]];

    // Select all
    [theMenu addItemWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.select_all",
                                                                nil,
                                                                [NSBundle bundleForClass:[self class]],
                                                                @"Select All",
                                                                @"Context menu item")
                     action:@selector(selectAll:) keyEquivalent:@""];

    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.send_selection.910776d4", nil, NSBundle.mainBundle, @"Send Selection", @"User-facing context menu item."), @selector(sendSelection:));
    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.save_selection_as_snippet.59ffe6d6", nil, NSBundle.mainBundle, @"Save Selection as Snippet", @"User-facing context menu item."), @selector(saveSelectionAsSnippet:));

    // Clear buffer
    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.clear_buffer.5a559eb3", nil, NSBundle.mainBundle, @"Clear Buffer", @"User-facing context menu item."), @selector(clearTextViewBuffer:));

    // Make note
    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.annotate_selection.7b9215ff", nil, NSBundle.mainBundle, @"Annotate Selection", @"User-facing context menu item."), @selector(addNote:));
    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.reveal_annotation.60ea3d0f", nil, NSBundle.mainBundle, @"Reveal Annotation", @"User-facing context menu item."), @selector(showNotes:));

    // Separator
    [theMenu addItem:[NSMenuItem separatorItem]];

    // Edit Session
    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.edit_session.0f315055", nil, NSBundle.mainBundle, @"Edit Session...", @"User-facing context menu item."), @selector(editTextViewSession:));

    // Separator
    [theMenu addItem:[NSMenuItem separatorItem]];

    // Toggle broadcast
    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.toggle_broadcasting_input.0afbc39e", nil, NSBundle.mainBundle, @"Toggle Broadcasting Input", @"User-facing context menu item."), @selector(toggleBroadcastingInput:));

    // Lock pane
    {
        NSMenuItem *lockItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.lock_pane.16012f00", nil, NSBundle.mainBundle, @"Lock Pane", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:).")
                                                          action:@selector(toggleLock:)
                                                   keyEquivalent:@""];
        lockItem.target = self;
        lockItem.state = [self.delegate contextMenuIsLocked:self] ? NSControlStateValueOn : NSControlStateValueOff;
        [theMenu addItem:lockItem];
    }

    // Lock all panes in tab (with Option-key alternate)
    if ([self.delegate contextMenuCurrentTabHasMultipleSessions:self]) {
        BOOL allLocked = [self.delegate contextMenuAreAllPanesInTabLocked:self];
        BOOL anyLocked = [self.delegate contextMenuIsAnyPaneInTabLocked:self];

        // Primary item: shows contextual action based on current state
        // Alternate item: shows opposite action when Option is held (only if useful)
        if (allLocked) {
            // Primary: Unlock (since all are locked)
            // No alternate needed - Lock All would be a no-op
            NSMenuItem *unlockItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.unlock_all_panes_in_tab.f7aa3ccd", nil, NSBundle.mainBundle, @"Unlock All Panes in Tab", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:).")
                                                                action:@selector(unlockAllInTab:)
                                                         keyEquivalent:@""];
            unlockItem.target = self;
            [theMenu addItem:unlockItem];
        } else {
            // Primary: Lock (since not all are locked)
            NSMenuItem *lockItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.lock_all_panes_in_tab.ff6b4847", nil, NSBundle.mainBundle, @"Lock All Panes in Tab", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:).")
                                                              action:@selector(lockAllInTab:)
                                                       keyEquivalent:@""];
            lockItem.target = self;
            [theMenu addItem:lockItem];

            // Alternate: Unlock (Option-key) - only if at least one pane is locked
            if (anyLocked) {
                NSMenuItem *unlockItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.unlock_all_panes_in_tab.f7aa3ccd", nil, NSBundle.mainBundle, @"Unlock All Panes in Tab", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:).")
                                                                    action:@selector(unlockAllInTab:)
                                                             keyEquivalent:@""];
                unlockItem.target = self;
                unlockItem.alternate = YES;
                unlockItem.keyEquivalentModifierMask = NSEventModifierFlagOption;
                [theMenu addItem:unlockItem];
            }
        }
    }

    if ([self.delegate contextMenuHasCoprocess:self]) {
        add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.stop_coprocess.6b7307c1", nil, NSBundle.mainBundle, @"Stop Coprocess", @"User-facing context menu item."), @selector(stopCoprocess:));
    }

    // Separator
    [theMenu addItem:[NSMenuItem separatorItem]];

    // Close current pane
    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.close.7d9eb7ac", nil, NSBundle.mainBundle, @"Close", @"User-facing context menu item."), @selector(closeTextViewSession:));
    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.restart.6b983a81", nil, NSBundle.mainBundle, @"Restart", @"User-facing context menu item."), @selector(restartSession:));

    [self.delegate contextMenu:self amend:theMenu];

    // Separator
    [theMenu addItem:[NSMenuItem separatorItem]];
    add(NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.bury.ab00d5f0", nil, NSBundle.mainBundle, @"Bury", @"User-facing context menu item."), @selector(bury:));

    // Terminal State
    [theMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *terminalState = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.terminal_state.c4006156", nil, NSBundle.mainBundle, @"Terminal State", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:).") action:nil keyEquivalent:@""];
    terminalState.submenu = [[NSMenu alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.terminal_state.c4006156", nil, NSBundle.mainBundle, @"Terminal State", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:).")];

    struct {
        NSString *title;
        SEL action;
    } terminalStateDecls[] = {
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.alternate_screen.6c52306f", nil, NSBundle.mainBundle, @"Alternate Screen", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:)."), @selector(terminalStateToggleAlternateScreen:) },
        { nil, nil },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.focus_reporting.934f30cc", nil, NSBundle.mainBundle, @"Focus Reporting", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:)."), @selector(terminalStateToggleFocusReporting:) },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.mouse_reporting.d4d68999", nil, NSBundle.mainBundle, @"Mouse Reporting", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:)."), @selector(terminalStateToggleMouseReporting:) },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.paste_bracketing.bd0f74ae", nil, NSBundle.mainBundle, @"Paste Bracketing", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:)."), @selector(terminalStateTogglePasteBracketing:) },
        { nil, nil },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.application_cursor.d4e748b9", nil, NSBundle.mainBundle, @"Application Cursor", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:)."), @selector(terminalStateToggleApplicationCursor:) },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.application_keypad.5aeb4e2a", nil, NSBundle.mainBundle, @"Application Keypad", @"User-facing text in iTermTextViewContextMenuHelper (menuAtCoord:)."), @selector(terminalStateToggleApplicationKeypad:) },
        { nil, nil },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.standard_key_reporting_mode.c25f37b7", nil, NSBundle.mainBundle, @"Standard Key Reporting Mode", @"User-facing terminal state menu item."), @selector(terminalToggleKeyboardMode:) },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.modifyotherkeys_mode_1.15d924fc", nil, NSBundle.mainBundle, @"modifyOtherKeys Mode 1", @"User-facing terminal state menu item."), @selector(terminalToggleKeyboardMode:) },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.modifyotherkeys_mode_2.ff775042", nil, NSBundle.mainBundle, @"modifyOtherKeys Mode 2", @"User-facing terminal state menu item."), @selector(terminalToggleKeyboardMode:) },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.csi_u_mode.21647084", nil, NSBundle.mainBundle, @"CSI u Mode", @"User-facing terminal state menu item."), @selector(terminalToggleKeyboardMode:) },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.raw_key_reporting_mode.b6cc843f", nil, NSBundle.mainBundle, @"Raw Key Reporting Mode", @"User-facing terminal state menu item."), @selector(terminalToggleKeyboardMode:) },
        { nil, nil },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.disambiguate_escape.f6c03214", nil, NSBundle.mainBundle, @"Disambiguate Escape", @"User-facing terminal state menu item."), @selector(terminalToggleKeyboardMode:) },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.report_all_event_types.221f4bb4", nil, NSBundle.mainBundle, @"Report All Event Types", @"User-facing terminal state menu item."), @selector(terminalToggleKeyboardMode:) },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.report_alternate_keys.1ea57b35", nil, NSBundle.mainBundle, @"Report Alternate Keys", @"User-facing terminal state menu item."), @selector(terminalToggleKeyboardMode:) },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.report_all_keys_as_escape_codes.b9ccb6fd", nil, NSBundle.mainBundle, @"Report All Keys as Escape Codes", @"User-facing terminal state menu item."), @selector(terminalToggleKeyboardMode:) },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.report_associated_text.65fc5867", nil, NSBundle.mainBundle, @"Report Associated Text", @"User-facing terminal state menu item."), @selector(terminalToggleKeyboardMode:) },
        { nil, nil },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.literal_controls.888eb5d8", nil, NSBundle.mainBundle, @"Literal Controls", @"User-facing terminal state menu item."), @selector(terminalStateToggleLiteralMode:)},
        { nil, nil },
        { NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.emulation_level.d9a6557c", nil, NSBundle.mainBundle, @"Emulation Level", @"User-facing terminal state menu item."), nil }
    };
    NSInteger j = 1;
    for (size_t i = 0; i < sizeof(terminalStateDecls) / sizeof(*terminalStateDecls); i++) {
        if (!terminalStateDecls[i].title) {
            [terminalState.submenu addItem:[NSMenuItem separatorItem]];
            continue;
        }
        NSMenuItem *item = [terminalState.submenu addItemWithTitle:terminalStateDecls[i].title
                                                            action:terminalStateDecls[i].action
                                                     keyEquivalent:@""];
        item.tag = j;
        j += 1;
        item.state = [self.delegate contextMenu:self terminalStateForMenuItem:item];
    }

    NSMenuItem *levelItem = terminalState.submenu.itemArray.lastObject;
    NSMenu *levelMenu = [[NSMenu alloc] init];
    levelItem.submenu = levelMenu;

    struct {
        NSString *title;
        SEL action;
    } emulationLevelDecls[] = {
        { @"VT100", @selector(terminalStateSetEmulationLevel:) },
        { @"VT200", @selector(terminalStateSetEmulationLevel:) },
        { @"VT300", @selector(terminalStateSetEmulationLevel:) },
        { @"VT400", @selector(terminalStateSetEmulationLevel:) },
        { @"VT500", @selector(terminalStateSetEmulationLevel:) },
    };
    j = 100;
    for (size_t i = 0; i < sizeof(emulationLevelDecls) / sizeof(*emulationLevelDecls); i++) {
        if (!emulationLevelDecls[i].title) {
            [levelMenu addItem:[NSMenuItem separatorItem]];
            continue;
        }
        NSMenuItem *item = [levelMenu addItemWithTitle:emulationLevelDecls[i].title
                                                action:emulationLevelDecls[i].action
                                         keyEquivalent:@""];
        item.tag = j;
        j += 100;
        item.state = [self.delegate contextMenu:self terminalStateForMenuItem:item];
    }

    [theMenu addItem:terminalState];

    [self.delegate contextMenu:self addContextMenuItems:theMenu];

    [self addMainMenuIfNeededTo:theMenu];

    return theMenu;
}

- (void)addMainMenuIfNeededTo:(NSMenu *)menu {
    if (![[iTermApplication sharedApplication] isUIElement]) {
        return;
    }
    NSMenuItem *mainMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.main_menu.35f9896e", nil, NSBundle.mainBundle, @"Main Menu", @"User-facing text in iTermTextViewContextMenuHelper (addMainMenuIfNeededTo:).") action:nil keyEquivalent:@""];
    NSMenu *copyOfMainMenu = [[NSMenu alloc] init];
    for (NSMenuItem *mainMenuItem in NSApp.mainMenu.itemArray) {
        [self addCopyOfItem:mainMenuItem to:copyOfMainMenu];
    }
    mainMenuItem.submenu = copyOfMainMenu;
    [menu insertItem:mainMenuItem atIndex:0];
    [menu insertItem:[NSMenuItem separatorItem] atIndex:1];
}

- (void)addCopyOfItem:(NSMenuItem *)item to:(NSMenu *)menu {
    [menu addItem:[item copy]];
}

- (SEL)selectorForSmartSelectionAction:(NSDictionary *)action {
    NSDictionary<NSNumber *, NSString *> *dictionary = [self smartSelectionActionSelectorDictionary];
    ContextMenuActions contextMenuAction = [ContextMenuActionPrefsController actionForActionDict:action];
    return NSSelectorFromString(dictionary[@(contextMenuAction)]);
}

- (BOOL)addCustomActionsToMenu:(NSMenu *)theMenu matchingText:(NSString *)textWindow line:(int)line {
    BOOL didAdd = NO;
    NSArray *rulesArray = [self.delegate contextMenuSmartSelectionRules:self] ?: [SmartSelectionController defaultRules];
    const int numRules = [rulesArray count];

    DLog(@"Looking for custom actions. Evaluating smart selection rules…");
    DLog(@"text window is: %@", textWindow);
    for (int j = 0; j < numRules; j++) {
        NSDictionary *rule = [rulesArray objectAtIndex:j];
        NSArray *actions = [SmartSelectionController actionsInRule:rule];
        if (!actions.count) {
            DLog(@"Skipping rule with no actions:\n%@", rule);
            continue;
        }

        DLog(@"Evaluating rule:\n%@", rule);
        NSString *regex = [SmartSelectionController regexInRule:rule];
        for (int i = 0; i <= textWindow.length; i++) {
            NSString *substring = [textWindow substringWithRange:NSMakeRange(i, [textWindow length] - i)];
            NSError *regexError = nil;
            NSArray *components = [substring captureComponentsMatchedByRegex:regex
                                                                     options:0
                                                                       range:NSMakeRange(0, [substring length])
                                                                       error:&regexError];
            if (components.count) {
                DLog(@"Components for %@ are %@", regex, components);
                for (NSDictionary *action in actions) {
                    SEL mySelector = [self selectorForSmartSelectionAction:action];
                    NSString *workingDirectory = [self.delegate contextMenu:self workingDirectoryOnLine:line];
                    id<VT100RemoteHostReading> remoteHost = [self.delegate contextMenu:self remoteHostOnLine:line];
                    NSString *theTitle =
                        [ContextMenuActionPrefsController titleForActionDict:action
                                                       withCaptureComponents:components
                                                            workingDirectory:workingDirectory
                                                                  remoteHost:remoteHost];

                    NSMenuItem *theItem = [[NSMenuItem alloc] initWithTitle:theTitle
                                                                     action:mySelector
                                                              keyEquivalent:@""];
                    NSDictionary *dict = [@{ iTermSmartSelectionActionContextKeyAction: action,
                                             iTermSmartSelectionActionContextKeyComponents: components,
                                             iTermSmartSelectionActionContextKeyWorkingDirectory: workingDirectory ?: [NSNull null],
                                             iTermSmartSelectionActionContextKeyRemoteHost: (id)remoteHost ?: (id)[NSNull null]} dictionaryByRemovingNullValues];
                    [theItem setRepresentedObject:dict];
                    [theItem setTarget:self];
                    [theMenu addItem:theItem];
                    didAdd = YES;
                }
                break;
            }
        }
    }
    return didAdd;
}

- (BOOL)addAPIProvidedMenuItems:(NSMenu *)theMenu {
    NSArray<ITMRPCRegistrationRequest *> *reqs = [iTermAPIHelper contextMenuProviderRegistrationRequests];
    if (reqs.count == 0) {
        return NO;
    }
    [theMenu addItem:[NSMenuItem separatorItem]];
    for (ITMRPCRegistrationRequest *req in reqs) {
        NSMenuItem *theItem = [[NSMenuItem alloc] initWithTitle:req.contextMenuAttributes.displayName
                                                         action:@selector(apiMenuItem:)
                                                  keyEquivalent:@""];
        theItem.representedObject = req.contextMenuAttributes.uniqueIdentifier;
        theItem.target = self;
        [theMenu addItem:theItem];
    }
    return YES;
}

- (NSMenu *)menuForMark:(id<VT100ScreenMarkReading>)mark directory:(NSString *)directory {
    NSMenu *theMenu;

    // Allocate a menu
    theMenu = [[NSMenu alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.contextual_menu.3db60c37", nil, NSBundle.mainBundle, @"Contextual Menu", @"User-facing text in iTermTextViewContextMenuHelper (menuForMark:directory:).")];

    NSMenuItem *theItem = [[NSMenuItem alloc] init];
    theItem.title = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.command.7c488a07", nil, NSBundle.mainBundle, @"Command: %@", @"User-facing text in iTermTextViewContextMenuHelper (title)."), mark.firstLineOfCommand];
    [theMenu addItem:theItem];

    if (directory) {
        theItem = [[NSMenuItem alloc] init];
        theItem.title = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.directory.48014040", nil, NSBundle.mainBundle, @"Directory: %@", @"User-facing text in iTermTextViewContextMenuHelper (title)."), directory];
        [theMenu addItem:theItem];
    }

    theItem = [[NSMenuItem alloc] init];
    theItem.title = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.return_code_d.f6a6dd27", nil, NSBundle.mainBundle, @"Return code: %d", @"User-facing text in iTermTextViewContextMenuHelper (title)."), mark.code];
    [theMenu addItem:theItem];

    if (mark.startDate) {
        theItem = [[NSMenuItem alloc] init];
        NSTimeInterval runningTime;
        if (mark.endDate) {
            runningTime = [mark.endDate timeIntervalSinceDate:mark.startDate];
        } else {
            runningTime = -[mark.startDate timeIntervalSinceNow];
        }
        int hours = runningTime / 3600;
        int minutes = ((int)runningTime % 3600) / 60;
        int seconds = (int)runningTime % 60;
        int millis = (int) ((runningTime - floor(runningTime)) * 1000);
        if (hours > 0) {
            theItem.title = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.running_time_d_02d_02d.5215a41a", nil, NSBundle.mainBundle, @"Running time: %d:%02d:%02d", @"User-facing text in iTermTextViewContextMenuHelper (title)."),
                             hours, minutes, seconds];
        } else {
            theItem.title = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.running_time_d_02d_03d.7cc27a08", nil, NSBundle.mainBundle, @"Running time: %d:%02d.%03d", @"User-facing text in iTermTextViewContextMenuHelper (title)."),
                             minutes, seconds, millis];
        }
        [theMenu addItem:theItem];
    }

    [theMenu addItem:[NSMenuItem separatorItem]];

    theItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.re_run_command.cf5733c2", nil, NSBundle.mainBundle, @"Re-run Command", @"User-facing text in iTermTextViewContextMenuHelper (menuForMark:directory:).")
                                         action:@selector(reRunCommand:)
                                  keyEquivalent:@""];
    theItem.target = self;
    [theItem setRepresentedObject:mark.fullCommand];
    [theMenu addItem:theItem];

    theItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.contextmenu.itermtextviewcontextmenuhelper.select_command_output.f98ec114", nil, NSBundle.mainBundle, @"Select Command Output", @"User-facing text in iTermTextViewContextMenuHelper (menuForMark:directory:).")
                                         action:@selector(selectCommandOutput:)
                                  keyEquivalent:@""];
    theItem.target = self;
    [theItem setRepresentedObject:mark];
    [theMenu addItem:theItem];

    return theMenu;
}

#pragma mark - Context Menu Actions

- (void)foldCommandMark:(NSMenuItem *)sender {
    [self.delegate contextMenuFoldMark:sender.representedObject];
}

- (void)unfoldMark:(NSMenuItem *)sender {
    [self.delegate contextMenuUnfoldMark:sender.representedObject];
}

- (void)removeNamedMark:(id)sender {
    id<VT100ScreenMarkReading> mark = [sender representedObject];
    RLog(@"Remove named mark %@", RLogRedact(mark, mark.redactedDescription));
    if (mark.name) {
        [_delegate contextMenu:self removeNamedMark:mark];
    }
}

- (void)revealCommandInfo:(id)sender {
    id<VT100ScreenMarkReading> mark = [sender representedObject];
    RLog(@"Reveal command info %@", RLogRedact(mark, mark.redactedDescription));
    if (!mark || ![mark conformsToProtocol:@protocol(VT100ScreenMarkReading)]) {
        DLog(@"Bogus");
        return;
    }
    [_delegate contextMenu:self showCommandInfoForMark:mark];
}

- (void)contextMenuActionOpenFile:(id)sender {
    DLog(@"Open file: '%@'", [sender representedObject]);
    NSDictionary *dict = [sender representedObject];
    [self evaluateCustomActionDictionary:dict completion:^(NSString *value) {
        if (!value) {
            return;
        }
        [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:[value stringByExpandingTildeInPath]]];
    }];
}

- (void)contextMenuActionOpenURL:(id)sender {
    [self evaluateCustomActionDictionary:[sender representedObject] completion:^(NSString *value) {
        if (!value) {
            return;
        }
        NSURL *url = [NSURL URLWithUserSuppliedString:value];
        if (url) {
            DLog(@"Open URL: %@", [sender representedObject]);
            [[NSWorkspace sharedWorkspace] openURL:url];
        } else {
            DLog(@"%@ is not a URL", [sender representedObject]);
        }
    }];
}

- (void)contextMenuActionRunCommand:(id)sender {
    [self evaluateCustomActionDictionary:[sender representedObject] completion:^(NSString *value) {
        DLog(@"Run command: %@", value);
        if (!value) {
            return;
        }
        [self runCommand:value];
    }];
}

- (void)contextMenuActionRunCommandInWindow:(id)sender {
    [self evaluateCustomActionDictionary:[sender representedObject] completion:^(NSString *value) {
        DLog(@"Run command: %@", value);
        if (!value) {
            return;
        }
        [self.delegate contextMenu:self runCommandInWindow:value];
    }];
}

- (void)contextMenuActionCopy:(id)sender {
    DLog(@"Copy");
    URLAction *action = [URLAction castFrom:sender];
    NSDictionary *dict = [NSDictionary castFrom:[sender representedObject]];
    NSDictionary *actionDict = dict[iTermSmartSelectionActionContextKeyAction];
    if (action && [[ContextMenuActionPrefsController parameterInActionDict:actionDict] length] == 0) {
        // Preserve the historical cmd-click behavior of copying the matched
        // range so that the user's copy-with-styles preference is honored.
        [self.delegate contextMenu:self copyRangeAccordingToUserPreferences:action.visualRange];
        return;
    }
    [self evaluateCustomActionDictionary:[sender representedObject] completion:^(NSString *value) {
        DLog(@"Copy text: %@", value);
        if (!value) {
            return;
        }
        [self.delegate contextMenu:self copyText:value];
    }];
}

- (void)runCommand:(NSString *)command {
    [self.delegate contextMenu:self runCommandInBackground:command];
}

- (void)contextMenuActionRunCoprocess:(id)sender {
    [self evaluateCustomActionDictionary:[sender representedObject] completion:^(NSString *value) {
        DLog(@"Run coprocess: %@", value);
        if (!value) {
            return;
        }
        [self.delegate contextMenu:self runCoprocess:value];
    }];
}

- (void)contextMenuActionSendText:(id)sender {
    [self evaluateCustomActionDictionary:[sender representedObject] completion:^(NSString *value) {
        DLog(@"Send text: %@", value);
        if (!value) {
            return;
        }
        [self.delegate contextMenu:self insertText:value];
    }];
}

- (BOOL)smartSelectionActionsShouldUseInterpolatedStrings {
    return [self.delegate contextMenuSmartSelectionActionsShouldUseInterpolatedStrings:self];
}

- (void)evaluateCustomActionDictionary:(NSDictionary *)dict completion:(void (^)(NSString * _Nullable))completion {
    NSDictionary *action = dict[iTermSmartSelectionActionContextKeyAction];
    NSArray *components = dict[iTermSmartSelectionActionContextKeyComponents];
    NSString *workingDirectory = [dict[iTermSmartSelectionActionContextKeyWorkingDirectory] nilIfNull];
    id<VT100RemoteHostReading> remoteHost = [dict[iTermSmartSelectionActionContextKeyRemoteHost] nilIfNull];

    iTermVariableScope *myScope = [[self.delegate contextMenuSessionScope:self] copy];
    [myScope setValue:workingDirectory forVariableNamed:iTermVariableKeySessionPath];
    [myScope setValue:remoteHost.hostname forVariableNamed:iTermVariableKeySessionHostname];
    [myScope setValue:remoteHost.username forVariableNamed:iTermVariableKeySessionUsername];
    [ContextMenuActionPrefsController computeParameterForActionDict:action
                                              withCaptureComponents:components
                                                   useInterpolation:[self smartSelectionActionsShouldUseInterpolatedStrings]
                                                              scope:myScope
                                                              owner:[self.delegate contextMenuOwner:self]
                                                         completion:completion];
}

- (NSString *)evaluateCustomActionDictionary:(NSDictionary *)dict {
    NSDictionary *action = dict[iTermSmartSelectionActionContextKeyAction];
    NSArray *components = dict[iTermSmartSelectionActionContextKeyComponents];
    NSString *workingDirectory = [dict[iTermSmartSelectionActionContextKeyWorkingDirectory] nilIfNull];
    id<VT100RemoteHostReading> remoteHost = [dict[iTermSmartSelectionActionContextKeyRemoteHost] nilIfNull];

    iTermVariableScope *myScope = [[self.delegate contextMenuSessionScope:self] copy];
    [myScope setValue:workingDirectory forVariableNamed:iTermVariableKeySessionPath];
    [myScope setValue:remoteHost.hostname forVariableNamed:iTermVariableKeySessionHostname];
    [myScope setValue:remoteHost.username forVariableNamed:iTermVariableKeySessionUsername];
    return [ContextMenuActionPrefsController computeParameterForActionDict:action
                                              withCaptureComponents:components
                                                   useInterpolation:[self smartSelectionActionsShouldUseInterpolatedStrings]
                                                              scope:myScope
                                                              owner:[self.delegate contextMenuOwner:self]];
}

- (void)downloadWithSCP:(id)sender {
    iTermSelection *selection = [self.delegate contextMenuSelection:self];
    if (![selection hasSelection]) {
        return;
    }
    NSString *selectedText = [[self.delegate contextMenuSelectedText:self capped:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *parts = [selectedText componentsSeparatedByString:@"\n"];
    if (parts.count != 1) {
        return;
    }
    [self.delegate contextMenu:self
        withRelativeCoordRange:selection.lastAbsRange.coordRange
                         block:^(VT100GridCoordRange coordRange) {
        SCPPath *scpPath = [self.delegate contextMenu:self scpPathForFile:parts[0] onLine:coordRange.start.y];
        [_urlActionHelper downloadFileAtSecureCopyPath:scpPath displayName:selectedText locationInView:coordRange];
    }];
}

- (void)browse:(id)sender {
    [_urlActionHelper findUrlInString:[self.delegate contextMenuSelectedText:self capped:0]
                  andOpenInBackground:NO
                                style:iTermOpenStyleTab];
}

- (void)openURLInVerticalSplitPane:(id)sender {
    [_urlActionHelper findUrlInString:[self.delegate contextMenuSelectedText:self capped:0]
                  andOpenInBackground:NO
                                style:iTermOpenStyleVerticalSplit];
}

- (void)openURLInHorizontalSplitPane:(id)sender {
    [_urlActionHelper findUrlInString:[self.delegate contextMenuSelectedText:self capped:0]
                  andOpenInBackground:NO
                                style:iTermOpenStyleHorizontalSplit];
}

- (void)quickLook:(id)sender {
    NSString *string = [self.delegate contextMenuSelectedText:self capped:0];
    NSURL *url = [NSURL URLWithUserSuppliedString:string];
    if (!url) {
        return;
    }
    [self.delegate contextMenuHandleQuickLook:self
                                          url:url
                             windowCoordinate:NSApp.currentEvent.locationInWindow];
}

- (void)searchInBrowser:(id)sender {
    NSURL *url = [NSURL urlByReplacingFormatSpecifier:@"%@"
                                             inString:[iTermAdvancedSettingsModel searchCommand]
                                            withValue:[self.delegate contextMenuSelectedText:self capped:0]];
    [_urlActionHelper findUrlInString:url.absoluteString
                  andOpenInBackground:NO
                                style:iTermOpenStyleTab];
}

- (void)addTrigger:(id)sender {
    [self.delegate contextMenu:self addTrigger:[self.delegate contextMenuSelectedText:self capped:0]];
}

- (void)mail:(id)sender {
    NSString *mailto;

    NSString *selectedText = [self.delegate contextMenuSelectedText:self capped:0];
    if ([selectedText hasPrefix:@"mailto:"]) {
        mailto = [selectedText copy];
    } else {
        mailto = [NSString stringWithFormat:@"mailto:%@", selectedText];
    }

    NSURL *url = [NSURL URLWithUserSuppliedString:mailto];
    [self.delegate contextMenu:self openURL:url];
}

- (void)splitTextViewVertically:(id)sender {
    [self.delegate contextMenuSplitVertically:self];
}

- (void)splitTextViewHorizontally:(id)sender {
    [self.delegate contextMenuSplitHorizontally:self];
}

- (void)movePane:(id)sender {
    [self.delegate contextMenuMovePane:self];
}

- (void)copyLinkAddress:(id)sender {
    [self.delegate contextMenu:self copyURL:[sender representedObject]];
}

- (void)copyDetectedURL:(id)sender {
    NSURL *url = [NSURL castFrom:[sender representedObject]];
    if (!url) {
        return;
    }
    [self.delegate contextMenu:self copyURL:url];
}

- (void)copyString:(id)sender {
    NSMenuItem *item = sender;
    [self.delegate contextMenu:self copy:item.representedObject];
}

- (void)copyData:(id)sender {
    NSMenuItem *item = sender;
    [self.delegate contextMenu:self copy:item.representedObject];
}

- (void)replaceWithPrettyJSON:(id)sender {
    NSMenuItem *item = sender;
    [self.delegate contextMenu:self replaceSelectionWith:item.representedObject];
}

- (void)replaceWithBase64Decoded:(id)sender {
    NSMenuItem *item = sender;
    [self.delegate contextMenu:self replaceSelectionWith:item.representedObject];
}

- (void)replaceWithBase64Encoded:(id)sender {
    NSMenuItem *item = sender;
    [self.delegate contextMenu:self replaceSelectionWith:item.representedObject];
}

- (void)swapSessions:(id)sender {
    [self.delegate contextMenuSwapSessions:self];
}

- (void)sendSelection:(id)sender {
    iTermSelection *selection = [self.delegate contextMenuSelection:self];
    if (!selection.hasSelection) {
        return;
    }
    [self.delegate contextMenuSendSelectedText:self];
}

- (void)saveSelectionAsSnippet:(id)sender {
    iTermSelection *selection = [self.delegate contextMenuSelection:self];
    if (!selection.hasSelection) {
        return;
    }
    [self.delegate contextMenuSaveSelectionAsSnippet:self];
}

- (void)clearTextViewBuffer:(id)sender {
    [self.delegate contextMenuClearBuffer:self];
}

- (void)addNote:(id)sender {
    [self.delegate contextMenuAddAnnotation:self];
}

- (void)showNotes:(id)sender {
    [self.delegate contextMenuRevealAnnotations:self at:_validationClickPoint];
}

- (void)editTextViewSession:(id)sender {
    [self.delegate contextMenuEditSession:self];
}

- (void)toggleBroadcastingInput:(id)sender {
    [self.delegate contextMenuToggleBroadcastingInput:self];
}

- (void)toggleLock:(id)sender {
    [self.delegate contextMenuToggleLock:self];
}

- (void)lockAllInTab:(id)sender {
    [self.delegate contextMenuLockAllInTab:self];
}

- (void)unlockAllInTab:(id)sender {
    [self.delegate contextMenuUnlockAllInTab:self];
}

- (void)stopCoprocess:(id)sender {
    [self.delegate contextMenuStopCoprocess:self];
}

- (void)closeTextViewSession:(id)sender {
    [self.delegate contextMenuCloseSession:self];
}

- (void)restartSession:(id)sender {
    RLog(@"restartSession");
    [self.delegate contextMenuRestartSession:self];
}

- (void)bury:(id)sender {
    [self.delegate contextMenuBurySession:self];
}

- (void)reRunCommand:(id)sender {
    NSString *command = [sender representedObject];
    [self.delegate contextMenu:self insertText:[command stringByAppendingString:@"\n"]];
}

- (void)selectCommandOutput:(id)sender {
    id<VT100ScreenMarkReading> mark = [sender representedObject];
    [self selectOutputOfCommandMark:mark];
}

- (void)selectOutputOfCommandMark:(id<VT100ScreenMarkReading>)mark {
    VT100GridCoordRange range = [self.delegate contextMenu:self rangeOfOutputForCommandMark:mark];
    if (range.start.x == -1) {
        RLog(@"Beep: can't select output");
        NSBeep();
        return;
    }
    const long long overflow = [self.delegate contextMenuTotalScrollbackOverflow:self];
    VT100GridAbsCoordRange absRange = VT100GridAbsCoordRangeFromCoordRange(range, overflow);
    iTermSelection *selection = [self.delegate contextMenuSelection:self];
    // absRange is LOGICAL. Commit it as a logical selection rather than driving a
    // character-mode live selection, which with bidi on would treat it as visual
    // columns and mis-select on right-to-left output lines. Matches
    // -[PTYTextView selectLastCommandOutput].
    [selection setSelectedLogicalRange:VT100GridAbsWindowedRangeMake(absRange, 0, 0)
                                  mode:kiTermSelectionModeCharacter];

    if ([iTermPreferences boolForKey:kPreferenceKeySelectionCopiesText]) {
        [self.delegate contextMenuCopySelectionAccordingToUserPreferences:self];
    }
}

- (void)saveImageAs:(NSMenuItem *)item {
    [self.delegate contextMenu:self saveImage:item.representedObject];
}

- (void)copyImage:(NSMenuItem *)item {
    [self.delegate contextMenu:self copyImage:item.representedObject];
}

- (void)openImage:(NSMenuItem *)item {
    [self.delegate contextMenu:self openImage:item.representedObject];
}

- (void)inspectImage:(NSMenuItem *)item {
    [self.delegate contextMenu:self inspectImage:item.representedObject];
}

- (void)togglePauseAnimatingImage:(NSMenuItem *)item {
    [self.delegate contextMenu:self toggleAnimationOfImage:item.representedObject];
}

- (void)apiMenuItem:(NSMenuItem *)item {
    NSString *identifier = item.representedObject;
    NSArray<ITMRPCRegistrationRequest *> *reqs = [iTermAPIHelper contextMenuProviderRegistrationRequests];
    for (ITMRPCRegistrationRequest *req in reqs) {
        if (![req.contextMenuAttributes.uniqueIdentifier isEqualToString:identifier]) {
            continue;
        }
        NSString *invocation = [self invocationForAPIRegistrationRequest:req];
        [iTermScriptFunctionCall callFunction:invocation
                                      timeout:req.hasTimeout ? req.timeout : 30
                           sideEffectsAllowed:YES
                                        scope:[self.delegate contextMenuSessionScope:self]
                                   retainSelf:YES
                                   completion:^(id value, NSError *error, NSSet<NSString *> *missingFunctions) {
            if (error) {
                [self.delegate contextMenu:self invocation:invocation failedWithError:error forMenuItem:item.title];
            }
        }];
        return;
    }
}

#pragma mark - API

- (NSString *)invocationForAPIRegistrationRequest:(ITMRPCRegistrationRequest *)req {
    NSArray<ITMRPCRegistrationRequest_RPCArgument *> *defaults = req.defaultsArray ?: @[];
    return [iTermAPIHelper invocationWithFullyQualifiedName:req.it_fullyQualifiedName
                                                   defaults:defaults];
}

#pragma mark - Title Bar Menu

- (NSMenu *)titleBarMenu {
    _validationClickPoint = VT100GridCoordMake(-1, -1);
    NSMenu *menu = [self menuAtCoord:VT100GridCoordMake(-1, -1)];
    [self applyWindowAppearanceToMenu:menu];
    return menu;
}

#pragma mark - NSMenuDelegate

- (void)menuDidClose:(NSMenu *)menu {
    _savedSelectedText = nil;
}

@end
