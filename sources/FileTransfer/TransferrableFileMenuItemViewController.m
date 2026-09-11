//
//  TransferrableFileMenuItemViewController.m
//  iTerm
//
//  Created by George Nachman on 12/23/13.
//
//

#import "TransferrableFileMenuItemViewController.h"
#import "FileTransferManager.h"
#import "TransferrableFileMenuItemView.h"

static const CGFloat kWidth = 300;
static const CGFloat kHeight = 63;
static const CGFloat kCollapsedHeight = 51;

@interface TransferrableFileMenuItemViewController()<NSMenuItemValidation>
@end

@implementation TransferrableFileMenuItemViewController {
    BOOL _hasOpenedMenu;
    NSVisualEffectView *_effectView;
    TransferrableFileMenuItemView *_contentView;
}

- (instancetype)initWithTransferrableFile:(TransferrableFile *)transferrableFile {
    self = [super init];
    if (self) {
        _transferrableFile = transferrableFile;
        _effectView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(5,
                                                                           0,
                                                                           kWidth - 10,
                                                                           kHeight)];
        _effectView.material = NSVisualEffectMaterialSelection;
        _effectView.wantsLayer = YES;
        _effectView.autoresizingMask = NSViewWidthSizable;
        _effectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        _effectView.emphasized = YES;
        _effectView.layer.cornerRadius = 4;
        _effectView.layer.masksToBounds = YES;
        _effectView.state = NSVisualEffectStateActive;
        _effectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.view.autoresizesSubviews = YES;
        [self.view addSubview:_effectView];
        _contentView = [[TransferrableFileMenuItemView alloc] initWithFrame:NSMakeRect(0,
                                                                                       0,
                                                                                       kWidth,
                                                                                       kHeight)
                                                                 effectView:_effectView];
        _contentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self.view addSubview:_contentView];
    }
    return self;
}

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0,
                                                         0,
                                                         kWidth,
                                                         kHeight)];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(itemSelected:)) {
        return YES;
    }
    TransferrableFileStatus status = _transferrableFile.status;
    if ([menuItem action] == @selector(stop:)) {
        return (status == kTransferrableFileStatusStarting ||
                status == kTransferrableFileStatusTransferring);
    }
    if ([menuItem action] == @selector(showInFinder:)) {
        if (self.transferrableFile.localPath == nil ||
            [NSURL fileURLWithPath:self.transferrableFile.localPath] == nil) {
            return NO;
        }
        return (status == kTransferrableFileStatusFinishedSuccessfully);
    }
    if ([menuItem action] == @selector(removeFromList:)) {
        return (status == kTransferrableFileStatusFinishedSuccessfully ||
                status == kTransferrableFileStatusFinishedWithError ||
                status == kTransferrableFileStatusCancelled);
    }
    if ([menuItem action] == @selector(open:)) {
        return (status == kTransferrableFileStatusFinishedSuccessfully);
    }
    if ([menuItem action] == @selector(getInfo:)) {
        return YES;
    }
    return NO;
}

- (void)showMenu {
    if (!_hasOpenedMenu) {
        if (self.transferrableFile.isDownloading) {
            [[FileTransferManager sharedInstance] openDownloadsMenu];
        } else {
            [[FileTransferManager sharedInstance] openUploadsMenu];
        }
        _hasOpenedMenu = YES;
    }
}

- (void)update {
    TransferrableFileMenuItemView *view = _contentView;
    view.filename = [_transferrableFile shortName];
    view.subheading = [_transferrableFile subheading];
    double fileSize = [_transferrableFile fileSize];
    view.size = fileSize;
    if ([_transferrableFile fileSize] > 0) {
        double fraction = [_transferrableFile bytesTransferred];
        fraction /= [_transferrableFile fileSize];
        view.progressIndicator.fraction = fraction;
        [view.progressIndicator setNeedsDisplay:YES];
    }
    view.bytesTransferred = [_transferrableFile bytesTransferred];
    switch (_transferrableFile.status) {
        case kTransferrableFileStatusUnstarted:
        case kTransferrableFileStatusStarting:
            view.statusMessage = NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.starting.bbe5fc3b", nil, NSBundle.mainBundle, @"Starting…", @"User-facing file-transfer status.");
            [self collapse];
            break;

        case kTransferrableFileStatusTransferring:
            [self expand];
            [view.progressIndicator setHidden:[_transferrableFile fileSize] < 0];
            if (self.transferrableFile.isDownloading) {
                view.statusMessage = NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.downloading.a778d349", nil, NSBundle.mainBundle, @"Downloading…", @"User-facing file-transfer status.");
            } else {
                view.statusMessage = NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.uploading.5ce44dd7", nil, NSBundle.mainBundle, @"Uploading…", @"User-facing file-transfer status.");
            }
            [self showMenu];
            break;

        case kTransferrableFileStatusFinishedSuccessfully:
            [self collapse];
            view.statusMessage = NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.finished.7804f7a7", nil, NSBundle.mainBundle, @"Finished", @"User-facing file-transfer status.");
            break;

        case kTransferrableFileStatusFinishedWithError:
            [self collapse];
            view.statusMessage = NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.failed.031a8f0f", nil, NSBundle.mainBundle, @"Failed", @"User-facing file-transfer status.");
            [self showMenu];
            break;

        case kTransferrableFileStatusCancelling:
            [self expand];
            view.statusMessage = NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.cancelling.91b104db", nil, NSBundle.mainBundle, @"Cancelling…", @"User-facing file-transfer status.");
            break;

        case kTransferrableFileStatusCancelled:
            [self collapse];
            view.statusMessage = NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.cancelled.d353a99e", nil, NSBundle.mainBundle, @"Cancelled", @"User-facing file-transfer status.");
            break;
    }
    [view setNeedsDisplay:YES];
}

