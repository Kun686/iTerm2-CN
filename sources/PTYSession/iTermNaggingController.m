//
//  iTermNaggingController.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 12/11/19.
//

#import "iTermNaggingController.h"

#import "DebugLogging.h"
#import "NSArray+iTerm.h"
#import "NSStringITerm.h"
#import "NSWorkspace+iTerm.h"
#import "ProfileModel.h"
#import "iTerm2SharedARC-Swift.h"
#import "iTermAdvancedSettingsModel.h"
#import "iTermPreferences.h"
#import "iTermUserDefaults.h"

static NSString *const iTermNaggingControllerOrphanIdentifier = @"DidRestoreOrphan";
static NSString *const iTermNaggingControllerReopenSessionAfterBrokenPipeIdentifier = @"ReopenSessionAfterBrokenPipe";
static NSString *const iTermNaggingControllerAbortDownloadIdentifier = @"AbortDownloadOnKeyPressAnnouncement";
static NSString *const iTermNaggingControllerAbortUploadOnKeyPressAnnouncementIdentifier = @"AbortUploadOnKeyPressAnnouncement";
static NSString *const iTermNaggingControllerArrangementProfileMissingIdentifier = @"ThisProfileNoLongerExists";
static NSString *const iTermNaggingControllerTmuxSupplementaryPlaneErrorIdentifier = @"Tmux2.2SupplementaryPlaneAnnouncement";
static NSString *const iTermNaggingControllerAskAboutAlternateMouseScrollIdentifier = @"AskAboutAlternateMouseScroll";
static NSString *const iTermNaggingControllerAskAboutMouseReportingFrustrationIdentifier = @"AskAboutMouseReportingFrustration";
NSString *const kTurnOffBracketedPasteOnHostChangeAnnouncementIdentifier = @"TurnOffBracketedPasteOnHostChange";
static NSString *const kResetKeyReportingModeAnnouncementIdentifier = @"ResetKeyReportingMode";
NSString *const kRestoreIconAndWindowNameOnHostChangeAnnouncementIdentifier = @"RestoreIconAndWindowName";
static NSString *const iTermNaggingControllerAskAboutClearingScrollbackHistoryIdentifier = @"ClearScrollbackHistory";
static NSString *const iTermNaggingControllerWarnAboutSecureKeyboardInputWithOpenCommand = @"WarnAboutSecureKeyboardInputWithOpenCommand";
NSString *const kTurnOffBracketedPasteOnHostChangeUserDefaultsKey = @"NoSyncTurnOffBracketedPasteOnHostChange";
static NSString *const kResetKeyReportingModeUserDefaultsKey = @"NoSyncResetKeyReportingModeOnPrompt";
NSString *const kRestoreIconAndWindowNameOnHostChangeUserDefaultsKey = @"NoSyncRestoreIconAndWindowNameOnHostChange";
static NSString *const iTermNaggingControllerAskAboutChangingProfileIdentifier = @"AskAboutChangingProfile";
static NSString *const iTermNaggingControllerTmuxWindowsShouldCloseAfterDetach = @"TmuxWindowsShouldCloseAfterDetach";
static NSString *const kTurnOffSlowTriggersOfferUserDefaultsKey = @"kTurnOffSlowTriggersOfferUserDefaultsKey";
static NSString *const iTermNaggingControllerOfferToSyncTmuxClipboard = @"NoSyncOfferToSyncTmuxClipboard";

static NSString *const iTermNaggingControllerUserDefaultNeverAskAboutSettingAlternateMouseScroll = @"NoSyncNeverAskAboutSettingAlternateMouseScroll";

static NSString *iTermNaggingControllerSetBackgroundImageFileIdentifier = @"SetBackgroundImageFile";
static NSString *iTermNaggingControllerUserDefaultAlwaysAllowBackgroundImage = @"AlwaysAllowBackgroundImage";
static NSString *iTermNaggingControllerUserDefaultAlwaysDenyBackgroundImage = @"AlwaysDenyBackgroundImage";
static NSString *const iTermNaggingControllerDidChangeTmuxWindowsShouldCloseAfterDetach = @"iTermNaggingControllerDidChangeTmuxWindowsShouldCloseAfterDetach";
static NSString *const iTermNaggingControllerArrangementTextReplacements = @"TextReplacements";
static NSString *const iTermNaggingControllerArrangementSetProfileProperty = @"SetProfileProperty";
static NSString *const iTermNaggingControllerClaudeCodeStatusToolIdentifier = @"ClaudeCodeStatusTool";
static NSString *const iTermNaggingControllerClaudeCodeStatusToolDismissedNotification = @"iTermNaggingControllerClaudeCodeStatusToolDismissed";
static NSString *const iTermNaggingControllerRestoreIconAndWindowNameChoiceNotification = @"iTermNaggingControllerRestoreIconAndWindowNameChoice";
static NSString *const iTermNaggingControllerRestoreIconAndWindowNameChoiceAlwaysKey = @"always";

@implementation iTermNaggingController {
    BOOL _haveOutstandingTextReplacementOffer;
    NSString *_pendingRestoreIconName;
    NSString *_pendingRestoreWindowName;
    BOOL _hasPendingRestoreOffer;
    // Tracks whether the user has already dismissed or acted on the Touch ID for
    // sudo offer for the current sudo invocation. Cleared when sudo is no longer
    // the foreground job.
    BOOL _touchIDForSudoDismissed;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didChangeTmuxWindowsShouldCloseAfterDetach:)
                                                     name:iTermNaggingControllerDidChangeTmuxWindowsShouldCloseAfterDetach
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(claudeCodeStatusToolDismissed:)
                                                     name:iTermNaggingControllerClaudeCodeStatusToolDismissedNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(restoreIconAndWindowNameChoiceMade:)
                                                     name:iTermNaggingControllerRestoreIconAndWindowNameChoiceNotification
                                                   object:nil];
    }
    return self;
}

- (BOOL)permissionToReportVariableNamed:(NSString *)name {
    static NSString *const allow = @"allow:";
    static NSString *const deny = @"deny:";

    NSNumber *originalValue = nil;
    {
        NSArray<NSString *> *parts = [self variablesToReportEntries];
        if ([parts containsObject:[allow stringByAppendingString:name]]) {
            originalValue = @YES;
        }
        if ([parts containsObject:[deny stringByAppendingString:name]]) {
            originalValue = @NO;
        }
    }

    return [self requestPermissionWithOriginalValue:originalValue
                                                key:[NSString stringWithFormat:@"ShouldReportVariable%@", name]
                                   prompt:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.a_request_to_report_variable_was_denied_allow.738a2a13", nil, NSBundle.mainBundle, @"A request to report variable “%@” was denied. Allow it in the future?", @"User-facing announcement format string."), name]
                                   setter:^(BOOL shouldAllow) {
        NSArray<NSString *> *parts = [self variablesToReportEntries];
        NSString *prefix = shouldAllow ? allow : deny;
        NSString *newEntry = [prefix stringByAppendingString:name];
        parts = [parts arrayByAddingObject:newEntry];
        [iTermAdvancedSettingsModel setNoSyncVariablesToReport:[parts componentsJoinedByString:@","]];
    }];
}

