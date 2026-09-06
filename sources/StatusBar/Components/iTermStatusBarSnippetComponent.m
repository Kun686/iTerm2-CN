//
//  iTermStatusBarSnippetComponent.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 9/9/20.
//

#import "iTermStatusBarSnippetComponent.h"
#import "iTermSnippetsMenuController.h"
#import "iTermSnippetsModel.h"
#import "iTermScriptHistory.h"
#import "iTermSwiftyString.h"
#import "NSArray+iTerm.h"
#import "NSDictionary+iTerm.h"
#import "NSImage+iTerm.h"
#import "RegexKitLite.h"

@implementation iTermStatusBarSnippetMenuComponent

- (nullable NSImage *)statusBarComponentIcon {
    return [NSImage it_cacheableImageNamed:@"StatusBarIconSnippet" forClass:[self class]];
}

- (NSString *)statusBarComponentShortDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarsnippetcomponent.snippets_menu.58565b69", nil, NSBundle.mainBundle, @"Snippets Menu", @"Status bar component name.");
}

- (NSString *)statusBarComponentDetailedDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarsnippetcomponent.when_clicked_opens_a_menu_of_snippets_snippets_are_saved_text_strings_that_can_be_pasted_quickly.33960824", nil, NSBundle.mainBundle, @"When clicked, opens a menu of snippets. Snippets are saved text strings that can be pasted quickly.", @"Status bar component description.");
}

- (id)statusBarComponentExemplarWithBackgroundColor:(NSColor *)backgroundColor
                                          textColor:(NSColor *)textColor {
    return NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarsnippetcomponent.snippet.d5c0d6cd", nil, NSBundle.mainBundle, @"Snippet…", @"Status bar component preview.");
}

- (BOOL)statusBarComponentCanStretch {
    return YES;
}

- (nullable NSString *)stringValue {
    return NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarsnippetcomponent.send_snippet.fec5a180", nil, NSBundle.mainBundle, @"Send Snippet…", @"Status bar component label.");
}

- (nullable NSString *)stringValueForCurrentWidth {
    return self.stringValue;
}

- (nullable NSArray<NSString *> *)stringVariants {
    return @[ self.stringValue ];
}

- (NSString *)statusBarComponentCopyableString {
    return nil;
}

- (BOOL)statusBarComponentHandlesClicks {
    return YES;
}

- (BOOL)statusBarComponentIsEmpty {
    return [[[iTermSnippetsModel sharedInstance] snippets] count] == 0;
}

- (void)statusBarComponentDidClickWithView:(NSView *)view {
    [self openMenuWithView:view];
}

- (void)statusBarComponentMouseDownWithView:(NSView *)view {
    [self openMenuWithView:view];
}

- (BOOL)statusBarComponentHandlesMouseDown {
    return YES;
}

- (void)openMenuWithView:(NSView *)view {
    NSView *containingView = view.superview;

    NSMenu *menu = [[NSMenu alloc] init];
    iTermSnippetsMenuController *menuController = [[iTermSnippetsMenuController alloc] init];
    menuController.menu = menu;

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.statusbar.components.itermstatusbarsnippetcomponent.edit_snippets.dec476c7", nil, NSBundle.mainBundle, @"Edit Snippets…", @"User-facing text in iTermStatusBarSnippetComponent (openMenuWithView:).") action:@selector(editSnippets:) keyEquivalent:@""];
    item.target = self;
    [menu addItem:item];

    [menu popUpMenuPositioningItem:menu.itemArray.firstObject atLocation:NSMakePoint(0, 0) inView:containingView];
}

- (void)editSnippets:(id)sender {
    [self.delegate statusBarComponentEditSnippets:self];
}

@end
