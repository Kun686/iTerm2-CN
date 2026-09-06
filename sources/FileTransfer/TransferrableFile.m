//
//  TransferrableFile.m
//  iTerm
//
//  Created by George Nachman on 12/23/13.
//
//

#import "TransferrableFile.h"

#import "DebugLogging.h"
#import "NSFileManager+iTerm.h"
#import "iTermNotificationController.h"
#import "iTermWarning.h"

@implementation TransferrableFile {
    NSTimeInterval _timeOfLastStatusChange;
    TransferrableFileStatus _status;
    TransferrableFile *_successor;
}

static NSMutableSet<NSString *> *iTermTransferrableFileLockedFileNames(void) {
    static NSMutableSet<NSString *> *locks;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        locks = [[NSMutableSet alloc] init];
    });
    return locks;
}

+ (void)lockFileName:(NSString *)name {
    if (name) {
        [iTermTransferrableFileLockedFileNames() addObject:name];
    }
}

+ (void)unlockFileName:(NSString *)name {
    if (name) {
        [iTermTransferrableFileLockedFileNames() removeObject:name];
    }
}

+ (BOOL)fileNameIsLocked:(NSString *)name {
    if (!name) {
        return NO;
    }
    return [iTermTransferrableFileLockedFileNames() containsObject:name];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _status = kTransferrableFileStatusUnstarted;
        _fileSize = -1;
    }
    return self;
}

- (NSString *)protocolName {
    assert(false);
}

- (NSString *)authRequestor {
    assert(false);
}

- (NSString *)displayName {
    assert(false);
}

- (NSString *)shortName {
    assert(false);
}

- (NSString *)subheading {
    assert(false);
}

- (void)download {
    assert(false);
}

- (void)upload {
    assert(false);
}

- (void)stop {
    assert(false);
}

- (NSString *)localPath {
    assert(false);
}

- (NSString *)error {
    assert(false);
}

- (NSString *)destination  {
    assert(false);
}

- (BOOL)isDownloading {
    assert(false);
}

- (NSString *)finalDestinationForPath:(NSString *)originalBaseName
                 destinationDirectory:(NSString *)destinationDirectory
                               prompt:(BOOL)prompt {
    NSString *baseName = originalBaseName;
    if (self.isZipOfFolder) {
        baseName = [baseName stringByAppendingString:@".zip"];
    }
    NSString *name = baseName;
    NSString *finalDestination = nil;
    int retries = 0;
    do {
        finalDestination = [destinationDirectory stringByAppendingPathComponent:name];
        ++retries;
        NSRange rangeOfDot = [baseName rangeOfString:@"."];
        NSString *prefix = baseName;
        NSString *suffix = @"";
        if (rangeOfDot.length > 0) {
            prefix = [baseName substringToIndex:rangeOfDot.location];
            suffix = [baseName substringFromIndex:rangeOfDot.location];
        }
        name = [NSString stringWithFormat:@"%@ (%d)%@", prefix, retries, suffix];
    } while ([[NSFileManager defaultManager] fileExistsAtPath:finalDestination] ||
             [TransferrableFile fileNameIsLocked:finalDestination]);
    if (retries == 1 || !prompt) {
        return finalDestination;
    }
    NSString *message = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefile.a_file_named_already_exists_keep_both_files.bc569339", nil, NSBundle.mainBundle, @"A file named %@ already exists. Keep both files or replace the existing file?", @"User-facing overwrite warning; preserve the file name."), baseName];
    const iTermWarningSelection selection = [iTermWarning showWarningWithTitle:message
                                                                       actions:@[ NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefile.keep_both.38b99fe6", nil, NSBundle.mainBundle, @"Keep Both", @"User-facing action label in TransferrableFile (actions)."), NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefile.replace.95e15439", nil, NSBundle.mainBundle, @"Replace", @"User-facing action label in TransferrableFile (actions).") ]
                                                                     accessory:nil
                                                                    identifier:@"NoSyncOverwriteOrReplaceFile"
                                                                   silenceable:kiTermWarningTypePermanentlySilenceable
                                                                       heading:NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefile.overwrite_existing_file.fd5136b3", nil, NSBundle.mainBundle, @"Overwrite existing file?", @"User-facing text in TransferrableFile (heading).")
                                                                        window:nil];
    if (selection == kiTermWarningSelection1) {
        return [destinationDirectory stringByAppendingPathComponent:baseName];
    }
    return finalDestination;
}

- (NSString *)downloadsDirectory {
    return [[NSFileManager defaultManager] downloadsDirectory] ?: NSHomeDirectory();
}

- (void)setSuccessor:(TransferrableFile *)successor {
    @synchronized(self) {
        [_successor autorelease];
        _successor = [successor retain];
        successor.hasPredecessor = YES;
    }
}

- (TransferrableFile *)successor {
    @synchronized(self) {
        return _successor;
    }
}

- (void)didFailWithError:(NSString *)error {
    RLog(@"didFailWithError:%@", error);
    @synchronized(self) {
        if (_status != kTransferrableFileStatusFinishedWithError) {
            _status = kTransferrableFileStatusFinishedWithError;
            _timeOfLastStatusChange = [NSDate timeIntervalSinceReferenceDate];
            [[iTermNotificationController sharedInstance] notify:error];
        }
    }
}

