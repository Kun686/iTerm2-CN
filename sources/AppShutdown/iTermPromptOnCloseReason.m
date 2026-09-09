//
//  iTermPromptOnCloseReason.m
//  iTerm2
//
//  Created by George Nachman on 11/29/16.
//
//

#import "iTermPromptOnCloseReason.h"
#import "ITAddressBookMgr.h"
#import "NSArray+iTerm.h"

@interface iTermPromptOnCloseReason()
@property (nonatomic, readonly) NSNumber *priority;
+ (NSString *)groupFooter;
@end

@interface iTermPromptOnCloseCompoundReason : iTermPromptOnCloseReason
@end

@implementation iTermPromptOnCloseCompoundReason {
    NSMutableArray<iTermPromptOnCloseReason *> *_children;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _children = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_children release];
    [super dealloc];
}

- (BOOL)hasReason {
    return _children.count > 0;
}

- (NSString *)message {
    NSArray<iTermPromptOnCloseReason *> *sortedReasons = [_children sortedArrayUsingComparator:^NSComparisonResult(iTermPromptOnCloseReason *_Nonnull obj1,
                                                                                                                   iTermPromptOnCloseReason *_Nonnull obj2) {
        return [obj1.priority compare:obj2.priority];
    }];

    __block NSString *previousMessage = nil;
    NSArray *uniqueReasons = [sortedReasons filteredArrayUsingBlock:^BOOL(iTermPromptOnCloseReason *reason) {
        BOOL ok = ![reason.message isEqualToString:previousMessage];
        previousMessage = reason.message;
        return ok;
    }];

    __block Class previousClass = [uniqueReasons.firstObject class];
    NSArray *prettyReasons = [uniqueReasons flatMapWithBlock:^id(iTermPromptOnCloseReason *reason) {
        NSString *formattedMessage = [@"• " stringByAppendingString:reason.message];
        NSString *groupFooter = [previousClass groupFooter];
        NSArray *result;
        if (reason.class != previousClass && groupFooter) {
            result = @[ groupFooter, @"", formattedMessage ];
        } else {
            result = @[ formattedMessage ];
        }
        previousClass = [reason class];
        return result;
    }];
    if ([previousClass groupFooter]) {
        prettyReasons = [prettyReasons arrayByAddingObject:[previousClass groupFooter]];
    }

    return [prettyReasons componentsJoinedByString:@"\n"];
}

- (void)addReason:(iTermPromptOnCloseReason *)reason {
    if ([reason isKindOfClass:[iTermPromptOnCloseCompoundReason class]]) {
        iTermPromptOnCloseCompoundReason *compound = (iTermPromptOnCloseCompoundReason *)reason;
        for (iTermPromptOnCloseReason *child in compound->_children) {
            [self addReason:child];
        }
    } else {
        [_children addObject:reason];
    }
}

- (NSNumber *)priority {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

@end

@interface iTermPromptOnCloseAlwaysReason : iTermPromptOnCloseReason
@end

@implementation iTermPromptOnCloseAlwaysReason {
    NSString *_name;
}

- (instancetype)initWithProfileName:(NSString *)name {
    self = [super init];
    if (self) {
        _name = [name copy];
    }
    return self;
}

- (void)dealloc {
    [_name release];
    [super dealloc];
}

- (NSString *)message {
    return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.appshutdown.itermpromptonclosereason.the_profile_always_requires_confirmation.23e23396", nil, NSBundle.mainBundle, @"The profile “%@” always requires confirmation.", @"Reason shown in a close confirmation sheet."), _name];
}

+ (NSString *)groupFooter {
    return NSLocalizedStringWithDefaultValue(@"ui.appshutdown.itermpromptonclosereason.you_can_change_this_setting_in_settings_profiles_session.c4ba8711", nil, NSBundle.mainBundle, @"You can change this setting in Settings > Profiles > Session", @"Footer shown below profile-related close confirmation reasons.");
}

- (NSNumber *)priority {
    return @50;
}

@end

@interface iTermPromptOnCloseBlockedReason : iTermPromptOnCloseReason
@end

@implementation iTermPromptOnCloseBlockedReason {
    NSString *_name;
    NSArray<NSString *> *_jobs;
}

- (instancetype)initWithName:(NSString *)name jobs:(NSArray<NSString *> *)jobs {
    self = [super init];
    if (self) {
        _name = [name copy];
        _jobs = [jobs copy];
    }
    return self;
}

- (void)dealloc {
    [_name release];
    [_jobs release];
    [super dealloc];
}

- (NSString *)message {
    const NSInteger maxJobsToList = 3;
    if (_jobs.count <= maxJobsToList) {
        return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.appshutdown.itermpromptonclosereason.a_session_with_profile_is_running.d0546a43", nil, NSBundle.mainBundle, @"A session with profile “%@” is running %@.", @"Reason shown when a session has running jobs."),
                _name,
                [_jobs componentsJoinedWithOxfordCommaAndConjunction:
                    NSLocalizedStringWithDefaultValue(@"ui.terminalview.pseudoterminal.close_job_conjunction", nil, NSBundle.mainBundle, @"and", @"Conjunction between job names in a close confirmation.")]];
    } else {
        return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.appshutdown.itermpromptonclosereason.a_session_with_profile_is_running_and_other.d56440b9", nil, NSBundle.mainBundle, @"A session with profile “%@” is running %@, and %@ other %@.", @"Reason shown when a session has more running jobs than can be listed."),
                _name,
                [[_jobs subarrayWithRange:NSMakeRange(0, maxJobsToList)] componentsJoinedByString:@", "],
                @(_jobs.count - maxJobsToList),
                _jobs.count == (maxJobsToList + 1) ? NSLocalizedStringWithDefaultValue(@"ui.appshutdown.itermpromptonclosereason.job.5e8c9902", nil, NSBundle.mainBundle, @"job", @"Singular job noun in a close confirmation reason.") : NSLocalizedStringWithDefaultValue(@"ui.appshutdown.itermpromptonclosereason.jobs.5d9a17cb", nil, NSBundle.mainBundle, @"jobs", @"Plural job noun in a close confirmation reason.")];
    }
}

