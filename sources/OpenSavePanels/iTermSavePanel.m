//
//  iTermSavePanel.m
//  iTerm2
//
//  Created by George Nachman on 7/9/15.
//
//

#import "DebugLogging.h"
#import "NSArray+iTerm.h"
#import "NSFileManager+iTerm.h"
#import "NSObject+iTerm.h"
#import "NSStringITerm.h"
#import "iTerm2SharedARC-Swift.h"
#import "iTermSavePanel.h"
#import "iTermSavePanelFileFormatAccessory.h"
#import "iTermUserDefaults.h"
#import "iTermWarning.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSString *const kInitialDirectoryKey = @"Initial Directory";
static NSString *const iTermSavePanelLoggingStyleUserDefaultsKey = @"NoSyncLoggingStyle";

@interface iTermSavePanel () <iTermModernSavePanelDelegate>
@property(nonatomic, copy) NSString *filename;  // Just the filename.
@property(nonatomic, strong, readwrite) iTermSavePanelItem *item;
@property(nonatomic, assign) iTermSavePanelReplaceOrAppend replaceOrAppend;
@property(nonatomic, copy) NSString *requiredExtension;
@property(nonatomic, copy) NSString *forcedExtension;
@property(nonatomic, strong) NSPopUpButton *accessoryButton;
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, strong) iTermModernSavePanel *savePanel;
@property(nonatomic, strong) NSViewController *accessoryViewController;
@end

@implementation iTermSavePanel {
    NSInteger _options;
}

+ (NSString *)keyForIdentifier:(NSString *)identifier {
    return [NSString stringWithFormat:@"NoSyncSavePanelSavedSettings_%@", identifier];
}

+ (NSString *)nameForFileType:(NSString *)extension {
    UTType *type = [UTType typeWithFilenameExtension:extension];
    NSString *description = type.localizedDescription ?: extension;
    NSString *capitalized = [description stringByCapitalizingFirstLetter];
    NSString *pattern = [NSString stringWithFormat:@"(%@)", extension];
    NSRange range = [capitalized rangeOfString:pattern];
    if (range.location != NSNotFound) {
        return [capitalized stringByReplacingCharactersInRange:range
                                                  withString:extension.uppercaseString];
    }
    return capitalized;
}

+ (iTermSavePanelFileFormatAccessory *)newFileFormatAccessoryViewControllerFileWithFileTypes:(NSArray<NSString *> *)fileTypes
                                                                                     options:(iTermSavePanelOptions)options {
    iTermSavePanelFileFormatAccessory *accessory = [[iTermSavePanelFileFormatAccessory alloc] initWithNibName:@"iTermSavePanelFileFormatAccessory" bundle:[NSBundle bundleForClass:self]];
    accessory.showFileFormat = !!(options & kSavePanelOptionFileFormatAccessory);
    accessory.showTimestamps = !!(options & kSavePanelOptionIncludeTimestampsAccessory);
    [accessory view];
    NSInteger i = 0;
    for (NSString *fileType in fileTypes) {
        NSString *name = [self nameForFileType:fileType];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:name action:@selector(popupButtonDidChange:) keyEquivalent:@""];
        item.target = accessory;
        item.tag = i++;
        [accessory.popupButton.menu addItem:item];
    }
    return accessory;
}