- (void)offerToFixSessionWithBrokenArrangementProfileIn:(NSString *)arrangementName
                                                   guid:(NSString *)guid {
    NSString *notice = NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.this_arrangement_s_profile_is_missing_this_could.5b50b96d", nil, NSBundle.mainBundle, @"This arrangement’s profile is missing. This could be due to a bug in iTerm2 version 3.5.7, which caused profiles to be corrupted in saved arrangements.", @"User-facing announcement message.");
    [self.delegate naggingControllerShowMessage:notice
                                     isQuestion:NO
                                      important:YES
                                     identifier:@"ArrangementMissingProfile"
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.assign_profile.1df4924e", nil, NSBundle.mainBundle, @"Assign Profile", @"User-facing action label in iTermNaggingController (options).") ]
                                     completion:^(int selection) {
        if (selection == 0) {
            [self.delegate naggingControllerAssignProfileToSession:arrangementName
                                                              guid:guid];
        }
    }];
}

- (NSString *)userDefaultsKeyForProfileProperty:(NSString *)key {
    return [@"NoSyncSetProfileProperty_" stringByAppendingString:key];
}

- (void)offerToSetProfileProperties:(NSDictionary<NSString *, id> *)dict {
    DLog(@"%@", dict);
    NSDictionary *permissions = [dict mapValuesWithBlock:^id(NSString *key, id object) {
        return [[iTermUserDefaults userDefaults] objectForKey:[self userDefaultsKeyForProfileProperty:key]];
    }];
    DLog(@"permissions: %@", permissions);
    // true = deny, false = always allow
    if ([permissions.allValues containsObject:@(iTermTriStateTrue)]) {
        DLog(@"Disallowed by setting");
        return;
    }
    if (permissions.count == dict.count && [permissions.allValues allWithBlock:^BOOL(id anObject) {
        return [anObject isEqual:@(iTermTriStateFalse)];
    }]) {
        [self.delegate naggingControllerSetProfileProperties:dict];
        return;
    }
    NSString *notice;
    if (dict.count == 1) {
        NSString *key = dict.allKeys.firstObject;
        notice = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.an_app_tried_to_change_the_profile_property.93ec8378", nil, NSBundle.mainBundle, @"An app tried to change the profile property **%@**", @"User-facing Markdown announcement format string."), [iTermProfilePreferences descriptionForKey:key]];
    } else {
        NSMutableArray<NSString *> *descriptions = [NSMutableArray array];
        for (NSString *key in dict.allKeys) {
            NSString *desc = [iTermProfilePreferences descriptionForKey:key] ?: key;
            [descriptions addObject:[NSString stringWithFormat:@"* %@", desc]];
        }
        NSString *bulletList = [descriptions componentsJoinedByString:@"\n"];
        NSString *popoverMessage = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.properties_to_be_changed.f8a4b1f1", nil, NSBundle.mainBundle, @"**Properties to be changed:**\n\n%@", @"User-facing Markdown popover format string."), bulletList];
        NSString *encodedMessage = [popoverMessage stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *popoverURL = [NSString stringWithFormat:@"x-iterm2-popover:?message=%@", encodedMessage];
        notice = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.an_app_tried_to_change_multiple_profile_properties.6eaede18", nil, NSBundle.mainBundle, @"An app tried to change [multiple profile properties](%@).", @"User-facing Markdown announcement format string."), popoverURL];
    }
    __weak __typeof(self) weakSelf = self;
    [self.delegate naggingControllerShowMarkdownMessage:notice
                                             isQuestion:YES
                                              important:NO
                                             identifier:iTermNaggingControllerArrangementSetProfileProperty
                                                options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.allow_once.db188ae1", nil, NSBundle.mainBundle, @"_Allow Once", @"Announcement action; underscore marks the Option-key shortcut."),
                                                           NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.allow_always.4d419bb3", nil, NSBundle.mainBundle, @"Allow Always", @"Announcement action."),
                                                           NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.deny_always.12b1559a", nil, NSBundle.mainBundle, @"Deny Always", @"Announcement action.") ]
                                             completion:^(int selection) {
        if (selection == 0 || selection == 1) {
            [weakSelf.delegate naggingControllerSetProfileProperties:dict];
        }
        __strong __typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (selection == 1) {
            for (NSString *key in dict) {
                [[iTermUserDefaults userDefaults] setObject:@(iTermTriStateFalse)
                                                          forKey:[strongSelf userDefaultsKeyForProfileProperty:key]];
            }
        } else if (selection == 2) {
            for (NSString *key in dict) {
                [[iTermUserDefaults userDefaults] setObject:@(iTermTriStateTrue)
                                                          forKey:[strongSelf userDefaultsKeyForProfileProperty:key]];
            }
        }
    }];
}

- (void)offerTextReplacement:(void (^NS_NOESCAPE)(void))perform {
    NSString *userDefaultsKey = @"NoSyncTextReplacements";
    NSNumber *n = [NSNumber castFrom:[[iTermUserDefaults userDefaults] objectForKey:userDefaultsKey]];
    if (n) {
        if (n.boolValue) {
            perform();
        }
        return;
    }
    if (_haveOutstandingTextReplacementOffer) {
        return;
    }
    NSString *notice = NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.would_you_like_macos_text_replacements_to_be.9fb1b642", nil, NSBundle.mainBundle, @"Would you like macOS Text Replacements to be applied automatically?", @"User-facing announcement message.");
    _haveOutstandingTextReplacementOffer = YES;
    __weak __typeof(self) weakSelf = self;
    [self.delegate naggingControllerShowMessage:notice
                                     isQuestion:YES
                                      important:NO
                                     identifier:iTermNaggingControllerArrangementTextReplacements
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.yes.b481b415", nil, NSBundle.mainBundle, @"_Yes", @"Announcement action; underscore marks the Option-key shortcut."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.no.bae768bf", nil, NSBundle.mainBundle, @"_No", @"Announcement action; underscore marks the Option-key shortcut.") ]
                                     completion:^(int selection) {
        if (selection == 0 || selection == 1) {
            [[iTermUserDefaults userDefaults] setBool:selection == 0 forKey:userDefaultsKey];
        }
        [weakSelf resetHaveTextReplacementOffer];
    }];
}

- (void)cancelTextReplacementOffer {
    if (_haveOutstandingTextReplacementOffer) {
        [self.delegate naggingControllerRemoveMessageWithIdentifier:iTermNaggingControllerArrangementTextReplacements];
        _haveOutstandingTextReplacementOffer = NO;
    }
}

- (void)resetHaveTextReplacementOffer {
    _haveOutstandingTextReplacementOffer = NO;
}

