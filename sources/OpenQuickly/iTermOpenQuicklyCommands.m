//
//  iTermOpenQuicklyCommands.m
//  iTerm2
//
//  Created by George Nachman on 3/7/16.
//
//

#import "iTermOpenQuicklyCommands.h"

@implementation iTermOpenQuicklyCommand

@synthesize text = _text;

- (void)dealloc {
    [_text release];
    [super dealloc];
}
+ (NSString *)tipTitle {
    return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.openquickly.itermopenquicklycommands.tip_start_your_query_with.7cccedde", nil, NSBundle.mainBundle, @"Tip: Start your query with “/%@”", @"Open Quickly command tip title. The slash and command token must remain unchanged."), [self command]];
}

+ (NSString *)tipDetail {
    return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.openquickly.itermopenquicklycommands.restricts_results_to.8bbb3aae", nil, NSBundle.mainBundle, @"Restricts results to %@", @"Open Quickly command tip detail."), [self restrictionDescription]];
}

+ (NSString *)command {
    return nil;
}

+ (NSString *)restrictionDescription {
    return nil;
}

- (BOOL)supportsSessionLocation {
    return NO;
}

- (BOOL)supportsWindowLocation {
    return NO;
}

- (BOOL)supportsCreateNewTab {
    return NO;
}

- (BOOL)supportsChangeProfile {
    return NO;
}

- (BOOL)supportsOpenArrangement:(out BOOL *)tabsOnlyPtr {
    return NO;
}

- (BOOL)supportsScript {
    return NO;
}

- (BOOL)supportsColorPreset {
    return NO;
}

- (BOOL)supportsAction {
    return NO;
}

- (BOOL)supportsSnippet {
    return NO;
}

- (BOOL)supportsNamedMarks {
    return NO;
}

- (BOOL)supportsMenuItems {
    return NO;
}

- (BOOL)supportsBookmarks {
    return NO;
}

- (BOOL)supportsURLs {
    return NO;
}

@end

@implementation iTermOpenQuicklyInTabsWindowArrangementCommand

+ (NSString *)restrictionDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.openquickly.itermopenquicklycommands.window_arrangements_that_open_in_tabs.321efdd2", nil, NSBundle.mainBundle, @"window arrangements that open in tabs", @"Open Quickly restriction description.");
}

+ (NSString *)command {
    return @"A";
}

- (BOOL)supportsOpenArrangement:(out BOOL *)tabsOnlyPtr {
    *tabsOnlyPtr = YES;
    return YES;
}

@end

@implementation iTermOpenQuicklyWindowArrangementCommand

+ (NSString *)restrictionDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.openquickly.itermopenquicklycommands.window_arrangements.29ede2ec", nil, NSBundle.mainBundle, @"window arrangements", @"Open Quickly restriction description.");
}

+ (NSString *)command {
    return @"a";
}

- (BOOL)supportsOpenArrangement:(out BOOL *)tabsOnlyPtr {
    *tabsOnlyPtr = NO;
    return YES;
}

@end

@implementation iTermOpenQuicklySearchSessionsCommand

+ (NSString *)restrictionDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.openquickly.itermopenquicklycommands.existing_sessions.28c6d242", nil, NSBundle.mainBundle, @"existing sessions", @"Open Quickly restriction description.");
}

+ (NSString *)command {
    return @"f";
}

- (BOOL)supportsSessionLocation {
    return YES;
}

@end

@implementation iTermOpenQuicklySearchWindowsCommand

+ (NSString *)restrictionDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.openquickly.itermopenquicklycommands.existing_windows.95c3416b", nil, NSBundle.mainBundle, @"existing windows", @"Open Quickly restriction description.");
}

+ (NSString *)command {
    return @"w";
}

- (BOOL)supportsWindowLocation {
    return YES;
}

@end

@implementation iTermOpenQuicklySwitchProfileCommand

+ (NSString *)restrictionDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.openquickly.itermopenquicklycommands.switch_profiles.8be411d0", nil, NSBundle.mainBundle, @"switch profiles", @"Open Quickly restriction description.");
}

+ (NSString *)command {
    return @"p";
}

- (BOOL)supportsChangeProfile {
    return YES;
}

@end

@implementation iTermOpenQuicklyCreateTabCommand

+ (NSString *)restrictionDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.openquickly.itermopenquicklycommands.create_tab.3dd053dc", nil, NSBundle.mainBundle, @"create tab", @"Open Quickly restriction description.");
}

+ (NSString *)command {
    return @"t";
}

- (BOOL)supportsCreateNewTab {
    return YES;
}

@end

@implementation iTermOpenQuicklyScriptCommand

+ (NSString *)restrictionDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.openquickly.itermopenquicklycommands.run_script.f068017a", nil, NSBundle.mainBundle, @"run script", @"Open Quickly restriction description.");
}

+ (NSString *)command {
    return @"s";
}

- (BOOL)supportsScript {
    return YES;
}

@end

@implementation iTermOpenQuicklyColorPresetCommand

+ (NSString *)restrictionDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.openquickly.itermopenquicklycommands.load_color_preset.685ae6af", nil, NSBundle.mainBundle, @"load color preset", @"Open Quickly restriction description.");
}

+ (NSString *)command {
    return @"c";
}

- (BOOL)supportsColorPreset {
    return YES;
}

@end

@implementation iTermOpenQuicklyNoCommand

- (BOOL)supportsSessionLocation {
    return YES;
}

- (BOOL)supportsCreateNewTab {
    return YES;
}

- (BOOL)supportsChangeProfile {
    return YES;
}

- (BOOL)supportsOpenArrangement:(out BOOL *)tabsOnlyPtr {
    *tabsOnlyPtr = NO;
    return YES;
}

- (BOOL)supportsScript {
    return YES;
}

- (BOOL)supportsColorPreset {
    return YES;
}

- (BOOL)supportsAction {
    return YES;
}

- (BOOL)supportsSnippet {
    return YES;
}

- (BOOL)supportsWindowLocation {
    return YES;
}

- (BOOL)supportsNamedMarks {
    return YES;
}

- (BOOL)supportsMenuItems {
    return YES;
}

- (BOOL)supportsBookmarks {
    return YES;
}

- (BOOL)supportsURLs {
    return YES;
}

@end

@implementation iTermOpenQuicklyActionCommand

+ (NSString *)restrictionDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.openquickly.itermopenquicklycommands.perform_action.c7dc2a48", nil, NSBundle.mainBundle, @"perform action", @"Open Quickly restriction description.");
}

+ (NSString *)command {
    return @":";
}

- (BOOL)supportsAction {
    return YES;
}

@end

@implementation iTermOpenQuicklySnippetCommand

+ (NSString *)restrictionDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.openquickly.itermopenquicklycommands.send_snippet.77a063a0", nil, NSBundle.mainBundle, @"send snippet", @"Open Quickly restriction description.");
}

+ (NSString *)command {
    return @".";
}

- (BOOL)supportsSnippet {
    return YES;
}

@end

@implementation iTermOpenQuicklyBookmarkCommand

+ (NSString *)restrictionDescription {
    return NSLocalizedStringWithDefaultValue(@"ui.openquickly.itermopenquicklycommands.open_bookmark.92204f92", nil, NSBundle.mainBundle, @"open bookmark", @"Open Quickly restriction description.");
}

+ (NSString *)command {
    return @"b";
}

- (BOOL)supportsBookmarks {
    return YES;
}

@end