- (void)setStatus:(TransferrableFileStatus)status {
    DLog(@"setStatus:%@\n%@", @(status), [NSThread callStackSymbols]);
    @synchronized(self) {
        if (status != _status) {
            _status = status;
            _timeOfLastStatusChange = [NSDate timeIntervalSinceReferenceDate];
            switch (status) {
                case kTransferrableFileStatusUnstarted:
                case kTransferrableFileStatusStarting:
                case kTransferrableFileStatusTransferring:
                case kTransferrableFileStatusCancelling:
                case kTransferrableFileStatusCancelled:
                    break;

                case kTransferrableFileStatusFinishedSuccessfully:
                    [[iTermNotificationController sharedInstance] notify:
                        [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefile.finished_for.82a08d9c", nil, NSBundle.mainBundle, @"%@ finished for “%@”.", @"User-facing successful-transfer notification; preserve the transfer type and file name."),
                            self.isDownloading ? NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefile.download.d6eafe82", nil, NSBundle.mainBundle, @"Download", @"Transfer type in a user-facing notification.") : NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefile.upload.865e89de", nil, NSBundle.mainBundle, @"Upload", @"Transfer type in a user-facing notification."), [self shortName]]];
                    break;

                case kTransferrableFileStatusFinishedWithError:
                    [[iTermNotificationController sharedInstance] notify:
                     [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefile.failed_for.1fdaa5c1", nil, NSBundle.mainBundle, @"%@ failed for “%@”.", @"User-facing failed-transfer notification; preserve the transfer type and file name."),
                      self.isDownloading ? NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefile.download.d6eafe82", nil, NSBundle.mainBundle, @"Download", @"Transfer type in a user-facing notification.") : NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefile.upload.865e89de", nil, NSBundle.mainBundle, @"Upload", @"Transfer type in a user-facing notification."), [self shortName]]];
            }
        }
    }
}

- (TransferrableFileStatus)status {
    @synchronized(self) {
        return _status;
    }
}

- (NSTimeInterval)timeOfLastStatusChange {
    return _timeOfLastStatusChange;
}

- (void)failedToRemoveUnquarantinedFileAt:(NSString *)path {
    [iTermWarning showWarningWithTitle:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefile.the_file_at_could_not_be_quarantined_or.12810c3b", nil, NSBundle.mainBundle, @"The file at “%@” could not be quarantined or deleted! It is dangerous and should be removed.", @"User-facing security warning; preserve the file path."), path]
                               actions:@[ NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefile.ok.565339bc", nil, NSBundle.mainBundle, @"OK", @"User-facing action label in TransferrableFile (actions).") ]
                             accessory:nil
                            identifier:nil
                           silenceable:kiTermWarningTypePersistent
                               heading:NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefile.danger.849ca3bd", nil, NSBundle.mainBundle, @"Danger!", @"User-facing text in TransferrableFile (heading).")
                                window:nil];
}

- (BOOL)quarantine:(NSString *)path sourceURL:(NSURL *)sourceURL {
    if (!path) {
        XLog(@"Nil path to quarantine");
        return NO;
    }
    NSURL *url = [NSURL fileURLWithPath:path];

    NSMutableDictionary *properties = nil;
    {
        NSError *error = nil;
        NSDictionary *temp;
        const BOOL ok = [url getResourceValue:&temp
                                       forKey:NSURLQuarantinePropertiesKey
                                        error:&error];
        if (!ok) {
            XLog(@"Get quarantine of %@ failed: %@", path, error);
            return NO;
        }
        if (temp && ![temp isKindOfClass:[NSDictionary class]]) {
            XLog(@"Quarantine of wrong class: %@", NSStringFromClass([temp class]));
            return NO;
        }
        properties = [[temp ?: @{} mutableCopy] autorelease];
    }

    NSBundle *bundle = [NSBundle mainBundle];
    NSDictionary *info = bundle.infoDictionary;
    properties[(__bridge NSString *)kLSQuarantineAgentNameKey] = info[(__bridge NSString *)kCFBundleNameKey] ?: @"iTerm2";
    properties[(__bridge NSString *)kLSQuarantineAgentBundleIdentifierKey] = info[(__bridge NSString *)kCFBundleIdentifierKey] ?: @"com.googlecode.iterm2";
    if (sourceURL.absoluteString) {
        properties[(__bridge NSString *)kLSQuarantineDataURLKey] = sourceURL.absoluteString;
    }
    properties[(__bridge NSString *)kLSQuarantineTimeStampKey] = [NSDate date];
    properties[(__bridge NSString *)kLSQuarantineTypeKey] = (__bridge NSString *)kLSQuarantineTypeOtherDownload;

    {
        NSError *error = nil;
        const BOOL ok = [url setResourceValue:properties
                                       forKey:NSURLQuarantinePropertiesKey
                                        error:&error];
        if (!ok) {
            XLog(@"Set quarantine of %@ failed: %@", path, error);
            return NO;
        }
    }
    return YES;
}

@end