- (void)arrangementWithName:(NSString *)savedArrangementName
        missingProfileNamed:(NSString *)missingProfileName
                       guid:(NSString *)guid {
    RLog(@"Can’t find profile %@ guid %@", missingProfileName, guid);
    if ([iTermAdvancedSettingsModel noSyncSuppressMissingProfileInArrangementWarning]) {
        return;
    }
    NSString *notice;
    NSArray<NSString *> *actions = @[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.don_t_warn_again.4e0cbb59", nil, NSBundle.mainBundle, @"Don’t Warn Again", @"User-facing action label in iTermNaggingController (actions).") ];
    if ([[ProfileModel sharedInstance] bookmarkWithName:missingProfileName]) {
        notice = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.this_session_s_profile_no_longer_exists_a.30c330c8", nil, NSBundle.mainBundle, @"This session’s profile, “%@”, no longer exists. A profile with that name happens to exist.", @"User-facing announcement format string."), missingProfileName];
        if (savedArrangementName) {
            actions = [actions arrayByAddingObject:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.repair_saved_arrangement.16c6eb10", nil, NSBundle.mainBundle, @"Repair Saved Arrangement", @"Announcement action.")];
        }
    } else {
        notice = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.this_session_s_profile_no_longer_exists.1919b34c", nil, NSBundle.mainBundle, @"This session’s profile, “%@”, no longer exists.", @"User-facing announcement format string."), missingProfileName];
    }
    _missingSavedArrangementProfileGUID = [guid copy];
    [self.delegate naggingControllerShowMessage:notice
                                     isQuestion:NO
                                      important:NO
                                     identifier:iTermNaggingControllerArrangementProfileMissingIdentifier
                                        options:actions
                                     completion:^(int selection) {
        [self handleCompletionForMissingProfileInArrangementWithName:savedArrangementName
                                                 missingProfileNamed:missingProfileName
                                                                guid:guid
                                                           selection:selection];
    }];
}

- (void)arrangementWithName:(NSString *)arrangementName
              hasInvalidPWD:(NSString *)badPWD
         forSessionWithGuid:(NSString *)sessionGUID {
    RLog(@"Arrangement %@ has bad pwd of %@ for session guid %@", arrangementName, badPWD, sessionGUID);
    if ([iTermAdvancedSettingsModel noSyncSuppressBadPWDInArrangementWarning]) {
        return;
    }
    NSString *notice = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.the_saved_arrangement_has_a_bad_initial_directory.1afaaaf9", nil, NSBundle.mainBundle, @"The saved arrangement “%@” has a bad initial directory of “%@” for this session.", @"User-facing announcement format string."), arrangementName, badPWD];

    [self.delegate naggingControllerShowMessage:notice
                                     isQuestion:NO
                                      important:NO
                                     identifier:iTermNaggingControllerArrangementProfileMissingIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.don_t_warn_again.4e0cbb59", nil, NSBundle.mainBundle, @"Don’t Warn Again", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.repair.1196b6c5", nil, NSBundle.mainBundle, @"Repair", @"Announcement action.") ]
                                     completion:^(int selection) {
        [self handleCompletionForInvalidPWDInArrangementWithName:arrangementName
                                                            guid:sessionGUID
                                                       selection:selection];
    }];
}

- (void)handleCompletionForInvalidPWDInArrangementWithName:(NSString *)arrangementName
                                                      guid:(NSString *)guid
                                                 selection:(int)selection {
    if (selection == 0) {
        [iTermAdvancedSettingsModel setNoSyncSuppressBadPWDInArrangementWarning:YES];
        return;
    }
    if (selection == 1) {
        [self.delegate naggingControllerRepairInitialWorkingDirectoryOfSessionWithGUID:guid
                                                                 inArrangementWithName:arrangementName];
    }
}

- (void)didRestoreOrphan {
    [self.delegate naggingControllerShowMessage:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.this_already_running_session_was_restored_but_its.4b39a0ee", nil, NSBundle.mainBundle, @"This already-running session was restored but its contents were not saved.", @"User-facing announcement message.")
                                     isQuestion:YES
                                      important:NO
                                     identifier:iTermNaggingControllerOrphanIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.why.5d8a995a", nil, NSBundle.mainBundle, @"Why?", @"Announcement action.") ]
                                     completion:^(int selection) {
        if (selection == 0) {
            // Why?
            NSURL *whyUrl = [NSURL URLWithString:@"https://iterm2.com/why_no_content.html"];
            [[NSWorkspace sharedWorkspace] it_openURL:whyUrl
                                               target:nil
                                                style:iTermOpenStyleTab
                                               window:self.delegate.naggingControllerWindow];
        }
    }];
}

- (void)sessionEndedWithExecFailure:(BOOL)execDidFail {
    [self.delegate naggingControllerShowMessage:execDidFail ? NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.session_failed_to_start.2319836a", nil, NSBundle.mainBundle, @"Session failed to start.", @"User-facing announcement message.") : NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.session_ended_command_exited_restart_it.f17115d4", nil, NSBundle.mainBundle, @"Session ended (command exited). Restart it?", @"User-facing announcement message.")
                                     isQuestion:!execDidFail
                                      important:YES
                                     identifier:iTermNaggingControllerReopenSessionAfterBrokenPipeIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.restart.b09ca3b4", nil, NSBundle.mainBundle, @"_Restart", @"Announcement action; underscore marks the Option-key shortcut."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.don_t_ask_again.6137db69", nil, NSBundle.mainBundle, @"Don’t Ask Again", @"Announcement action.") ]
                                     completion:^(int selection) {
        [self handleCompletionForBrokenPipe:selection];
    }];
}

- (void)askAboutAbortingDownload {
    [self.delegate naggingControllerShowMessage:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.a_file_is_being_downloaded_abort_the_download.b0ad087c", nil, NSBundle.mainBundle, @"A file is being downloaded. Abort the download?", @"User-facing announcement message.")
                                     isQuestion:YES
                                      important:YES
                                     identifier:iTermNaggingControllerAbortDownloadIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.ok.565339bc", nil, NSBundle.mainBundle, @"OK", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.cancel.19766ed6", nil, NSBundle.mainBundle, @"Cancel", @"Announcement action.") ]
                                     completion:^(int selection) {
        if (selection == 0) {
            [self.delegate naggingControllerAbortDownload];
        }
    }];
}

- (void)askAboutAbortingUpload {
    [self.delegate naggingControllerShowMessage:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.a_file_is_being_uploaded_abort_the_upload.fdefd95e", nil, NSBundle.mainBundle, @"A file is being uploaded. Abort the upload?", @"User-facing announcement message.")
                                     isQuestion:YES
                                      important:YES
                                     identifier:iTermNaggingControllerAbortUploadOnKeyPressAnnouncementIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.ok.565339bc", nil, NSBundle.mainBundle, @"OK", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.cancel.19766ed6", nil, NSBundle.mainBundle, @"Cancel", @"Announcement action.") ]
                                     completion:^(int selection) {
        if (selection == 0) {
            [self.delegate naggingControllerAbortUpload];
        }
    }];
}

- (void)didFinishDownload {
    [self.delegate naggingControllerRemoveMessageWithIdentifier:iTermNaggingControllerAbortDownloadIdentifier];
}

- (void)didRepairSavedArrangement {
    [self.delegate naggingControllerRemoveMessageWithIdentifier:iTermNaggingControllerArrangementProfileMissingIdentifier];
}

- (void)willRecycleSession {
    NSArray<NSString *> *identifiers = @[
        iTermNaggingControllerOrphanIdentifier,
        iTermNaggingControllerReopenSessionAfterBrokenPipeIdentifier,
        iTermNaggingControllerAbortDownloadIdentifier,
        iTermNaggingControllerAbortUploadOnKeyPressAnnouncementIdentifier ];
    for (NSString *identifier in identifiers) {
        [self.delegate naggingControllerRemoveMessageWithIdentifier:identifier];
    }
}