+ (iTermModernSavePanel *)newSavePanelWithOptions:(iTermSavePanelOptions)options
                                       identifier:(NSString *)identifier
                                 initialDirectory:(NSString *)initialDirectory
                                  defaultFilename:(NSString *)defaultFilename
                                 allowedFileTypes:(NSArray<NSString *> *)allowedFileTypes
                                         delegate:(iTermSavePanel *)delegate {
    NSString *key = [self keyForIdentifier:identifier];
    NSDictionary *savedSettings = [[iTermUserDefaults userDefaults] objectForKey:key];
    if (savedSettings) {
        initialDirectory = savedSettings[kInitialDirectoryKey] ?: initialDirectory;
    }

    iTermModernSavePanel *savePanel = [[iTermModernSavePanel alloc] init];
    if (initialDirectory) {
        savePanel.directoryURL = [NSURL fileURLWithPath:initialDirectory];
    }
    savePanel.nameFieldStringValue = defaultFilename;
    if (allowedFileTypes) {
        savePanel.extensionHidden = NO;
        savePanel.allowedContentTypes = [allowedFileTypes mapWithBlock:^id _Nullable(NSString *ext) {
            return [UTType typeWithFilenameExtension:ext];
        }];
    }
    if (options & kSavePanelOptionDefaultToLocalhost) {
        savePanel.preferredSSHIdentity = [SSHIdentity localhost];
    }
    iTermSavePanelFileFormatAccessory *accessoryViewController = nil;
    NSPopUpButton *button = nil;
    if (options & (kSavePanelOptionFileFormatAccessory | kSavePanelOptionIncludeTimestampsAccessory)) {
        accessoryViewController = [self newFileFormatAccessoryViewControllerFileWithFileTypes:allowedFileTypes
                                                                                      options:options];
        delegate.accessoryViewController = accessoryViewController;
        savePanel.accessoryView = accessoryViewController.view;
    } else if (options & kSavePanelOptionLogPlainTextAccessory) {
        button = [[NSPopUpButton alloc] init];
        NSMenuItem *item;
        {
            item = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.raw_data.84428a7a", nil, NSBundle.mainBundle, @"Raw data", @"User-facing text in iTermSavePanel (newSavePanelWithOptions:identifier:initialDirectory:defaultFilename:allowedFileTypes:delegate:).") action:nil keyEquivalent:@""];
            item.tag = iTermLoggingStyleRaw;
            [button.menu addItem:item];
        }
        {
            item = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.plain_text.cf416625", nil, NSBundle.mainBundle, @"Plain text", @"User-facing text in iTermSavePanel (newSavePanelWithOptions:identifier:initialDirectory:defaultFilename:allowedFileTypes:delegate:).") action:nil keyEquivalent:@""];
            item.tag = iTermLoggingStylePlainText;
            [button.menu addItem:item];
        }
        {
            item = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.html.07239dbd", nil, NSBundle.mainBundle, @"HTML", @"User-facing text in iTermSavePanel (newSavePanelWithOptions:identifier:initialDirectory:defaultFilename:allowedFileTypes:delegate:).") action:nil keyEquivalent:@""];
            item.tag = iTermLoggingStyleHTML;
            [button.menu addItem:item];
        }
        {
            item = [[NSMenuItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.asciinema.9e677fc0", nil, NSBundle.mainBundle, @"ASCIInema", @"User-facing text in iTermSavePanel (newSavePanelWithOptions:identifier:initialDirectory:defaultFilename:allowedFileTypes:delegate:).") action:nil keyEquivalent:@""];
            item.tag = iTermLoggingStyleAsciicast;
            [button.menu addItem:item];
        }

        [button selectItemWithTag:[[iTermUserDefaults userDefaults] integerForKey:iTermSavePanelLoggingStyleUserDefaultsKey]];
        [button sizeToFit];

        NSView *container = [[NSView alloc] init];
        NSRect rect = button.frame;
        rect.size.height += 12;
        container.frame = rect;
        [container addSubview:button];

        rect = button.frame;
        rect.origin.y += 6;
        button.frame = rect;
        savePanel.accessoryView = container;
        delegate.accessoryButton = button;
    }
    accessoryViewController.onChange = ^(NSInteger i){
        [delegate setRequiredExtension:allowedFileTypes[i]];
    };
    if (options & kSavePanelOptionFileFormatAccessory) {
        delegate.requiredExtension = allowedFileTypes[0];
    }
    if (options & kSavePanelOptionLocalhostOnly) {
        savePanel.requireLocalhost = YES;
    }
    savePanel.delegate = delegate;
    delegate.savePanel = savePanel;
    return savePanel;
}

+ (void)asyncShowWithOptions:(iTermSavePanelOptions)options
                  identifier:(NSString *)identifier
            initialDirectory:(NSString *)initialDirectory
             defaultFilename:(NSString *)defaultFilename
            allowedFileTypes:(NSArray<NSString *> *)allowedFileTypes
                      window:(NSWindow *)window
                  completion:(void (^)(iTermModernSavePanel *panel, iTermSavePanel *savePanel))completion {
    iTermSavePanel *delegate = [[iTermSavePanel alloc] initWithOptions:options];
    delegate.identifier = identifier;
    iTermModernSavePanel *savePanel = [self newSavePanelWithOptions:options
                                                         identifier:identifier
                                                   initialDirectory:initialDirectory
                                                    defaultFilename:defaultFilename
                                                   allowedFileTypes:allowedFileTypes
                                                           delegate:delegate];
    [delegate presentSavePanel:savePanel options:options window:window completion:completion];
}

- (void)presentSavePanel:(iTermModernSavePanel *)savePanel
                 options:(NSInteger)options
                  window:(NSWindow *)window
              completion:(void (^)(iTermModernSavePanel *panel, iTermSavePanel *savePanel))completion {
    [savePanel beginWithFallbackWindow:window handler:^(NSModalResponse response, iTermSavePanelItem *item) {
        [self savePanelDidCompleteWithResponse:response
                                       options:options
                                     savePanel:savePanel
                                    completion:^(iTermModernSavePanel *panel, iTermSavePanel *savePanel, BOOL retry) {
            if (retry) {
                [self presentSavePanel:panel options:options window:window completion:completion];
            } else {
                completion(panel, savePanel);
            }
        }];
    }];
}

- (void)savePanelDidCompleteWithResponse:(NSModalResponse)response
                                 options:(NSInteger)options
                               savePanel:(iTermModernSavePanel *)savePanel
                              completion:(void (^)(iTermModernSavePanel *panel, iTermSavePanel *savePanel, BOOL))completion {
    if (response != NSModalResponseOK) {
        completion(nil, self, NO);
        return;
    }
    [iTermSavePanel handleResponseFromSavePanel:savePanel
                                       delegate:self
                                        options:options
                                     completion:^(iTermSavePanelAction action) {
        switch (action) {
            case iTermSavePanelActionAbort:
                completion(nil, self, NO);
            case iTermSavePanelActionRetry:
                completion(nil, nil, YES);
            case iTermSavePanelActionAccept:
                completion([self accept:savePanel], self, NO);
        }
    }];
}

- (iTermModernSavePanel *)accept:(iTermModernSavePanel *)savePanel {
    if (savePanel.item) {
        NSString *key = [iTermSavePanel keyForIdentifier:self.identifier];
        NSDictionary *settings =
            @{ kInitialDirectoryKey: [savePanel.item.filename stringByDeletingLastPathComponent] };
        [[iTermUserDefaults userDefaults] setObject:settings forKey:key];
    }
    if (self) {
        self->_loggingStyle = (iTermLoggingStyle)self.accessoryButton.selectedTag;
    }
    if (self.item) {
        [[iTermUserDefaults userDefaults] setInteger:self.accessoryButton.selectedTag
                                                   forKey:iTermSavePanelLoggingStyleUserDefaultsKey];
    }

    return savePanel.item ? savePanel : nil;
}

typedef NS_ENUM(NSUInteger, iTermSavePanelAction) {
    iTermSavePanelActionAccept,
    iTermSavePanelActionRetry,
    iTermSavePanelActionAbort
};

+ (void)handleResponseFromSavePanel:(iTermModernSavePanel *)savePanel
                           delegate:(iTermSavePanel *)delegate
                            options:(NSInteger)options
                         completion:(void (^)(iTermSavePanelAction action))completion {
    iTermSavePanelItem *item = savePanel.item;
    NSArray<NSString *> *allowedFileTypes = [savePanel.allowedContentTypes mapWithBlock:^id _Nullable(UTType *uttype) {
        return uttype.preferredFilenameExtension;
    }];
    if (options & kSavePanelOptionAppendOrReplace) {
        if (!delegate.filename) {
            // Something went wrong.
            RLog(@"Save panel's delegate has no filename!");
            completion(iTermSavePanelActionAbort);
            return;
        }

        // The path contains random crap in the last path component. Use what we saved instead.
        [item setLastPathComponent:delegate.filename];
        if (allowedFileTypes.count && ![allowedFileTypes containsObject:delegate.item.pathExtension]) {
            [item setPathExtension:allowedFileTypes.firstObject];
        }

        // Show the replace/append/cancel panel.
        [delegate setItem:savePanel.item];
        [delegate checkForExistingFile:^(BOOL retry) {
            completion(retry ? iTermSavePanelActionRetry : iTermSavePanelActionAccept);
        }];
        return;
    }
    if (delegate.forcedExtension) {
        [item setPathExtension:delegate.forcedExtension];
    } else if (allowedFileTypes.count && ![allowedFileTypes containsObject:delegate.item.pathExtension]) {
        [item setPathExtension:allowedFileTypes.firstObject];
    }
    delegate.item = item;
    completion(iTermSavePanelActionAccept);
}

+ (NSInteger)runModal:(NSSavePanel *)savePanel inWindow:(NSWindow *)window {
    __block NSInteger response;
    if (window) {
        __block BOOL done = NO;
        [savePanel beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
            response = result;
            done = YES;
        }];
        while (!done) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
    } else {
        response = [savePanel runModal];
    }
    return response;
}

- (instancetype)initWithOptions:(NSInteger)options {
    self = [super init];
    if (self) {
        _options = options;
    }
    return self;
}

#pragma mark - Private

// Returns YES if the save panel should be shown again because the user canceled.
- (void)checkForExistingFile:(void (^)(BOOL retry))completion {
    __weak __typeof(self) weakSelf = self;
    [self.item exists:^(BOOL exists) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!exists) {
                completion(NO);
                return;
            }
            [weakSelf didCheckForExistingFile:exists withCompletion:completion];
        });
    }];
}