- (void)collapse {
    [_contentView.progressIndicator setHidden:YES];
    self.view.frame = NSMakeRect(0, 0, self.view.frame.size.width, kCollapsedHeight);
}

- (void)expand {
    [_contentView.progressIndicator setHidden:NO];
    self.view.frame = NSMakeRect(0, 0, self.view.frame.size.width, kHeight);
}

- (void)itemSelected:(id)sender {
    NSLog(@"Click");
}

- (void)stop:(id)sender {
    [self.transferrableFile stop];
}

- (void)showInFinder:(id)sender {
    NSURL *theUrl = [NSURL fileURLWithPath:self.transferrableFile.localPath];
    if (theUrl) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ theUrl ]];
    }

}
- (void)removeFromList:(id)sender {
    [[FileTransferManager sharedInstance] removeItem:self];
}

- (void)open:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:self.transferrableFile.localPath]];
}

- (NSString *)stringForStatus:(TransferrableFileStatus)status {
    switch (_transferrableFile.status) {
        case kTransferrableFileStatusUnstarted:
            return NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.unstarted.f60ed5e5", nil, NSBundle.mainBundle, @"Unstarted", @"User-facing file-transfer status in the information panel.");
        case kTransferrableFileStatusStarting:
            return NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.starting.aeed4d26", nil, NSBundle.mainBundle, @"Starting", @"User-facing file-transfer status in the information panel.");
        case kTransferrableFileStatusTransferring:
            return NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.transferring.5e16e20d", nil, NSBundle.mainBundle, @"Transferring", @"User-facing file-transfer status in the information panel.");
        case kTransferrableFileStatusFinishedSuccessfully:
            return NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.finished.7804f7a7", nil, NSBundle.mainBundle, @"Finished", @"User-facing file-transfer status.");
        case kTransferrableFileStatusFinishedWithError:
            return [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.failed_with_error.c3c5e41a", nil, NSBundle.mainBundle, @"Failed with error “%@”", @"User-facing file-transfer status; preserve the error."), [_transferrableFile error]];
        case kTransferrableFileStatusCancelling:
            return NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.waiting_to_cancel.58e9df8b", nil, NSBundle.mainBundle, @"Waiting to cancel", @"User-facing file-transfer status in the information panel.");
        case kTransferrableFileStatusCancelled:
            return NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.canceled_by_user.def50520", nil, NSBundle.mainBundle, @"Canceled by user", @"User-facing file-transfer status in the information panel.");
    }
}

- (void)getInfo:(id)sender {
    NSString *extra = @"";
    if (_transferrableFile.destination) {
        extra = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.destination.9dca4e19", nil, NSBundle.mainBundle, @"\nDestination: %@", @"Destination line in the file-transfer information panel; preserve the path."),
                       _transferrableFile.destination];
    } else if (_transferrableFile.localPath) {
        extra = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.local_path.d2ab4525", nil, NSBundle.mainBundle, @"\nLocal path: %@", @"Local-path line in the file-transfer information panel; preserve the path."),
                       _transferrableFile.localPath];
    }
    NSString *text = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.status.cd1b400a", nil, NSBundle.mainBundle, @"%@\n\nStatus: %@%@", @"Body of the file-transfer information panel; preserve the display name, status, and optional path line."),
                      [_transferrableFile displayName],
                      [self stringForStatus:_transferrableFile.status],
                      extra];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedStringWithDefaultValue(@"ui.filetransfer.transferrablefilemenuitemviewcontroller.file_transfer_summary.4780f2d0", nil, NSBundle.mainBundle, @"File Transfer Summary", @"User-facing text in TransferrableFileMenuItemViewController (getInfo:).");
    alert.informativeText = text;
    [alert layout];
    [alert runModal];
}

- (NSTimeInterval)timeSinceLastStatusChange {
    return [NSDate timeIntervalSinceReferenceDate] - [_transferrableFile timeOfLastStatusChange];
}

@end