- (void)tmuxSupplementaryPlaneErrorForCharacter:(NSString *)string {
    NSString *message = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.because_of_a_bug_in_tmux_2_2.45e87eff", nil, NSBundle.mainBundle, @"Because of a bug in tmux 2.2, the character “%@” cannot be sent.", @"User-facing announcement format string."), string];
    [self.delegate naggingControllerShowMessage:message
                                     isQuestion:NO
                                      important:NO
                                     identifier:iTermNaggingControllerTmuxSupplementaryPlaneErrorIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.why.5d8a995a", nil, NSBundle.mainBundle, @"Why?", @"Announcement action.") ]
                                     completion:^(int selection) {
        if (selection == 0) {
            [self showTmuxSupplementaryPlaneBugHelpPage];
        }
    }];
}

- (void)showTmuxSupplementaryPlaneBugHelpPage {
    NSURL *whyUrl = [NSURL URLWithString:@"https://iterm2.com//tmux22bug.html"];
    [[NSWorkspace sharedWorkspace] it_openURL:whyUrl
                                       target:nil
                                        style:iTermOpenStyleTab
                                       window:self.delegate.naggingControllerWindow];
}

- (void)tryingToSendArrowKeysWithScrollWheel:(BOOL)isTrying {
    if (!isTrying) {
        [self.delegate naggingControllerRemoveMessageWithIdentifier:iTermNaggingControllerAskAboutAlternateMouseScrollIdentifier];
        return;
    }
    if ([[iTermUserDefaults userDefaults] boolForKey:iTermNaggingControllerUserDefaultNeverAskAboutSettingAlternateMouseScroll]) {
        return;
    }
    [self.delegate naggingControllerShowMessage:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.do_you_want_the_scroll_wheel_to_move.77b77f1b", nil, NSBundle.mainBundle, @"Do you want the scroll wheel to move the cursor in interactive programs like this?", @"User-facing announcement message.")
                                     isQuestion:YES
                                      important:YES
                                     identifier:iTermNaggingControllerAskAboutAlternateMouseScrollIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.yes.85a39ab3", nil, NSBundle.mainBundle, @"Yes", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.don_t_ask_again.a7373bf6", nil, NSBundle.mainBundle, @"Don‘t Ask Again", @"Announcement action.") ]
                                     completion:^(int selection) {
        [self handleTryingToSendArrowKeysWithScrollWheel:selection];
    }];
}

- (void)handleTryingToSendArrowKeysWithScrollWheel:(int)selection {
    switch (selection) {
        case 0: // Yes
            [iTermAdvancedSettingsModel setAlternateMouseScroll:YES];
            break;

        case 1: { // Never
            [[iTermUserDefaults userDefaults] setBool:YES forKey:iTermNaggingControllerUserDefaultNeverAskAboutSettingAlternateMouseScroll];
            break;
        }
    }
}

- (void)setBackgroundImageToFileWithName:(NSString *)maybeFilename {
    NSString *filename = maybeFilename ?: @"";
    DLog(@"screenSetbackgroundImageFile:%@", filename);

    NSUserDefaults *userDefaults = [iTermUserDefaults userDefaults];
    NSArray *allowedFiles = [userDefaults objectForKey:iTermNaggingControllerUserDefaultAlwaysAllowBackgroundImage];
    NSArray *deniedFiles = [userDefaults objectForKey:iTermNaggingControllerUserDefaultAlwaysDenyBackgroundImage];
    if ([deniedFiles containsObject:filename]) {
        return;
    }
    if ([allowedFiles containsObject:filename]) {
        [self.delegate naggingControllerSetBackgroundImageToFileWithName:filename];
        return;
    }

    NSString *title;
    if (filename.length) {
        title = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.set_background_image_to.6cd0c9d7", nil, NSBundle.mainBundle, @"Set background image to “%@”?", @"User-facing announcement format string."), filename];
    } else {
        title = NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.remove_background_image.0fe1b7b8", nil, NSBundle.mainBundle, @"Remove background image?", @"User-facing warning message.");
    }
    [self.delegate naggingControllerShowMessage:title
                                     isQuestion:YES
                                      important:NO
                                     identifier:iTermNaggingControllerSetBackgroundImageFileIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.yes.85a39ab3", nil, NSBundle.mainBundle, @"Yes", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.always.de9f057a", nil, NSBundle.mainBundle, @"Always", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.never.6300ef80", nil, NSBundle.mainBundle, @"Never", @"Announcement action.") ]
                                     completion:^(int selection) {
        [self handleSetBackgroundImageToFileWithName:filename selection:selection];
    }];
}

- (void)handleSetBackgroundImageToFileWithName:(NSString *)filename selection:(int)selection {
    NSUserDefaults *userDefaults = [iTermUserDefaults userDefaults];
    switch (selection) {
        case 0: // Yes
            if (!filename.length) {
                DLog(@"Filename is empty. Reset the background image.");
                [self.delegate naggingControllerSetBackgroundImageToFileWithName:nil];
                return;
            }
            [self.delegate naggingControllerSetBackgroundImageToFileWithName:filename];
            break;

        case 1: { // Always
            NSArray *allowed = [userDefaults objectForKey:iTermNaggingControllerUserDefaultAlwaysAllowBackgroundImage];
            if (!allowed) {
                allowed = @[];
            }
            allowed = [allowed arrayByAddingObject:filename];
            [userDefaults setObject:allowed forKey:iTermNaggingControllerUserDefaultAlwaysAllowBackgroundImage];
            if (!filename.length) {
                DLog(@"Filename is empty. Reset the background image.");
                [self.delegate naggingControllerSetBackgroundImageToFileWithName:nil];
                return;
            }
            [self.delegate naggingControllerSetBackgroundImageToFileWithName:filename];
            break;
        }
        case 2: {  // Never
            NSArray *denied = [userDefaults objectForKey:iTermNaggingControllerUserDefaultAlwaysDenyBackgroundImage];
            if (!denied) {
                denied = @[];
            }
            denied = [denied arrayByAddingObject:filename];
            [userDefaults setObject:denied forKey:iTermNaggingControllerUserDefaultAlwaysDenyBackgroundImage];
            break;
        }
    }
}

- (void)didDetectMouseReportingFrustration {
    if ([iTermAdvancedSettingsModel noSyncNeverAskAboutMouseReportingFrustration]) {
        return;
    }
    [self.delegate naggingControllerShowMessage:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.looks_like_you_re_trying_to_copy_to.7e7a6136", nil, NSBundle.mainBundle, @"Looks like you’re trying to copy to the pasteboard, but mouse reporting has prevented making a selection. Disable mouse reporting?", @"User-facing announcement message.")
                                     isQuestion:YES
                                      important:YES
                                     identifier:iTermNaggingControllerAskAboutMouseReportingFrustrationIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.temporarily.ca14778a", nil, NSBundle.mainBundle, @"_Temporarily", @"Announcement action; underscore marks the Option-key shortcut."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.permanently.d06138e2", nil, NSBundle.mainBundle, @"Permanently", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.stop_asking.ba90d712", nil, NSBundle.mainBundle, @"Stop Asking", @"Announcement action.") ]
                                     completion:^(int selection) {
        [self handleMouseReportingFrustration:selection];
    }];
}

