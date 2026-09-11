//
//  iTermShellIntegrationDownloadAndRunViewController.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 12/22/19.
//

#import "iTermShellIntegrationDownloadAndRunViewController.h"

@interface iTermShellIntegrationDownloadAndRunViewController ()

@property (nonatomic, weak) IBOutlet id<iTermShellIntegrationInstallerDelegate> shellInstallerDelegate;
@property (nonatomic, strong) IBOutlet NSButton *continueButton;
@property (nonatomic, strong) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic, strong) IBOutlet NSTextField *textField;

@end

@implementation iTermShellIntegrationDownloadAndRunViewController

- (void)willAppear {
    self.continueButton.enabled = YES;
    self.progressIndicator.hidden = YES;
    [self setInstallUtilities:_installUtilities];
}

- (NSString *)urlString {
    if (self.installUtilities) {
        return @"https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh";
    }
    return @"https://iterm2.com/shell_integration/install_shell_integration.sh";
}

- (NSString *)command {
    return [NSString stringWithFormat:@"\ncurl -L %@ | bash", self.urlString];
}

- (void)setInstallUtilities:(BOOL)installUtilities {
    _installUtilities = installUtilities;
    NSString *prefix = self.busy
        ? NSLocalizedStringWithDefaultValue(@"ui.shellintegrationinstaller.itermshellintegrationdownloadandrunviewcontroller.waiting_for_this_command_to_finish.8d0e39f7", nil, NSBundle.mainBundle, @"Waiting for this command to finish:", @"Status shown while the Shell Integration install command is running.")
        : NSLocalizedStringWithDefaultValue(@"ui.shellintegrationinstaller.itermshellintegrationdownloadandrunviewcontroller.press_continue_to_run_this_command.ee83a63a", nil, NSBundle.mainBundle, @"Press “Continue” to run this command:", @"Instruction shown before running the Shell Integration install command.");
    self.textField.stringValue = [NSString stringWithFormat:@"%@\n%@", prefix, self.command];
}

- (void)showShellUnsupportedError {
    self.textField.stringValue = NSLocalizedStringWithDefaultValue(@"ui.shellintegrationinstaller.itermshellintegrationdownloadandrunviewcontroller.your_shell_is_not_supported_or_perhaps_your.915fbe26", nil, NSBundle.mainBundle, @"😞 Your shell is not supported, or perhaps your $SHELL environment variable is not set correctly. Press “Continue” to try again.", @"User-facing text in iTermShellIntegrationDownloadAndRunViewController (showShellUnsupportedError).");
}

- (IBAction)pipeCurlToBash:(id)sender {
    [self.shellInstallerDelegate shellIntegrationInstallerReallyDownloadAndRun];
    self.continueButton.enabled = NO;
}

- (void)setBusy:(BOOL)busy {
    _busy = busy;
    self.continueButton.enabled = !busy;
    self.progressIndicator.hidden = !busy;
    if (busy) {
        [self.progressIndicator startAnimation:nil];
    } else {
        [self.progressIndicator stopAnimation:nil];
    }
}

@end
