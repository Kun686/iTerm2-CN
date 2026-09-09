//
//  iTermShellIntegrationPasteShellCommandsViewController.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 12/22/19.
//

#import "iTermShellIntegrationPasteShellCommandsViewController.h"

@interface iTermShellIntegrationPasteShellCommandsViewController ()

@property (nonatomic, strong) IBOutlet NSTextField *textField;
@property (nonatomic, strong) IBOutlet NSButton *previewCommandButton1;
@property (nonatomic, strong) IBOutlet NSButton *previewCommandButton2;
@property (nonatomic, strong) IBOutlet NSButton *previewCommandButton3;
@property (nonatomic, strong) IBOutlet NSButton *previewCommandButton4;
@property (nonatomic, strong) IBOutlet NSTextView *previewTextView;
@property (nonatomic, strong) IBOutlet NSViewController *popoverViewController;
@property (nonatomic, strong) IBOutlet NSPopover *popover;
@property (nonatomic, strong) IBOutlet NSButton *continueButton;
@property (nonatomic, strong) IBOutlet NSButton *skipButton;

@end

@implementation iTermShellIntegrationPasteShellCommandsViewController {
    BOOL _busy;
}

- (void)setShell:(iTermShellIntegrationShell)shell {
    _shell = shell;
    if (shell == iTermShellIntegrationShellUnknown) {
        self.continueButton.enabled = NO;
    } else {
        self.continueButton.enabled = YES;
    }
}

- (void)setStage:(int)stage {
    _stage = stage;
    [self update];
}