- (void)handleMouseReportingFrustration:(int)selection {
    switch (selection) {
        case 0: // Temporarily
            [self.delegate naggingControllerDisableMouseReportingPermanently:NO];
            break;

        case 1: { // Never
            [self.delegate naggingControllerDisableMouseReportingPermanently:YES];
            break;
        }

        case 2: { // Stop asking
            [iTermAdvancedSettingsModel setNoSyncNeverAskAboutMouseReportingFrustration:YES];
        }
    }
}

- (void)offerToTurnOffBracketedPasteOnHostChange {
    NSString *title;
    title = NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.looks_like_paste_bracketing_was_left_on_when.f86b5af5", nil, NSBundle.mainBundle, @"Looks like paste bracketing was left on when an ssh session ended unexpectedly or an app misbehaved. Turn it off?", @"User-facing warning message.");

    [self.delegate naggingControllerShowMessage:title
                                     isQuestion:YES
                                      important:YES
                                     identifier:kTurnOffBracketedPasteOnHostChangeAnnouncementIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.yes.b481b415", nil, NSBundle.mainBundle, @"_Yes", @"Announcement action; underscore marks the Option-key shortcut."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.always.de9f057a", nil, NSBundle.mainBundle, @"Always", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.never.6300ef80", nil, NSBundle.mainBundle, @"Never", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.help.b79cac92", nil, NSBundle.mainBundle, @"Help", @"Announcement action.") ]
                                     completion:^(int selection) {
        switch (selection) {
            case -2:  // Dismiss programmatically
                break;

            case -1: // No
                break;

            case 0: // Yes
                [self.delegate naggingControllerDisableBracketedPasteMode];
                break;

            case 1: // Always
                [[iTermUserDefaults userDefaults] setBool:YES
                                                        forKey:kTurnOffBracketedPasteOnHostChangeUserDefaultsKey];
                [self.delegate naggingControllerDisableBracketedPasteMode];
                break;

            case 2: // Never
                [[iTermUserDefaults userDefaults] setBool:NO
                                                        forKey:kTurnOffBracketedPasteOnHostChangeUserDefaultsKey];
                break;

            case 3: // Help
                [[NSWorkspace sharedWorkspace] it_openURL:[NSURL URLWithString:@"https://iterm2.com/paste_bracketing"]
                                                   target:nil
                                                    style:iTermOpenStyleTab
                                                   window:self.delegate.naggingControllerWindow];
                break;
        }
    }];
}

- (BOOL)shouldResetKeyReportingMode {
    NSNumber *number = [[iTermUserDefaults userDefaults] objectForKey:kResetKeyReportingModeUserDefaultsKey];
    if (number.boolValue) {
        // User chose "Always" - caller should reset
        return YES;
    }
    if (number != nil) {
        // User chose "Never" - do nothing
        return NO;
    }
    // User hasn't chosen yet - show nag
    NSString *title = NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.the_key_reporting_mode_may_have_been_left.f176e939", nil, NSBundle.mainBundle, @"The key reporting mode may have been left in an unusual setting when an ssh session died or an app crashed. Restore?", @"User-facing warning message.");

    [self.delegate naggingControllerShowMessage:title
                                     isQuestion:YES
                                      important:YES
                                     identifier:kResetKeyReportingModeAnnouncementIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.yes.b481b415", nil, NSBundle.mainBundle, @"_Yes", @"Announcement action; underscore marks the Option-key shortcut."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.always.de9f057a", nil, NSBundle.mainBundle, @"Always", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.never.6300ef80", nil, NSBundle.mainBundle, @"Never", @"Announcement action.") ]
                                     completion:^(int selection) {
        switch (selection) {
            case -2:  // Dismiss programmatically
                break;

            case -1: // No
                break;

            case 0: // Yes
                [self.delegate naggingControllerResetKeyReportingMode];
                break;

            case 1: // Always
                [[iTermUserDefaults userDefaults] setBool:YES
                                                        forKey:kResetKeyReportingModeUserDefaultsKey];
                [self.delegate naggingControllerResetKeyReportingMode];
                break;

            case 2: // Never
                [[iTermUserDefaults userDefaults] setBool:NO
                                                        forKey:kResetKeyReportingModeUserDefaultsKey];
                break;
        }
    }];
    return NO;
}

- (void)dismissKeyReportingModeOffer {
    [self.delegate naggingControllerRemoveMessageWithIdentifier:kResetKeyReportingModeAnnouncementIdentifier];
}

- (void)offerToRestoreIconName:(NSString *)iconName windowName:(NSString *)windowName {
    NSString *title;
    title = NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.automatically_restore_the_tab_and_window_title_when.8f464a98", nil, NSBundle.mainBundle, @"Automatically restore the tab and window title when an ssh session ends?", @"User-facing warning message.");

    _pendingRestoreIconName = [iconName copy];
    _pendingRestoreWindowName = [windowName copy];
    _hasPendingRestoreOffer = YES;

    [self.delegate naggingControllerShowMessage:title
                                     isQuestion:YES
                                      important:YES
                                     identifier:kRestoreIconAndWindowNameOnHostChangeAnnouncementIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.only_this_time.155a11ec", nil, NSBundle.mainBundle, @"_Only This Time", @"Announcement action; underscore marks the Option-key shortcut."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.always.de9f057a", nil, NSBundle.mainBundle, @"Always", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.never.6300ef80", nil, NSBundle.mainBundle, @"Never", @"Announcement action.") ]
                                     completion:^(int selection) {
        switch (selection) {
            case -2:  // Dismiss programmatically
                [self clearPendingRestoreOffer];
                break;

            case -1: // No
                [self clearPendingRestoreOffer];
                break;

            case 0: // Only This Time
                [self clearPendingRestoreOffer];
                [self.delegate naggingControllerRestoreIconNameTo:iconName windowName:windowName];
                break;

            case 1: // Always
                [self clearPendingRestoreOffer];
                [[iTermUserDefaults userDefaults] setBool:YES
                                                        forKey:kRestoreIconAndWindowNameOnHostChangeUserDefaultsKey];
                [self.delegate naggingControllerRestoreIconNameTo:iconName windowName:windowName];
                [[NSNotificationCenter defaultCenter] postNotificationName:iTermNaggingControllerRestoreIconAndWindowNameChoiceNotification
                                                                    object:nil
                                                                  userInfo:@{ iTermNaggingControllerRestoreIconAndWindowNameChoiceAlwaysKey: @YES }];
                break;

            case 2: // Never
                [self clearPendingRestoreOffer];
                [[iTermUserDefaults userDefaults] setBool:NO
                                                        forKey:kRestoreIconAndWindowNameOnHostChangeUserDefaultsKey];
                [[NSNotificationCenter defaultCenter] postNotificationName:iTermNaggingControllerRestoreIconAndWindowNameChoiceNotification
                                                                    object:nil
                                                                  userInfo:@{ iTermNaggingControllerRestoreIconAndWindowNameChoiceAlwaysKey: @NO }];
                break;
        }
    }];
}