+ (NSString *)groupFooter {
    return NSLocalizedStringWithDefaultValue(@"ui.appshutdown.itermpromptonclosereason.you_can_change_this_setting_in_settings_profiles_session.c4ba8711", nil, NSBundle.mainBundle, @"You can change this setting in Settings > Profiles > Session", @"Footer shown below profile-related close confirmation reasons.");
}

- (NSNumber *)priority {
    return @25;
}

@end

@interface iTermPromptOnCloseMessageReason : iTermPromptOnCloseReason
@end

@implementation iTermPromptOnCloseMessageReason {
    NSString *_message;
    double _priority;
}

- (instancetype)initWithMessage:(NSString *)message priority:(double)priority {
    self = [super init];
    if (self) {
        _message = [message copy];
        _priority = priority;
    }
    return self;
}

- (void)dealloc {
    [_message release];
    [super dealloc];
}

- (NSString *)message {
    return _message;
}

- (NSNumber *)priority {
    return @(_priority);
}

@end

@implementation iTermPromptOnCloseReason

+ (instancetype)noReason {
    return [[[iTermPromptOnCloseCompoundReason alloc] init] autorelease];
}

+ (instancetype)profileAlwaysPrompts:(Profile *)profile {
    return [[[iTermPromptOnCloseAlwaysReason alloc] initWithProfileName:profile[KEY_NAME]] autorelease];
}

+ (instancetype)profile:(Profile *)profile blockedByJobs:(NSArray<NSString *> *)jobs {
    return [[[iTermPromptOnCloseBlockedReason alloc] initWithName:profile[KEY_NAME] jobs:jobs] autorelease];
}

+ (instancetype)alwaysConfirmQuitPreferenceEnabled {
    return [[[iTermPromptOnCloseMessageReason alloc] initWithMessage:NSLocalizedStringWithDefaultValue(@"ui.appshutdown.itermpromptonclosereason.settings_general_closing_confirm_quit_iterm2_is_enabled_and_there_is_at_least_one_terminal_window.2a44ccc6", nil, NSBundle.mainBundle, @"“Settings > General > Closing > Confirm Quit iTerm2” is enabled and there is at least one terminal window.", @"Reason shown in a quit confirmation sheet.") priority:100] autorelease];
}

+ (instancetype)alwaysConfirmQuitPreferenceEvenIfThereAreNoWindowsEnabled {
    return [[[iTermPromptOnCloseMessageReason alloc] initWithMessage:NSLocalizedStringWithDefaultValue(@"ui.appshutdown.itermpromptonclosereason.settings_general_closing_confirm_quit_iterm2_and_even_if_there_are_no_windows_is_enabled.893cb090", nil, NSBundle.mainBundle, @"“Settings > General > Closing > Confirm Quit iTerm2” and “Even if there are no windows” is enabled.", @"Reason shown in a quit confirmation sheet.") priority:100] autorelease];
}

+ (instancetype)closingMultipleSessionsPreferenceEnabled {
    return [[[iTermPromptOnCloseMessageReason alloc] initWithMessage:NSLocalizedStringWithDefaultValue(@"ui.appshutdown.itermpromptonclosereason.settings_general_closing_confirm_closing_multiple_sessions_is_enabled.6c6f8f1f", nil, NSBundle.mainBundle, @"“Settings > General > Closing > Confirm closing multiple sessions” is enabled.", @"Reason shown in a close confirmation sheet.") priority:90] autorelease];
}

+ (instancetype)tmuxClientsAlwaysPromptBecauseJobsAreNotExposed {
    return [[[iTermPromptOnCloseMessageReason alloc] initWithMessage:NSLocalizedStringWithDefaultValue(@"ui.appshutdown.itermpromptonclosereason.a_tmux_session_is_configured_to_prompt_if_jobs_are_running_but_tmux_doesn_t_expose_the_process_tree.a90ea250", nil, NSBundle.mainBundle, @"A tmux session is configured to prompt if jobs are running, but tmux doesn’t expose the process tree.", @"Reason shown in a close confirmation sheet for tmux sessions.") priority:80] autorelease];
}

+ (instancetype)sessionIsLocked {
    return [[[iTermPromptOnCloseMessageReason alloc] initWithMessage:NSLocalizedStringWithDefaultValue(@"ui.appshutdown.itermpromptonclosereason.this_pane_is_locked.36a8aaac", nil, NSBundle.mainBundle, @"This pane is locked.", @"Reason shown in a close confirmation sheet.") priority:75] autorelease];
}

+ (instancetype)tabIsPinnedWithNumber:(int)tabNumber {
    NSString *const message = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.appshutdown.itermpromptonclosereason.tab_d_is_pinned.2f845fc7", nil, NSBundle.mainBundle, @"Tab #%d is pinned.", @"Reason shown in a close confirmation sheet for a pinned tab."), tabNumber];
    return [[[iTermPromptOnCloseMessageReason alloc] initWithMessage:message priority:70] autorelease];
}

- (BOOL)hasReason {
    return YES;
}

+ (NSString *)groupFooter {
    return nil;
}


- (NSString *)message {
    [self doesNotRecognizeSelector:_cmd];
    return @"";
}

- (void)addReason:(iTermPromptOnCloseReason *)reason {
    [self doesNotRecognizeSelector:_cmd];
}

@end