- (NSString *)waitingText {
    return NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.waiting", nil, NSBundle.mainBundle, @"⏳ Waiting for command to complete…", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.");
}
- (void)update {
    const int stage = _stage;
    if (stage < 0) {
        self.shell = iTermShellIntegrationShellUnknown;
    }
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSInteger indexToBold = NSNotFound;
    NSString *step;
    NSString *prefix;

    if (stage < 0) {
        prefix = NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.discover_initial", nil, NSBundle.mainBundle, @"1. Discover", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.");
    } else if (stage == 0) {
        if (_busy) {
            prefix = self.waitingText;
        } else {
            prefix = NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.discover_next", nil, NSBundle.mainBundle, @"➡ Select “Continue” to discover", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.");
        }
        indexToBold = lines.count;
    } else if (stage > 0) {
        if (self.shell == iTermShellIntegrationShellUnknown) {
            prefix = NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.unsupported", nil, NSBundle.mainBundle, @"🛑 Your shell is not supported.\n\nOnly bash, fish, tcsh, xonsh, and zsh work with shell integration", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.");
        } else {
            prefix = NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.discovered", nil, NSBundle.mainBundle, @"✅ Discovered", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.");
        }
    }
    if (self.shell == iTermShellIntegrationShellUnknown || (_busy && stage == 0)) {
        step = prefix;
    } else {
        step = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.shell_suffix", nil, NSBundle.mainBundle, @"%@ your shell", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments."), prefix];
    }
    if (stage > 0) {
        if (self.shell != iTermShellIntegrationShellUnknown) {
            step = [step stringByAppendingFormat:NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.shell_detected_suffix", nil, NSBundle.mainBundle, @": you use “%@”.", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments."), iTermShellIntegrationShellString(self.shell)];
        }
    } else if (stage != 0 || !_busy) {
        step = [step stringByAppendingString:NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.period", nil, NSBundle.mainBundle, @".", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.")];
    }
    [lines addObject:step];

    const BOOL unavailable = (stage == 1 && self.shell == iTermShellIntegrationShellUnknown);
    self.continueButton.enabled = !(unavailable || _busy);
    if (unavailable) {
        self.skipButton.enabled = NO;
    } else {
        if (stage < 1) {
            prefix = NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.write_initial", nil, NSBundle.mainBundle, @"Step 2. Write", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.");
        } else if (stage == 1) {
            if (self.shell == iTermShellIntegrationShellUnknown) {
                prefix = NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.write_initial", nil, NSBundle.mainBundle, @"Step 2. Write", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.");
            } else if (_busy) {
                prefix = self.waitingText;
            } else {
                prefix = NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.write_next", nil, NSBundle.mainBundle, @"➡ Select “Continue” to write", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.");
            }
            indexToBold = lines.count;
        } else if (stage > 1) {
            prefix = NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.wrote", nil, NSBundle.mainBundle, @"✅ Wrote", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.");
        }
        if (_busy && stage == 1) {
            step = prefix;
        } else {
            step = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.script_suffix", nil, NSBundle.mainBundle, @"%@ the shell integration script.", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments."), prefix];
        }
        [lines addObject:step];

        int i = 2;
        if (self.installUtilities) {
            i += 1;
            if (stage < 2) {
                prefix = NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.utilities_initial", nil, NSBundle.mainBundle, @"Step 3. Install", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.");
            } else if (stage == 2 && !_busy) {
                prefix = NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.utilities_next", nil, NSBundle.mainBundle, @"➡ Select “Continue” to install", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.");
                indexToBold = lines.count;
            } else if (stage == 2 && _busy) {
                prefix = self.waitingText;
                indexToBold = lines.count;
            } else {
                prefix = NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.installed", nil, NSBundle.mainBundle, @"✅ Installed", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.");
            }
            if (_busy && stage == 2) {
                step = prefix;
            } else {
                step = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.utilities_suffix", nil, NSBundle.mainBundle, @"%@ iTerm2 utility scripts.", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments."), prefix];
            }
            [lines addObject:step];
        }

        // Xonsh auto-loads scripts from rc.d, so no dotfile modification is needed.
        // Show this step as already complete for xonsh.
        if (self.shell == iTermShellIntegrationShellXonsh) {
            if (stage < i) {
                step = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.xonsh_step", nil, NSBundle.mainBundle, @"Step %d. Xonsh auto-loads scripts from rc.d (no dotfile update needed).", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments."), i + 1];
            } else {
                step = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.xonsh_done", nil, NSBundle.mainBundle, @"✅ Xonsh auto-loads scripts from rc.d (no dotfile update needed).", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.")];
            }
            [lines addObject:step];
        } else {
            if (stage < i) {
                prefix = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.update_step", nil, NSBundle.mainBundle, @"Step %d. Update", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments."), i + 1];
            } else if (stage == i && !_busy) {
                prefix = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.update_next", nil, NSBundle.mainBundle, @"➡ Select “Continue” to update", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.")];
                indexToBold = lines.count;
            } else if (stage == i && _busy) {
                prefix = self.waitingText;
                indexToBold = lines.count;
            } else if (stage > i) {
                prefix = NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.updated", nil, NSBundle.mainBundle, @"✅ Updated", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.");
            }
            if (_busy && stage == i) {
                step = prefix;
            } else {
                step =
                [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.dotfile_suffix", nil, NSBundle.mainBundle, @"%@ your shell's dotfile.", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments."), prefix];
            }
            [lines addObject:step];
        }
        
        // For xonsh, stage >= i means we're at the dotfile step which is a no-op,
        // so treat it as done. For other shells, we need stage > i.
        BOOL isDone = (stage > i) || (stage >= i && self.shell == iTermShellIntegrationShellXonsh);
        if (isDone) {
            [lines addObject:@""];
            indexToBold = lines.count;
            [lines addObject:NSLocalizedStringWithDefaultValue(@"ui.shell_integration.steps.done", nil, NSBundle.mainBundle, @"Done! Select “Continue” to proceed.", @"Display-only Shell Integration step text. Preserve command and shell names in format arguments.")];
            self.skipButton.enabled = NO;
        } else {
            self.skipButton.enabled = !_busy;
        }
    }

    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineSpacing = 4;
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] init];
    NSDictionary *regularAttributes =
    @{ NSFontAttributeName: [NSFont systemFontOfSize:[NSFont systemFontSize]],
       NSForegroundColorAttributeName: [NSColor textColor],
       NSParagraphStyleAttributeName: paragraphStyle
    };
    NSDictionary *boldAttributes =
    @{ NSFontAttributeName: [NSFont boldSystemFontOfSize:[NSFont systemFontSize]],
       NSForegroundColorAttributeName: [NSColor textColor],
       NSParagraphStyleAttributeName: paragraphStyle
    };
    [lines enumerateObjectsUsingBlock:^(NSString * _Nonnull string, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *temp = [string stringByAppendingString:@"\n"];
        NSAttributedString *as = [[NSAttributedString alloc] initWithString:temp attributes:idx == indexToBold ? boldAttributes : regularAttributes];
        [attributedString appendAttributedString:as];
    }];
    self.textField.attributedStringValue = attributedString;
    NSString *preview = [self.shellInstallerDelegate shellIntegrationInstallerNextCommandForSendShellCommands];
    NSArray<NSButton *> *buttons = self.previewCommandButtons;
    for (NSInteger i = 0; i < self.previewCommandButtons.count; i++){
        buttons[i].hidden = unavailable || (i != stage) || preview == nil;
        if (_busy && i == stage) {
            [buttons[i] setTitle:NSLocalizedStringWithDefaultValue(@"ui.shellintegrationinstaller.itermshellintegrationpasteshellcommandsviewcontroller.send_again.48a3e1af", nil, NSBundle.mainBundle, @"Send Again", @"User-facing text in iTermShellIntegrationPasteShellCommandsViewController (update).")];
        } else {
            [buttons[i] setTitle:NSLocalizedStringWithDefaultValue(@"ui.shellintegrationinstaller.itermshellintegrationpasteshellcommandsviewcontroller.preview_command.7ba90cea", nil, NSBundle.mainBundle, @"Preview Command", @"User-facing text in iTermShellIntegrationPasteShellCommandsViewController (update).")];
        }
    }
    self.previewTextView.string = preview ?: @"";
}