- (void)clearPendingRestoreOffer {
    _hasPendingRestoreOffer = NO;
    _pendingRestoreIconName = nil;
    _pendingRestoreWindowName = nil;
}

- (void)restoreIconAndWindowNameChoiceMade:(NSNotification *)notification {
    if (!_hasPendingRestoreOffer) {
        return;
    }
    NSString *iconName = _pendingRestoreIconName;
    NSString *windowName = _pendingRestoreWindowName;
    const BOOL always = [notification.userInfo[iTermNaggingControllerRestoreIconAndWindowNameChoiceAlwaysKey] boolValue];
    [self clearPendingRestoreOffer];
    if (always) {
        [self.delegate naggingControllerRestoreIconNameTo:iconName windowName:windowName];
    }
    [self.delegate naggingControllerRemoveMessageWithIdentifier:kRestoreIconAndWindowNameOnHostChangeAnnouncementIdentifier];
}

- (void)offerToDisableTriggersInInteractiveAppsWithStats:(NSString *)stats {
    if (![self.delegate naggingControllerCanShowMessageWithIdentifier:kTurnOffSlowTriggersOfferUserDefaultsKey]) {
        DLog(@"Don't show warning");
        return;
    }
    if ([[[iTermUserDefaults userDefaults] objectForKey:kTurnOffSlowTriggersOfferUserDefaultsKey] isEqual:@NO]) {
        return;
    }
    NSString *title;
    title = NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.this_session_s_triggers_are_pretty_slow_disable.c207b402", nil, NSBundle.mainBundle, @"This session’s triggers are pretty slow. Disable them in interactive apps?", @"User-facing warning message.");

    [self.delegate naggingControllerShowMessage:title
                                     isQuestion:YES
                                      important:YES
                                     identifier:kTurnOffSlowTriggersOfferUserDefaultsKey
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.yes.b481b415", nil, NSBundle.mainBundle, @"_Yes", @"Announcement action; underscore marks the Option-key shortcut."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.stop_asking.ba90d712", nil, NSBundle.mainBundle, @"Stop Asking", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.view_stats.2ddb8956", nil, NSBundle.mainBundle, @"View Stats", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.help.b79cac92", nil, NSBundle.mainBundle, @"Help", @"Announcement action.") ]
                                     completion:^(int selection) {
        switch (selection) {
            case -2:  // Dismiss programmatically
                break;

            case -1: // No
                break;

            case 0: // Yes
                [self.delegate naggingControllerDisableTriggersInInteractiveApps];
                break;

            case 1: // Stop Asking
                [[iTermUserDefaults userDefaults] setBool:NO
                                                        forKey:kTurnOffSlowTriggersOfferUserDefaultsKey];
                break;

            case 2:  { // View stats
                [self showStats:stats];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self offerToDisableTriggersInInteractiveAppsWithStats:stats];
                });
                break;
            }

            case 4: // Help
                [[NSWorkspace sharedWorkspace] it_openURL:[NSURL URLWithString:@"https://iterm2.com/slow_triggers"]
                                                   target:nil
                                                    style:iTermOpenStyleTab
                                                   window:self.delegate.naggingControllerWindow];
                break;
        }
    }];
}

- (void)showStats:(NSString *)stats {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"trigger-stats-%@.txt", [NSUUID UUID].UUIDString]];

    NSError *error = nil;
    BOOL ok = [stats writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!ok) {
        DLog(@"Error writing file: %@", error);
        return;
    }

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/open";
    task.arguments = @[ @"-a", @"TextEdit", path ];
    [task launch];
}

- (void)tmuxDidUpdatePasteBuffer {
    if (![self.delegate naggingControllerCanShowMessageWithIdentifier:iTermNaggingControllerOfferToSyncTmuxClipboard]) {
        DLog(@"Don't show warning");
        return;
    }
    if ([[iTermUserDefaults userDefaults] objectForKey:kPreferenceKeyTmuxSyncClipboard]) {
        DLog(@"Nag disabled");
        return;
    }
    if ([iTermPreferences boolForKey:kPreferenceKeyTmuxSyncClipboard]) {
        return;
    }
    [self.delegate naggingControllerShowMessage:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.the_tmux_paste_buffer_was_updated_would_you.a75c1c6b", nil, NSBundle.mainBundle, @"The tmux paste buffer was updated. Would you like to mirror it to the local clipboard from now on?", @"User-facing announcement message.")
                                     isQuestion:YES
                                      important:NO
                                     identifier:iTermNaggingControllerOfferToSyncTmuxClipboard
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.always.5d2c8ee0", nil, NSBundle.mainBundle, @"_Always", @"Announcement action; underscore marks the Option-key shortcut."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.never.aa373939", nil, NSBundle.mainBundle, @"_Never", @"Announcement action; underscore marks the Option-key shortcut.") ]
                                     completion:^(int selection) {
        switch (selection) {
            case -2:  // Dismiss programatically
                break;
            case -1: // No
                break;

            case 0: // Always
                [iTermPreferences setBool:YES forKey:kPreferenceKeyTmuxSyncClipboard];
                break;

            case 1:  // Never
                [iTermPreferences setBool:NO forKey:kPreferenceKeyTmuxSyncClipboard];
                break;
        }
    }];
}

- (BOOL)shouldAskAboutClearingScrollbackHistory {
    return iTermAdvancedSettingsModel.preventEscapeSequenceFromClearingHistory == nil;
}

- (void)askAboutClearingScrollbackHistory {
    NSString *message = NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.a_control_sequence_attempted_to_clear_scrollback_history.7cae0484", nil, NSBundle.mainBundle, @"A control sequence attempted to clear scrollback history. Allow this in the future?", @"User-facing announcement message.");
    [self.delegate naggingControllerShowMessage:message
                                     isQuestion:YES
                                      important:NO
                                     identifier:iTermNaggingControllerAskAboutClearingScrollbackHistoryIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.always_allow.98c85017", nil, NSBundle.mainBundle, @"Always _Allow", @"Announcement action; underscore marks the Option-key shortcut."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.always_deny.a9ba1293", nil, NSBundle.mainBundle, @"Always _Deny", @"Announcement action; underscore marks the Option-key shortcut.") ]
                                     completion:^(int selection) {
        switch (selection) {
            case 0: {
                const BOOL value = NO;
                iTermAdvancedSettingsModel.preventEscapeSequenceFromClearingHistory = &value;
                break;
            }
            case 1: {
                const BOOL value = YES;
                iTermAdvancedSettingsModel.preventEscapeSequenceFromClearingHistory = &value;
                break;
            }
        }
    }];
}

