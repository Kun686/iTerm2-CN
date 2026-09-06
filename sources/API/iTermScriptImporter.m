//
//  iTermScriptImporter.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 6/24/18.
//

#import "iTermScriptImporter.h"

#import "DebugLogging.h"
#import "iTerm2SharedARC-Swift.h"
#import "iTermBuildingScriptWindowController.h"
#import "iTermCommandRunner.h"
#import "iTermScriptArchive.h"
#import "iTermScriptHistory.h"
#import "iTermWarning.h"
#import "NSFileManager+iTerm.h"
#import "NSWorkspace+iTerm.h"
#import "SIGArchiveVerifier.h"
#import "SIGCertificate.h"

static BOOL sInstallingScript;

// The ".replacing-<name>-<UUID>" naming used to move a script aside during a replace and to
// recover a leaked backup at launch. The UUID string is always 36 characters, so the
// original name is everything between the prefix and that fixed-length suffix (names may
// themselves contain hyphens).
static NSString *const iTermReplaceBackupPrefix = @".replacing-";
static const NSUInteger iTermReplaceBackupUUIDSuffixLength = 1 + 36;  // "-" + UUID

// The dotted staging name iTermScriptArchive uses to rename a finished install into place
// atomically. A leftover at launch is always an orphan (a completed install renames it
// away), so the recovery sweep just deletes it.
static NSString *const iTermInstallStagingPrefix = @".installing-";

@implementation iTermScriptImporter

+ (void)importScriptFromURL:(NSURL *)downloadedURL
              userInitiated:(BOOL)userInitiated
            offerAutoLaunch:(BOOL)offerAutoLaunch
              callbackQueue:(dispatch_queue_t)callbackQueue
                    avoidUI:(BOOL)avoidUI
                 completion:(void (^)(NSString *errorMessage, BOOL quiet, NSURL *location))completion {
    RLog(@"dowloadedURL=%@ userInitiated=%@ offerAutoLaunch=%@", downloadedURL, @(userInitiated), @(offerAutoLaunch));
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.iterm2.install-script", DISPATCH_QUEUE_SERIAL);
    });
    dispatch_async(queue, ^{
        dispatch_group_t group = dispatch_group_create();
        dispatch_group_enter(group);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self reallyImportScriptFromURL:downloadedURL
                              userInitiated:userInitiated
                            offerAutoLaunch:offerAutoLaunch
                              callbackQueue:callbackQueue
                                    avoidUI:avoidUI
                                 completion:^(NSString *errorMessage, BOOL quiet, NSURL *location) {
                DLog(@"errorMessage=%@ quiet=%@ location=%@", errorMessage, @(quiet), location);
                dispatch_group_leave(group);
                completion(errorMessage, quiet, location);
            }];
        });
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    });
}