- (NSArray<NSButton *> *)previewCommandButtons {
    return @[ self.previewCommandButton1, self.previewCommandButton2, self.previewCommandButton3, self.previewCommandButton4 ];
}

- (NSButton *)previewCommandButton {
    NSArray<NSButton *> *buttons = self.previewCommandButtons;
    if (self.stage < 0 || self.stage >= buttons.count) {
        return nil;
    }
    return buttons[self.stage];
}

- (IBAction)previewCommand:(id)sender {
    if (_busy) {
        [self.shellInstallerDelegate shellIntegrationInstallerCancelExpectations];
        [self.shellInstallerDelegate shellIntegrationInstallerSendShellCommands:_stage];
        return;
    }
    self.popover.behavior = NSPopoverBehaviorTransient;
    [self.popoverViewController view];
    self.previewTextView.font = [NSFont fontWithName:@"Menlo" size:12];
    [self.popover showRelativeToRect:self.previewCommandButton.bounds
                              ofView:self.previewCommandButton
                       preferredEdge:NSRectEdgeMaxY];
}

- (IBAction)skip:(id)sender {
    [self.shellInstallerDelegate shellIntegrationInstallerSkipStage];
}

- (IBAction)next:(id)sender {
    [self.shellInstallerDelegate shellIntegrationInstallerSendShellCommands:_stage];
}

- (IBAction)back:(id)sender {
    [self.shellInstallerDelegate shellIntegrationInstallerCancelExpectations];
    if (_stage == 0) {
        [self.shellInstallerDelegate shellIntegrationInstallerBack];
    } else {
        self.stage = self.stage - 1;
    }
}

- (void)setBusy:(BOOL)busy {
    _busy = busy;
    [self update];
}

@end