- (void)openCommandDidFailWithSecureInputEnabled {
    if (!iTermAdvancedSettingsModel.warnAboutSecureKeyboardInputWithOpenCommand) {
        return;
    }
    NSString *message = NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.the_open_command_doesn_t_activate_other_apps.a4076cbc", nil, NSBundle.mainBundle, @"The open command doesn't activate other apps when Secure Keyboard Input is enabled.", @"User-facing announcement message.");
    [self.delegate naggingControllerShowMessage:message
                                     isQuestion:YES
                                      important:NO
                                     identifier:iTermNaggingControllerWarnAboutSecureKeyboardInputWithOpenCommand
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.don_t_remind_me_again.861fd7e7", nil, NSBundle.mainBundle, @"Don’t Remind Me Again", @"Announcement action.") ]
                                     completion:^(int selection) {
        switch (selection) {
            case 0: {
                iTermAdvancedSettingsModel.warnAboutSecureKeyboardInputWithOpenCommand = NO;
                break;
            }
        }
    }];
}

- (BOOL)terminalCanChangeProfile {
    const BOOL *boolPtr = iTermAdvancedSettingsModel.preventEscapeSequenceFromChangingProfile;
    if (boolPtr) {
        return !*boolPtr;
    }
    NSString *message = NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.a_control_sequence_attempted_to_change_the_current.ed15e7f3", nil, NSBundle.mainBundle, @"A control sequence attempted to change the current profile. Allow this in the future?", @"User-facing announcement message.");
    [self.delegate naggingControllerShowMessage:message
                                     isQuestion:YES
                                      important:NO
                                     identifier:iTermNaggingControllerAskAboutChangingProfileIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.always_allow.98c85017", nil, NSBundle.mainBundle, @"Always _Allow", @"Announcement action; underscore marks the Option-key shortcut."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.always_deny.a9ba1293", nil, NSBundle.mainBundle, @"Always _Deny", @"Announcement action; underscore marks the Option-key shortcut.") ]
                                     completion:^(int selection) {
        switch (selection) {
            case 0: {
                const BOOL value = NO;
                iTermAdvancedSettingsModel.preventEscapeSequenceFromChangingProfile = &value;
                break;
            }
            case 1: {
                const BOOL value = YES;
                iTermAdvancedSettingsModel.preventEscapeSequenceFromChangingProfile = &value;
                break;
            }
        }
    }];
    return NO;
}

- (BOOL)tmuxWindowsShouldCloseAfterDetach {
    const BOOL *boolPtr = iTermAdvancedSettingsModel.tmuxWindowsShouldCloseAfterDetach;
    if (boolPtr) {
        return *boolPtr;
    }
    NSString *message = NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.close_tmux_windows_after_detaching.01165835", nil, NSBundle.mainBundle, @"Close tmux windows after detaching?", @"User-facing announcement message.");
    [self.delegate naggingControllerShowMessage:message
                                     isQuestion:YES
                                      important:YES
                                     identifier:iTermNaggingControllerTmuxWindowsShouldCloseAfterDetach
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.always.5d2c8ee0", nil, NSBundle.mainBundle, @"_Always", @"Announcement action; underscore marks the Option-key shortcut."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.never.aa373939", nil, NSBundle.mainBundle, @"_Never", @"Announcement action; underscore marks the Option-key shortcut.") ]
                                     completion:^(int selection) {
        if (selection == 0 || selection == 1) {
            BOOL value = (selection == 0);
            iTermAdvancedSettingsModel.tmuxWindowsShouldCloseAfterDetach = &value;
            [[NSNotificationCenter defaultCenter] postNotificationName:iTermNaggingControllerDidChangeTmuxWindowsShouldCloseAfterDetach
                                                                object:@(value)];
        }
    }];
    return NO;
}

- (void)didChangeTmuxWindowsShouldCloseAfterDetach:(NSNotification *)notification {
    [self.delegate naggingControllerRemoveMessageWithIdentifier:iTermNaggingControllerTmuxWindowsShouldCloseAfterDetach];
    if ([notification.object boolValue]) {
        [self.delegate naggingControllerCloseSession];
    }
}

- (void)showJSONPromotion {
    [_delegate naggingControllerShowMessage:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.that_s_a_gnarly_json_blob_you_ve.0f1fc59c", nil, NSBundle.mainBundle, @"That's a gnarly JSON blob you've got there! iTerm2 can replace this hard-to-read selection with a pretty-printed value.", @"User-facing announcement message.")
                                 isQuestion:NO
                                  important:NO
                                 identifier:@"JSONPromotion"
                                    options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.try_it_now.4a165b2e", nil, NSBundle.mainBundle, @"Try it Now", @"Announcement action."),
                                               NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.dismiss.48845bff", nil, NSBundle.mainBundle, @"Dismiss", @"Announcement action.") ]
                                 completion:^(int selection) {
        switch (selection) {
            case -2:  // Dismiss programmatically
                break;

            case -1: // Closed
                break;

            case 0: // try
                [self.delegate naggingControllerPrettyPrintJSON];
                break;

            case 1:  // Dismiss
                // The caller is responsible for not showing the promotion more than once.
                break;
        }
    }];
}

- (void)openURL:(NSURL *)url {
    NSString *allowHostKey = [NSString stringWithFormat:@"NoSyncAllowOpenURL_host:%@", url.host];

    if ([iTermAdvancedSettingsModel noSyncDisableOpenURL]) {
        RLog(@"OpenUrl disabled");
        return;
    }
    if ([iTermSecureUserDefaults openURLWithHost:url.host]) {
        DLog(@"Always allow %@", url.host);
        [[NSWorkspace sharedWorkspace] it_openURL:url
                                           target:nil
                                            style:iTermOpenStyleTab
                                           window:self.delegate.naggingControllerWindow];
        return;
    }

    [_delegate naggingControllerShowMessage:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.open_this_url.fefcf422", nil, NSBundle.mainBundle, @"Open this URL? %@", @"User-facing announcement format string."), url.sanitizedForPrinting.absoluteString]
                                 isQuestion:YES
                                  important:YES
                                 identifier:allowHostKey
                                    options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.allow.e213c161", nil, NSBundle.mainBundle, @"Allow", @"Announcement action."),
                                               NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.always_allow_for_this_host.bd97db20", nil, NSBundle.mainBundle, @"Always allow for this host", @"Announcement action."),
                                               NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.never_allow.bbf0cfa7", nil, NSBundle.mainBundle, @"Never allow", @"Announcement action.") ]
                                 completion:^(int selection) {
        switch (selection) {
            case -2:  // Dismiss programmatically
                break;

            case -1: // Closed
                break;

            case 0: // Allow
                [[NSWorkspace sharedWorkspace] it_openURL:url
                                                   target:nil
                                                    style:iTermOpenStyleTab
                                                   window:self.delegate.naggingControllerWindow];
                break;

            case 1:  // Allow for this host
                [iTermSecureUserDefaults setOpenURLWithHost:url.host allowed:YES];
                [[NSWorkspace sharedWorkspace] it_openURL:url
                                                   target:nil
                                                    style:iTermOpenStyleTab
                                                   window:self.delegate.naggingControllerWindow];
                break;

            case 2:  // Never allow
                [iTermAdvancedSettingsModel setNoSyncDisableOpenURL:YES];
                break;
        }
    }];
}

#pragma mark - Touch ID for Sudo

static NSString *const iTermNaggingControllerTouchIDForSudoIdentifier = @"TouchIDForSudo";
static NSString *const iTermNaggingControllerTouchIDForSudoUserDefaultsKey = @"NoSyncOfferTouchIDForSudo";