+ (void)reallyImportScriptFromURL:(NSURL *)downloadedURL
                    userInitiated:(BOOL)userInitiated
                  offerAutoLaunch:(BOOL)offerAutoLaunch
                    callbackQueue:(dispatch_queue_t)callbackQueue
                          avoidUI:(BOOL)avoidUI
                       completion:(void (^)(NSString *errorMessage, BOOL quiet, NSURL *location))completion {
    DLog(@"downloadedURL=%@ userInitiated=%@ offerAutoLauch=%@", downloadedURL, @(userInitiated), @(offerAutoLaunch));
    if (sInstallingScript) {
        RLog(@"already installing");
        completion(NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.another_import_in_progress.7339fd5a", nil, NSBundle.mainBundle, @"Another import is in progress. Please try again after it completes.", @"Error shown when another script import is already running."), NO, nil);
        return;
    }

    if ([downloadedURL.pathExtension isEqualToString:@"py"]) {
        NSString *to = [[[NSFileManager defaultManager] scriptsPathWithoutSpaces] stringByAppendingPathComponent:downloadedURL.lastPathComponent];
        DLog(@"ends in .py, just copy it to %@", to);
        NSError *error;
        [[NSFileManager defaultManager] copyItemAtURL:downloadedURL
                                                toURL:[NSURL fileURLWithPath:to]
                                                error:&error];
        DLog(@"%@", error);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error.localizedDescription, NO, error ? nil : [NSURL fileURLWithPath:to]);
        });
        return;
    }
    sInstallingScript = YES;
    DLog(@"Will verify and unwrap");
    [self verifyAndUnwrapArchive:downloadedURL requireSignature:!userInitiated completion:^(NSURL *url, NSString *errorMessage, BOOL trusted, BOOL reveal, BOOL quiet) {
        RLog(@"Verify and unwrap done with errorMessage=%@", errorMessage);
        if (errorMessage) {
            completion(errorMessage, quiet, nil);
            sInstallingScript = NO;
            return;
        }

        // Do not show the please-wait window eagerly: a uv full-environment install first
        // asks for download consent (and may prompt to replace an existing script), and a
        // premature "Building Script…" window would float over those. Show it only once
        // provisioning actually begins (after the download/consent), matching the
        // create/Dependency-Editor progress sequencing. Unzip is effectively instant, and
        // basic/legacy installs have their own UI or none.
        // Create it hidden: newPleaseWaitWindowController would order the window front
        // immediately, floating it over the intervening "Script Already Exists" and uv
        // "Download Python Support?" prompts. Order it front for the first time only in
        // provisioningDidBegin, after those prompts, when provisioning actually starts.
        iTermBuildingScriptWindowController *pleaseWait = reveal ? nil : [iTermBuildingScriptWindowController newPleaseWaitWindowControllerOrderingFront:NO];
        void (^provisioningDidBegin)(void) = ^{
            DLog(@"Open please wait window");
            [pleaseWait.window makeKeyAndOrderFront:nil];
        };
        NSString *tempDir = [[NSFileManager defaultManager] it_temporaryDirectory];

        DLog(@"Unzip %@", url);
        [iTermCommandRunner unzipURL:url
                       withArguments:@[ @"-q" ]
                         destination:tempDir
                       callbackQueue:callbackQueue
                          completion:^(NSError *error) {
            DLog(@"Unzip finished with %@", error);
            if (error) {
                [pleaseWait.window close];
                completion([NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.could_not_unzip_archive.10d8a12a", nil, NSBundle.mainBundle, @"Could not unzip archive: %@", @"Error shown when a script archive cannot be unzipped. Preserve the error placeholder."), error.localizedDescription], NO, nil);
                sInstallingScript = NO;
                return;
            }
            [self didUnzipSuccessfullyTo:tempDir
                                 trusted:trusted
                         offerAutoLaunch:offerAutoLaunch
                                  reveal:reveal
                                 avoidUI:avoidUI
                    provisioningDidBegin:provisioningDidBegin
                          withCompletion:
             ^(NSString *errorMessage, BOOL quiet, NSURL *location) {
                RLog(@"All done! errorMessage=%@", errorMessage);
                sInstallingScript = NO;
                if (reveal) {
                    completion(errorMessage, errorMessage == nil || quiet, nil);
                    return;
                }
                [self eraseTempDir:tempDir];
                [pleaseWait.window close];
                completion(errorMessage, quiet, location);
            }];
        }];
    }];
}

+ (void)verifyAndUnwrapArchive:(NSURL *)url
              requireSignature:(BOOL)requireSignature
                    completion:(void (^)(NSURL *url, NSString *, BOOL trusted, BOOL reveal, BOOL quiet))completion {
    DLog(@"url=%@ requireSignature=%@", url, @(requireSignature));
    SIGArchiveVerifier *verifier = [[SIGArchiveVerifier alloc] initWithURL:url];
    if ([[url pathExtension] isEqualToString:@"its"]) {
        DLog(@"Is .its");
        if (![verifier smellsLikeSignedArchive:NULL]) {
            DLog(@"Doesn't smell like signed archive");
            completion(nil, NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.script_archive_corrupt.9e4b2526", nil, NSBundle.mainBundle, @"This script archive is corrupt and cannot be installed.", @"Error shown when a script archive is corrupt."), NO, NO, NO);
            return;
        }
        
        NSURL *zipURL = [NSURL fileURLWithPath:[[NSWorkspace sharedWorkspace] temporaryFileNameWithPrefix:@"script" suffix:@".zip"]];
        DLog(@"Will verify");
        [verifier verifyWithCompletion:^(BOOL ok, NSError * _Nullable error) {
            DLog(@"verify done ok=%@ error=%@", @(ok), error);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self verifierDidComplete:verifier
                              withSuccess:ok
                               payloadURL:zipURL
                         requireSignature:requireSignature
                                    error:error
                               completion:completion];
            });
        }];
        return;
    }
    if (requireSignature) {
        completion(nil, NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.invalid_iterm2_script_archive.b144e1a0", nil, NSBundle.mainBundle, @"This is not a valid iTerm2 script archive.", @"Error shown when a required signed script archive is invalid."), NO, NO, NO);
        return;
    }
    completion(url, nil, NO, NO, NO);
}