- (void)didCheckForExistingFile:(BOOL)exists withCompletion:(void (^)(BOOL retry))completion {
    NSString *location = @"";
    NSString *directory = [self.item.filename stringByDeletingLastPathComponent];
    if ([directory isEqualToString:self.item.host.homeDirectory]) {
        location = NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.in_your_home_directory.a92b8a98", nil, NSBundle.mainBundle, @" in your home directory", @"User-facing phrase fragment in iTermSavePanel.");
    } else if (self.item.host.isLocalhost && [directory isEqualToString:[[NSFileManager defaultManager] desktopDirectory]]) {
        location = NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.on_the_desktop.870a3625", nil, NSBundle.mainBundle, @" on the Desktop", @"User-facing phrase fragment in iTermSavePanel.");
    }

    NSString *heading =
    [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.already_exists_do_you_want_to_replace_it_or_append_to_it.7fa3fd32", nil, NSBundle.mainBundle, @"“%@” already exists. Do you want to replace it or append to it?", @"User-facing text in iTermSavePanel (indirect UI)."),
     [self.item.filename lastPathComponent]];
    NSString *body = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.a_file_or_folder_with_the_same_name_already_exists_replacing_it_will_ove.4f462535", nil, NSBundle.mainBundle, @"A file or folder with the same name already exists%@. Replacing it will overwrite its current contents.", @"User-facing text in iTermSavePanel (indirect UI)."),
                      location];
    iTermWarningSelection selection = [iTermWarning showWarningWithTitle:body
                                                                 actions:@[ NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.cancel.19766ed6", nil, NSBundle.mainBundle, @"Cancel", @"User-facing action label in iTermSavePanel (actions)."), NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.replace.95e15439", nil, NSBundle.mainBundle, @"Replace", @"User-facing action label in iTermSavePanel (actions)."), NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.append.fc15cc0a", nil, NSBundle.mainBundle, @"Append", @"User-facing action label in iTermSavePanel (actions).") ]
                                                               accessory:nil
                                                              identifier:nil
                                                             silenceable:kiTermWarningTypePersistent
                                                                 heading:heading
                                                                  window:nil];
    switch (selection) {
        case kiTermWarningSelection0:
            self.replaceOrAppend = kSavePanelReplaceOrAppendSelectionNotApplicable;
            completion(YES);
            return;

        case kiTermWarningSelection1:
            self.replaceOrAppend = kSavePanelReplaceOrAppendSelectionReplace;
            break;

        case kiTermWarningSelection2:
            self.replaceOrAppend = kSavePanelReplaceOrAppendSelectionAppend;
            break;

        default:
            assert(false);
    }
    completion(NO);
}