- (void)offerToEnableTouchIDForSudo {
    if (_touchIDForSudoDismissed) {
        DLog(@"Touch ID for sudo offer already dismissed for this sudo invocation");
        return;
    }
    if (![self.delegate naggingControllerCanShowMessageWithIdentifier:iTermNaggingControllerTouchIDForSudoIdentifier]) {
        DLog(@"Can't show Touch ID for sudo offer");
        return;
    }
    NSNumber *setting = [[iTermUserDefaults userDefaults] objectForKey:iTermNaggingControllerTouchIDForSudoUserDefaultsKey];
    if (setting != nil) {
        RLog(@"Touch ID for sudo offer disabled by user default: %@", setting);
        return;
    }
    if ([iTermTouchIDHelper isTouchIDEnabledForSudo]) {
        DLog(@"Touch ID for sudo already enabled");
        return;
    }
    NSString *message = NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.would_you_like_to_enable_touch_id_for.94a185dd", nil, NSBundle.mainBundle, @"Would you like to enable Touch ID for sudo?", @"User-facing announcement message.");
    if ([self.delegate naggingControllerAnnouncementWouldObscureCursorForText:message]) {
        DLog(@"Announcement would obscure cursor");
        return;
    }
    [self.delegate naggingControllerShowMessage:message
                                     isQuestion:YES
                                      important:YES
                                     identifier:iTermNaggingControllerTouchIDForSudoIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.run_in_new_window.c779a0cd", nil, NSBundle.mainBundle, @"_Run In New Window", @"Announcement action; underscore marks the Option-key shortcut."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.copy_command.3bdd0fd9", nil, NSBundle.mainBundle, @"Copy Command", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.don_t_ask_again.6137db69", nil, NSBundle.mainBundle, @"Don’t Ask Again", @"Announcement action.") ]
                                     completion:^(int selection) {
        // Any explicit user action — including closing with the X (selection -1)
        // — should suppress further offers for this sudo invocation.
        if (selection != -2) {
            self->_touchIDForSudoDismissed = YES;
        }
        switch (selection) {
            case 0:  // Run In New Window
                [iTermTouchIDHelper runInstallInNewWindow];
                break;
            case 1: {  // Copy Command
                NSString *command = [iTermTouchIDHelper installCommand];
                if (command) {
                    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
                    [pasteboard clearContents];
                    [pasteboard setString:command forType:NSPasteboardTypeString];
                }
                break;
            }
            case 2:  // Don't ask again
                [[iTermUserDefaults userDefaults] setBool:NO
                                                   forKey:iTermNaggingControllerTouchIDForSudoUserDefaultsKey];
                break;
        }
    }];
}

- (void)removeTouchIDForSudoOffer {
    // Called by PTYSession when sudo is no longer the foreground job. Reset the
    // dismissal flag so future sudo invocations can offer again.
    _touchIDForSudoDismissed = NO;
    [self.delegate naggingControllerRemoveMessageWithIdentifier:iTermNaggingControllerTouchIDForSudoIdentifier];
}

#pragma mark - Variable Reporting

- (NSArray<NSString *> *)variablesToReportEntries {
    return [[[iTermAdvancedSettingsModel noSyncVariablesToReport] componentsSeparatedByString:@","] filteredArrayUsingBlock:^BOOL(NSString *anObject) {
        return anObject.length > 0;
    }];
}

- (BOOL)requestPermissionWithOriginalValue:(NSNumber *)setting
                                       key:(NSString *)key
                                    prompt:(NSString *)prompt
                                    setter:(void (^)(BOOL))setter {
    if (setting) {
        return setting.boolValue;
    }
    if (![self.delegate naggingControllerCanShowMessageWithIdentifier:key]) {
        return NO;
    }
    [self.delegate naggingControllerShowMessage:prompt
                                     isQuestion:YES
                                      important:YES
                                     identifier:key
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.always_allow.80584802", nil, NSBundle.mainBundle, @"Always Allow", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.always_deny.f9fd413a", nil, NSBundle.mainBundle, @"Always Deny", @"Announcement action.") ]
                                     completion:^(int selection) {
        if (selection == 0) {
            setter(YES);
        } else if (selection == 1) {
            setter(NO);
        }
    }];
    return NO;
}

#pragma mark - Arrangement with missing profile

- (void)handleCompletionForMissingProfileInArrangementWithName:(NSString *)savedArrangementName
                                           missingProfileNamed:(NSString *)missingProfileName
                                                          guid:(NSString *)guid
                                                     selection:(int)selection {
    if (selection == 0) {
        [iTermAdvancedSettingsModel setNoSyncSuppressMissingProfileInArrangementWarning:YES];
        return;
    }
    if (selection == 1) {
        [self.delegate naggingControllerRepairSavedArrangement:savedArrangementName
                                           missingProfileNamed:missingProfileName
                                                          guid:guid];
        return;
    }
}

- (void)handleCompletionForBrokenPipe:(int)selection {
    switch (selection) {
        case 0: // Yes
            [self.delegate naggingControllerRestart];
            break;

        case 1: // Don't ask again
            [iTermAdvancedSettingsModel setSuppressRestartAnnouncement:YES];
            break;
    }
}

#pragma mark - Claude Code Status Tool

- (void)offerClaudeCodeStatusTool:(void (^)(iTermClaudeCodeUpsellStatus))completion {
    if (![self.delegate naggingControllerCanShowMessageWithIdentifier:iTermNaggingControllerClaudeCodeStatusToolIdentifier]) {
        return;
    }
    NSString *message = NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.want_to_try_iterm2_s_claude_code_integration.49bc6941", nil, NSBundle.mainBundle, @"Want to try iTerm2’s Claude Code integration?", @"User-facing announcement message.");
    [self.delegate naggingControllerShowMessage:message
                                     isQuestion:YES
                                      important:NO
                                     identifier:iTermNaggingControllerClaudeCodeStatusToolIdentifier
                                        options:@[ NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.yes.b481b415", nil, NSBundle.mainBundle, @"_Yes", @"Announcement action; underscore marks the Option-key shortcut."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.never.6300ef80", nil, NSBundle.mainBundle, @"Never", @"Announcement action."),
                                                   NSLocalizedStringWithDefaultValue(@"ui.ptysession.itermnaggingcontroller.ask_later.605cd52f", nil, NSBundle.mainBundle, @"Ask Later", @"Announcement action.") ]
                                     completion:^(int selection) {
        [[NSNotificationCenter defaultCenter] postNotificationName:iTermNaggingControllerClaudeCodeStatusToolDismissedNotification
                                                            object:nil];
        switch (selection) {
            case 0:
                completion(iTermClaudeCodeUpsellStatusAccept);
                break;
            case 1:
                completion(iTermClaudeCodeUpsellStatusNever);
                break;
            case 2:
                completion(iTermClaudeCodeUpsellStatusAskLater);
                break;
        }
    }];
}

- (void)claudeCodeStatusToolDismissed:(NSNotification *)notification {
    [self.delegate naggingControllerRemoveMessageWithIdentifier:iTermNaggingControllerClaudeCodeStatusToolIdentifier];
}

@end