+ (void)verifierDidComplete:(SIGArchiveVerifier *)verifier
                withSuccess:(BOOL)ok
                 payloadURL:(NSURL *)zipURL
           requireSignature:(BOOL)requireSignature
                      error:(NSError *)error
                 completion:(void (^)(NSURL *url, NSString *, BOOL trusted, BOOL reveal, BOOL quiet))completion {
    DLog(@"ok=%@ zipURL=%@ requireSignature=%@", @(ok), zipURL, @(requireSignature));
    if (!ok) {
        DLog(@"Not OK");
        completion(nil, error.localizedDescription ?: NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.unknown_error.27c2ccd9", nil, NSBundle.mainBundle, @"Unknown error", @"Fallback error shown while importing a script."), NO, NO, NO);
        return;
    }
    
    if (requireSignature) {
        NSData *data = [[verifier.reader signingCertificates:nil] firstObject];
        if (!data) {
            DLog(@"No cert data");
            completion(nil, NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.certificate_missing_nil_data.e22b867e", nil, NSBundle.mainBundle, @"Could not find certificate after verficiation (nil data)", @"Error shown when script archive verification returns no certificate data."), NO, NO, NO);
            return;
        }
        SIGCertificate *cert = [[SIGCertificate alloc] initWithData:data];
        if (!cert) {
            DLog(@"Bad data");
            completion(nil, NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.certificate_missing_bad_data.6a233ca0", nil, NSBundle.mainBundle, @"Could not find certificate after verficiation (bad data)", @"Error shown when script archive verification returns invalid certificate data."), NO, NO, NO);
            return;
        }
        [self confirmInstallationOfVerifiedArchive:verifier.reader
                                   withCertificate:cert
                                        completion:^(BOOL ok, BOOL reveal) {
            RLog(@"Confirmation ok=%@ reveal=%@", @(ok), @(reveal));
            if (!ok) {
                DLog(@"Canceled");
                completion(nil, NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.installation_canceled.1125e313", nil, NSBundle.mainBundle, @"Installation canceled by user request.", @"Outcome message when the user cancels script installation."), NO, NO, YES);
                return;
            }
            DLog(@"Will copy payload");
            [self copyPayloadFromVerifier:verifier
                                    toURL:zipURL
                               completion:^(NSURL *URL, NSString *errorString) {
                DLog(@"Done copying payload url=%@ errorString=%@", URL, errorString);
                completion(URL, errorString, YES, reveal, NO);
            }];
        }];
        return;
    }
    [self copyPayloadFromVerifier:verifier
                            toURL:zipURL
                       completion:^(NSURL *URL, NSString *errorString) {
                           completion(URL, errorString, YES, NO, NO);
                       }];
}

+ (void)copyPayloadFromVerifier:(SIGArchiveVerifier *)verifier
                          toURL:(NSURL *)zipURL
                     completion:(void (^)(NSURL *, NSString *))completion {
    NSError *innerError = nil;
    const BOOL ok = [verifier copyPayloadToURL:zipURL error:&innerError];
    DLog(@"%@", innerError);
    if (!ok) {
        completion(nil, innerError.localizedDescription ?: NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.unknown_error.27c2ccd9", nil, NSBundle.mainBundle, @"Unknown error", @"Fallback error shown while importing a script."));
        return;
    }
    completion(zipURL, nil);
}

+ (void)revealPayloadFromVerifier:(SIGArchiveVerifier *)verifier
                           zipURL:(NSURL *)zipURL {

}

+ (void)confirmInstallationOfVerifiedArchive:(SIGArchiveReader *)reader
                             withCertificate:(SIGCertificate *)cert
                                  completion:(void (^)(BOOL ok, BOOL toTemp))completion {
    DLog(@"Confirming");
    NSString *body = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.the_signature_of_has_been_verified_the_author_is_would_you_like_to_insta.ab386218", nil, NSBundle.mainBundle, @"The signature of ”%@” has been verified. The author is:\n\n%@\n\nWould you like to install it?", @"User-facing text in iTermScriptImporter (indirect UI)."),
                      reader.url.lastPathComponent,
                      ((cert.name ?: cert.longDescription) ?: NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.unknown.b764cdc0", nil, NSBundle.mainBundle, @"Unknown", @"User-facing phrase fragment in iTermScriptImporter."))];
    iTermWarningSelection selection = [iTermWarning showWarningWithTitle:body
                                                                 actions:@[ NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.ok.565339bc", nil, NSBundle.mainBundle, @"OK", @"User-facing action label in iTermScriptImporter (actions)."), NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.cancel.19766ed6", nil, NSBundle.mainBundle, @"Cancel", @"User-facing action label in iTermScriptImporter (actions)."), NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.reveal_contents.03c0877a", nil, NSBundle.mainBundle, @"Reveal Contents", @"User-facing action label in iTermScriptImporter (actions).") ]
                                                               accessory:nil
                                                              identifier:nil
                                                             silenceable:kiTermWarningTypePersistent
                                                                 heading:NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.confirm_installation.81e71716", nil, NSBundle.mainBundle, @"Confirm Installation", @"User-facing text in iTermScriptImporter (heading).")
                                                                  window:nil];
    completion(selection != kiTermWarningSelection1, selection == kiTermWarningSelection2);
}

+ (void)didUnzipSuccessfullyTo:(NSString *)tempDir
                       trusted:(BOOL)trusted
               offerAutoLaunch:(BOOL)offerAutoLaunch
                        reveal:(BOOL)reveal
                       avoidUI:(BOOL)avoidUI
          provisioningDidBegin:(void (^)(void))provisioningDidBegin
                withCompletion:(void (^)(NSString *errorMessage, BOOL, NSURL *location))completion {
    [self didUnzipSuccessfullyTo:tempDir
                         trusted:trusted
                 offerAutoLaunch:offerAutoLaunch
                          reveal:reveal
                         avoidUI:avoidUI
            provisioningDidBegin:provisioningDidBegin
           replacedScriptBackup:nil
                  withCompletion:completion];
}

// replacedScriptBackup, when non-nil, is a path the caller moved a same-named existing
// script to before this (re)install. On success it is deleted; on failure or user
// cancellation it is restored over the destination and the outcome is surfaced (never a
// quiet "success"), so a replace whose install is canceled does not leave the user with
// no script.
+ (void)didUnzipSuccessfullyTo:(NSString *)tempDir
                       trusted:(BOOL)trusted
               offerAutoLaunch:(BOOL)offerAutoLaunch
                        reveal:(BOOL)reveal
                       avoidUI:(BOOL)avoidUI
          provisioningDidBegin:(void (^)(void))provisioningDidBegin
          replacedScriptBackup:(NSString *)replacedScriptBackup
                withCompletion:(void (^)(NSString *errorMessage, BOOL, NSURL *location))completion {
    DLog(@"didUnzipSuccessfullyTo:%@, trusted:%@, offerAutoLaunch:%@, reveal:%@, avoidUI:%@",
         tempDir,
         @(trusted),
         @(offerAutoLaunch),
         @(reveal),
         @(avoidUI));

    if (reveal) {
        DLog(@"Reveal in finder");
        [[NSWorkspace sharedWorkspace] it_openURL:[NSURL fileURLWithPath:tempDir]
                                           target:nil
                                            style:iTermOpenStyleTab
                                           window:nil];
        completion(nil, NO, nil);
        return;
    }

    BOOL deprecated = NO;
    iTermScriptArchive *archive = [iTermScriptArchive archiveFromContainer:tempDir
                                                                deprecated:&deprecated];
    if (!archive) {
        RLog(@"Failed to extract archive from container");
        if (deprecated) {
            DLog(@"deprecated");
            completion(NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.archive_from_older_iterm2_unsupported.a8b19949", nil, NSBundle.mainBundle, @"This archive was created by an older version of iTerm2. This kind of archive is no longer supported and cannot be installed.", @"Error shown when importing an unsupported script archive made by an older iTerm2 version."), NO, nil);
        } else {
            DLog(@"invalid");
            completion(NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.archive_missing_valid_script.7d8307d5", nil, NSBundle.mainBundle, @"Archive does not contain a valid iTerm2 script", @"Error shown when an archive does not contain a valid iTerm2 script."), NO, nil);
        }
        return;
    }

    if ([self haveScriptNamed:archive.name]) {
        DLog(@"Already have a script named %@", archive.name);
        iTermWarningSelection selection = kiTermWarningSelection0;
        if (!avoidUI) {
            selection = [iTermWarning showWarningWithTitle:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.a_script_named_is_already_installed.be945841", nil, NSBundle.mainBundle, @"A script named “%@” is already installed", @"User-facing text in iTermScriptImporter (showWarningWithTitle)."), archive.name]
                                                   actions:@[ NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.replace_script.64453b4a", nil, NSBundle.mainBundle, @"Replace Script", @"User-facing action label in iTermScriptImporter (actions)."), NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.cancel.19766ed6", nil, NSBundle.mainBundle, @"Cancel", @"User-facing action label in iTermScriptImporter (actions).") ]
                                                 accessory:nil
                                                identifier:nil
                                               silenceable:kiTermWarningTypePersistent
                                                   heading:NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.script_already_exists.dd835987", nil, NSBundle.mainBundle, @"Script Already Exists", @"User-facing text in iTermScriptImporter (heading).")
                                                    window:nil];
        }
        if (selection == kiTermWarningSelection0) {
            DLog(@"Move aside and retry");
            // Move the existing script aside rather than deleting it, so a failed or
            // canceled (re)install can restore it. If the move-aside itself fails, do NOT
            // fall back to deleting the original and proceeding: a later cancel would then
            // report a quiet success with the script already gone (the very bug this
            // move-aside flow fixed). Abort the replace and leave the script untouched.
            NSString *backup = [self moveAsideScriptNamed:archive.name];
            if (backup == nil) {
                completion([NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.could_not_replace_existing_script.27aec263", nil, NSBundle.mainBundle, @"Could not replace “%@”: the existing script could not be moved aside, so it was left unchanged.", @"Error shown when an existing script cannot be moved aside for replacement. Preserve the script-name placeholder."), archive.name],
                           NO, nil);
                return;
            }
            [self didUnzipSuccessfullyTo:tempDir
                                 trusted:trusted
                         offerAutoLaunch:offerAutoLaunch
                                  reveal:reveal
                                 avoidUI:avoidUI
                    provisioningDidBegin:provisioningDidBegin
                    replacedScriptBackup:backup
                          withCompletion:completion];
            return;
        }
        DLog(@"Give up");
        completion(nil, YES, nil);
        return;
    }

    [archive installTrusted:trusted
            offerAutoLaunch:offerAutoLaunch
                    avoidUI:avoidUI
       provisioningDidBegin:provisioningDidBegin
             withCompletion:^(NSError *error, NSURL *location) {
        RLog(@"Install finished with %@", error);
        const BOOL canceled = (error != nil && [iTermUvProvisioner isCancelationError:error]);
        if (error != nil) {
            // Failure or cancellation: if we replaced an existing script, put it back so
            // the user is not left with nothing, and surface the outcome rather than
            // reporting a quiet success (which would hide that the replacement never
            // happened and the original was gone).
            if (replacedScriptBackup != nil) {
                [self restoreReplacedScriptToPath:[[[NSFileManager defaultManager] scriptsPath] stringByAppendingPathComponent:archive.name]
                                       fromBackup:replacedScriptBackup];
                NSString *message = canceled
                    ? [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.replacement_canceled_existing_script_kept.3db71812", nil, NSBundle.mainBundle, @"Replacing “%@” was canceled. The existing script was kept.", @"Outcome shown when replacing a script is canceled and the existing script is restored. Preserve the script-name placeholder."), archive.name]
                    : (error.localizedDescription ?: NSLocalizedStringWithDefaultValue(@"ui.api.itermscriptimporter.the_script_could_not_be_installed.aa4e1cd0", nil, NSBundle.mainBundle, @"The script could not be installed.", @"Fallback error shown when a script installation fails."));
                completion(message, NO, nil);
                return;
            }
            if (canceled) {
                // Fresh install the user declined: finish quietly with no error dialog.
                completion(nil, YES, nil);
                return;
            }
            completion(error.localizedDescription, NO, location);
            return;
        }
        // Success: the replacement is in place, so discard the backup of the old script.
        if (replacedScriptBackup != nil) {
            [[NSFileManager defaultManager] removeItemAtPath:replacedScriptBackup error:nil];
        }
        completion(nil, NO, location);
    }];
}

+ (void)eraseTempDir:(NSString *)tempDir {
    [[NSFileManager defaultManager] removeItemAtPath:tempDir
                                               error:nil];
}

+ (BOOL)haveScriptNamed:(NSString *)name {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager fileExistsAtPath:[[fileManager scriptsPath] stringByAppendingPathComponent:name]];
}

+ (void)removeScriptNamed:(NSString *)name {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [[fileManager scriptsPath] stringByAppendingPathComponent:name];
    iTermScriptHistoryEntry *entry = [[iTermScriptHistory sharedInstance] runningEntryWithFullPath:path];
    if (entry) {
        [entry kill];
    }
    [fileManager removeItemAtPath:path error:nil];
}

// Kill a running instance and move the existing script aside (not delete), returning the
// backup path, or nil if the move failed. The backup is a hidden sibling in the scripts
// folder so the move stays on one volume (script environments can be multi-GB); the dot
// prefix keeps the menu's tree walk from descending into it.
+ (NSString *)moveAsideScriptNamed:(NSString *)name {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *scriptsPath = [fileManager scriptsPath];
    NSString *path = [scriptsPath stringByAppendingPathComponent:name];
    iTermScriptHistoryEntry *entry = [[iTermScriptHistory sharedInstance] runningEntryWithFullPath:path];
    if (entry) {
        [entry kill];
    }
    NSString *backupName = [NSString stringWithFormat:@"%@%@-%@", iTermReplaceBackupPrefix, name, [[NSUUID UUID] UUIDString]];
    NSString *backupPath = [scriptsPath stringByAppendingPathComponent:backupName];
    NSError *error = nil;
    if (![fileManager moveItemAtPath:path toPath:backupPath error:&error]) {
        RLog(@"Could not move aside %@ to %@: %@", path, backupPath, error);
        return nil;
    }
    return backupPath;
}

// Restore a script previously moved aside by moveAsideScriptNamed:, discarding whatever
// partial install (or leftover symlink) now sits at targetPath.
+ (void)restoreReplacedScriptToPath:(NSString *)targetPath fromBackup:(NSString *)backupPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:targetPath error:nil];
    NSError *error = nil;
    if (![fileManager moveItemAtPath:backupPath toPath:targetPath error:&error]) {
        RLog(@"Could not restore %@ from %@: %@", targetPath, backupPath, error);
    }
}

// Recover backups left by an import that died between move-aside and restore/cleanup
// (see moveAsideScriptNamed:). Called once at launch, mirroring the saved-iterm2env
// reclamation. If the target script is present again the replacement completed and the
// backup leaked, so delete it; otherwise the replace never finished, so restore the
// user's original script rather than leave it as a hidden orphan.
+ (void)recoverStaleReplaceBackups {
    [self recoverStaleReplaceBackupsInDirectory:[[NSFileManager defaultManager] scriptsPath]];
}

+ (void)recoverStaleReplaceBackupsInDirectory:(NSString *)scriptsPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *entry in [fileManager contentsOfDirectoryAtPath:scriptsPath error:nil]) {
        if ([entry hasPrefix:iTermInstallStagingPrefix]) {
            // An orphaned atomic-install staging dir; a completed install renames it away.
            NSString *stagingPath = [scriptsPath stringByAppendingPathComponent:entry];
            RLog(@"Removing orphaned install staging dir %@", stagingPath);
            [fileManager removeItemAtPath:stagingPath error:nil];
            continue;
        }
        if (![entry hasPrefix:iTermReplaceBackupPrefix]) {
            continue;
        }
        NSString *afterPrefix = [entry substringFromIndex:iTermReplaceBackupPrefix.length];
        if (afterPrefix.length <= iTermReplaceBackupUUIDSuffixLength) {
            continue;  // Too short to carry a name plus a UUID; not ours.
        }
        // Validate the fixed-length tail really is "-<UUID>" before treating this as our
        // backup, so a user file coincidentally named ".replacing-…" is never renamed to a
        // truncated garbage name.
        NSString *tail = [afterPrefix substringFromIndex:afterPrefix.length - iTermReplaceBackupUUIDSuffixLength];
        if (![tail hasPrefix:@"-"] ||
            [[NSUUID alloc] initWithUUIDString:[tail substringFromIndex:1]] == nil) {
            continue;
        }
        NSString *name = [afterPrefix substringToIndex:afterPrefix.length - iTermReplaceBackupUUIDSuffixLength];
        NSString *backupPath = [scriptsPath stringByAppendingPathComponent:entry];
        NSString *targetPath = [scriptsPath stringByAppendingPathComponent:name];
        // Use lstat (attributesOfItemAtPath does NOT follow symlinks). During a
        // full-environment replace the target is a symlink into a temp extraction dir that
        // survives an app crash, and a plain fileExistsAtPath would follow it, conclude the
        // replace succeeded, and delete the user's only backup. The replacement is complete
        // only when the target is a REAL item; a symlink (or nothing) means it did not
        // finish, so restore the original (restore removes the leftover link first).
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:targetPath error:nil];
        const BOOL targetIsRealItem = (attributes != nil &&
                                       ![attributes.fileType isEqualToString:NSFileTypeSymbolicLink]);
        if (targetIsRealItem) {
            RLog(@"Removing leaked replace-backup %@ (target %@ present)", backupPath, name);
            [fileManager removeItemAtPath:backupPath error:nil];
        } else {
            RLog(@"Restoring replace-backup %@ to %@ after interrupted import", backupPath, name);
            [self restoreReplacedScriptToPath:targetPath fromBackup:backupPath];
        }
    }
}

@end