#pragma mark - iTermModernSavePanelDelegate

- (NSString *)panel:(id)sender userEnteredFilename:(NSString*)filename confirmed:(BOOL)okFlag {
    if (_options & kSavePanelOptionAppendOrReplace) {
        if (!okFlag) {
            // User is just typing.
            return filename;
        }
        // User pressed ok.

        // Save the file the user entered. He could've typed slashes, which the system would
        // turn into colons normally.
        self.filename = [filename stringByReplacingOccurrencesOfString:@"/" withString:@":"];

        // Return a filename that definitely doesn't exist to avoid the Replace panel.
        return [NSString uuid];
    } else {
        // Default behavior.
        return filename;
    }
}

- (void)panel:(iTermModernSavePanel * _Nonnull)sender didChangeToDirectory:(iTermSavePanelItem * _Nullable)didChangeToDirectory { 
}

- (BOOL)panel:(iTermModernSavePanel * _Nonnull)sender shouldEnable:(iTermSavePanelItem * _Nonnull)item { 
    return YES;
}

- (BOOL)panel:(iTermModernSavePanel *)sender
     validate:(iTermSavePanelItem *)item
        error:(NSError **)error {
    NSString *proposedExtension = item.filename.pathExtension;
    self.forcedExtension = nil;
    if (!proposedExtension.length) {
        return YES;
    }
    if (!self.requiredExtension) {
        return YES;
    }
    if ([proposedExtension isEqualToString:self.requiredExtension]) {
        return YES;
    }
    iTermWarningSelection selection = [iTermWarning showWarningWithTitle:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.you_can_choose_to_use_both_so_that.a1ff1265", nil, NSBundle.mainBundle, @"You can choose to use both, so that your file name ends in “.%@.%@”.", @"User-facing text in iTermSavePanel (showWarningWithTitle)."), proposedExtension, _requiredExtension]
                                                                 actions:@[ [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.use.30232327", nil, NSBundle.mainBundle, @"Use .%@", @"User-facing action label in iTermSavePanel (actions)."), _requiredExtension],
                                                                            NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.cancel.19766ed6", nil, NSBundle.mainBundle, @"Cancel", @"User-facing action label in iTermSavePanel (actions)."),
                                                                            NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.use_both.81f7c50a", nil, NSBundle.mainBundle, @"Use both", @"User-facing action label in iTermSavePanel (actions).") ]
                                                               accessory:nil
                                                              identifier:nil
                                                             silenceable:kiTermWarningTypePersistent
                                                                 heading:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.opensavepanels.itermsavepanel.you_cannot_save_this_document_with_extension_at.15ca49d8", nil, NSBundle.mainBundle, @"You cannot save this document with extension “.%@” at the end of the name. The required extension is “.%@”.", @"User-facing text in iTermSavePanel (heading)."),
                                                                          proposedExtension, _requiredExtension]
                                                                  window:nil];
    switch (selection) {
        case kiTermWarningSelection0:
            self.forcedExtension = self.requiredExtension;
            return YES;

        case kiTermWarningSelection1:
            return NO;

        case kiTermWarningSelection2:
            self.forcedExtension = [NSString stringWithFormat:@"%@.%@", proposedExtension, _requiredExtension];
            return YES;

        default:
            break;
    }
    return NO;
}

- (BOOL)timestamps {
    iTermSavePanelFileFormatAccessory *accessoryViewController = [iTermSavePanelFileFormatAccessory castFrom:self.accessoryViewController];
    return accessoryViewController.timestampsEnabled;
}

@end
