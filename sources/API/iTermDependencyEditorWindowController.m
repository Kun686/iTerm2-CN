//
//  iTermDependencyEditorWindowController.m
//  iTerm2
//
//  Created by George Nachman on 1/12/19.
//

#import "iTermDependencyEditorWindowController.h"

#import "iTerm2SharedARC-Swift.h"
#import "DebugLogging.h"
#import "iTermAdvancedSettingsModel.h"
#import "iTermAPIScriptLauncher.h"
#import "iTermApplicationDelegate.h"
#import "iTermController.h"
#import "iTermPythonRuntimeDownloader.h"
#import "iTermScriptsMenuController.h"
#import "iTermSetupCfgParser.h"
#import "iTermTuple.h"
#import "iTermWarning.h"
#import "NSArray+iTerm.h"
#import "NSFileManager+iTerm.h"
#import "NSStringITerm.h"
#import "NSTextField+iTerm.h"

#import <Sparkle/Sparkle.h>

@interface iTermDependencyEditorWindowController ()<NSTableViewDataSource, NSTableViewDelegate>

@end

@implementation iTermDependencyEditorWindowController {
    IBOutlet NSPopUpButton *_scriptsButton;
    IBOutlet NSPopUpButton *_pythonVersionButton;
    IBOutlet NSTableView *_tableView;
    IBOutlet NSButton *_checkForUpdate;
    IBOutlet NSButton *_remove;
    IBOutlet NSView *_mainView;
    IBOutlet NSView *_upgradeContainer;
    NSMutableArray<iTermScriptItem *> *_scriptItems;
    NSArray<iTermTuple<NSString *, NSString *> *> *_packageTuples;
    iTermScriptItem *_selectedScriptItem;
    NSString *_pythonVersion;
    // Set while a uv .venv rebuild (Python version change) is in flight. The rebuild can
    // take minutes and its dependency list is a snapshot taken at click time, so any edit
    // made meanwhile would be installed into the soon-discarded venv and then erased when
    // setup.cfg is rewritten from the snapshot. Guard the mutating actions on it.
    BOOL _rebuildInProgress;
}

// Enable/disable the editing controls during a rebuild. The Add button has no outlet, so
// the mutating actions also early-return on _rebuildInProgress as the real guard.
- (void)setEditingControlsEnabled:(BOOL)enabled {
    _scriptsButton.enabled = enabled;
    _pythonVersionButton.enabled = enabled;
    _tableView.enabled = enabled;
    _remove.enabled = enabled;
    _checkForUpdate.enabled = enabled;
}

+ (instancetype)sharedInstance {
    if (![[NSFileManager defaultManager] homeDirectoryDotDir]) {
        return nil;
    }
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithWindowNibName:@"iTermDependencyEditorWindowController"];
    });
    return instance;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self reload];
}

- (void)open {
    if (self.windowLoaded) {
        iTermScriptItem *selectedItem = _selectedScriptItem;
        [self reload];
        NSInteger index = [_scriptItems indexOfObject:selectedItem];
        if (index != NSNotFound) {
            [_scriptsButton selectItemAtIndex:index];
            [self didSelectScriptAtIndex:index];
        }
    }
    [self.window makeKeyAndOrderFront:nil];
}

#pragma mark - Private

- (void)reload {
    [self populateScripts];
    if (_scriptItems.count) {
        [self didSelectScriptAtIndex:0];
    }
}

- (BOOL)selectedScriptIsUv {
    return [iTermScriptRuntime backendForScriptContainer:_selectedScriptItem.path] == iTermScriptRuntimeBackendUv;
}

- (void)fetchVersionOfPackage:(NSString *)packageName completion:(void (^)(BOOL ok, NSString *result))completion {
    // `pip show` (and uv's, which is strict) wants a bare package name, but a dependency
    // may be a full requirement like "aiohttp>=3.14.3". Pass just the name.
    NSString *baseName = [packageName pythonPackage] ?: packageName;
    void (^handle)(BOOL, NSData *) = ^(BOOL ok, NSData *output) {
        if (!ok) {
            completion(NO, [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding]);
        } else {
            completion(YES, [self versionInPipOutput:output]);
        }
    };
    if ([self selectedScriptIsUv]) {
        [[iTermUvProvisioner shared] runUvPipWithPipArguments:@[ @"show", baseName ]
                                                   venvPython:[iTermScriptRuntime uvInterpreterPathForScriptContainer:_selectedScriptItem.path]
                                                   completion:handle];
        return;
    }
    NSURL *container = [NSURL fileURLWithPath:_selectedScriptItem.path];
    [[iTermPythonRuntimeDownloader sharedInstance] runPip3InContainer:container
                                                        pythonVersion:_pythonVersion
                                                        withArguments:@[ @"show", baseName ]
                                                           completion:handle];
}

- (void)loadPackageAtIndex:(NSInteger)index {
    [self loadPackageAtIndex:index completion:nil];
}

- (void)loadPackageAtIndex:(NSInteger)index completion:(void (^)(BOOL ok, NSString *result))completion {
    NSURL *container = [NSURL fileURLWithPath:_selectedScriptItem.path];
    iTermTuple<NSString *, NSString *> *tuple = _packageTuples[index];
    __weak __typeof(self) weakSelf = self;
    [self fetchVersionOfPackage:tuple.firstObject completion:^(BOOL ok, NSString *result) {
        const BOOL accepted = [weakSelf didFetchVersionOfPackageAtIndex:index originalTuple:tuple container:container ok:ok result:result];
        if (accepted && completion) {
            completion(ok, result);
        }
    }];
}

- (BOOL)didFetchVersionOfPackageAtIndex:(NSInteger)index
                          originalTuple:(iTermTuple *)tuple
                              container:(NSURL *)container
                                     ok:(BOOL)ok
                                 result:(NSString *)result {
    if (index < 0 || index >= _packageTuples.count) {
        return NO;
    }
    if (_packageTuples[index] != tuple) {
        return NO;
    }
    if (!ok) {
        tuple.secondObject = @"[Error]";
        RLog(@"Error running pip3 show %@ in %@: %@",
             tuple.firstObject,
             container.path,
             result);
    } else {
        tuple.secondObject = result;
    }
    [self->_tableView beginUpdates];
    [self->_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:index]
                                columnIndexes:[NSIndexSet indexSetWithIndex:1]];  // Index 1 is version
    [self->_tableView endUpdates];
    return YES;
}

- (NSString *)versionInPipOutput:(NSData *)output {
    NSString *string = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    NSArray<NSString *> *lines = [string componentsSeparatedByString:@"\n"];
    NSString *const versionPrefix = @"Version: ";
    NSString *versionLine = [lines filteredArrayUsingBlock:^BOOL(NSString *aLine) {
        return [aLine hasPrefix:versionPrefix];
    }].firstObject;
    return [versionLine substringFromIndex:versionPrefix.length];
}

- (void)didSelectScriptAtIndex:(NSInteger)index {
    _checkForUpdate.enabled = NO;
    _remove.enabled = NO;
    _selectedScriptItem = _scriptItems[index];

    const BOOL fullEnvironment = _selectedScriptItem.fullEnvironment;
    _mainView.hidden = !fullEnvironment;
    _upgradeContainer.hidden = fullEnvironment;
    if (!fullEnvironment) {
        return;
    }

    iTermSetupCfgParser *parser = [[iTermSetupCfgParser alloc] initWithPath:[_selectedScriptItem.path stringByAppendingPathComponent:@"setup.cfg"]];
    _packageTuples = [[parser.dependencies mapWithBlock:^id(NSString *dep) {
        iTermTuple *tuple = [iTermTuple tupleWithObject:dep andObject:@""];
        return tuple;
    }] sortedArrayUsingComparator:^NSComparisonResult(iTermTuple * _Nonnull tuple1, iTermTuple * _Nonnull tuple2) {
        return [tuple1.firstObject compare:tuple2.firstObject];
    }];
    [self loadPythonVersionsSelecting:parser.pythonVersion.it_twoPartVersionNumber];
    for (NSInteger i = 0; i < _packageTuples.count; i++) {
        [self loadPackageAtIndex:i];
    }
    [_tableView reloadData];
}

- (void)loadPythonVersionsSelecting:(NSString *)selectedVersion {
    if ([self selectedScriptIsUv]) {
        // Offer exactly what the INSTALLED uv can provide (uv python list), so the list
        // never claims a version the current uv cannot install. The current version is
        // shown immediately; the full list fills in asynchronously (it spawns uv).
        NSString *current = [iTermScriptRuntime pythonVersionForScriptContainer:_selectedScriptItem.path] ?: selectedVersion ?: @"";
        _pythonVersion = current;
        [_pythonVersionButton.menu removeAllItems];
        if (current.length) {
            [_pythonVersionButton addItemWithTitle:current];
            _pythonVersionButton.title = current;
        }
        NSString *container = _selectedScriptItem.path;
        __weak __typeof(self) weakSelf = self;
        [[iTermUvProvisioner shared] availableMinorsWithCompletion:^(NSArray<NSString *> *minors) {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf->_selectedScriptItem.path != container) {
                return;  // the user switched scripts while uv was queried
            }
            NSMutableArray<NSString *> *versions = [minors mutableCopy];
            if (current.length && ![versions containsObject:current]) {
                [versions addObject:current];
            }
            [versions sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
                return [a compare:b options:NSNumericSearch];
            }];
            [strongSelf->_pythonVersionButton.menu removeAllItems];
            for (NSString *version in versions) {
                [strongSelf->_pythonVersionButton addItemWithTitle:version];
            }
            strongSelf->_pythonVersionButton.title = strongSelf->_pythonVersion;
            const NSInteger idx = [versions indexOfObject:strongSelf->_pythonVersion];
            if (idx != NSNotFound) {
                [strongSelf->_pythonVersionButton selectItemAtIndex:idx];
            }
        }];
        return;
    }
    NSString *const env = [[_selectedScriptItem.path stringByAppendingPathComponent:@"iterm2env"] stringByAppendingPathComponent:@"versions"];
    _pythonVersion = selectedVersion ?: [iTermPythonRuntimeDownloader bestPythonVersionAt:env];
    NSArray<NSString *> *versions = [[[[iTermPythonRuntimeDownloader pythonVersionsAt:env] mapWithBlock:^id(NSString *version) {
        return version.it_twoPartVersionNumber;
    }] sortedArrayUsingSelector:@selector(compare:)] uniq];
    [_pythonVersionButton.menu removeAllItems];
    for (NSString *version in versions) {
        [_pythonVersionButton addItemWithTitle:version];
    }
    _pythonVersionButton.title = _pythonVersion;
    [_pythonVersionButton selectItemAtIndex:[versions indexOfObject:_pythonVersion]];
}

- (void)populateScripts {
    _scriptItems = [NSMutableArray array];
    _checkForUpdate.enabled = NO;
    _remove.enabled = NO;
    [_scriptsButton.menu removeAllItems];
    iTermApplicationDelegate *itad = [iTermApplication.sharedApplication delegate];
    [self addScriptItems:[itad.scriptsMenuController scriptItems] breadcrumbs:@[]];
}

- (void)addScriptItems:(NSArray<iTermScriptItem *> *)scriptItems breadcrumbs:(NSArray<NSString *> *)breadcrumbs {
    for (iTermScriptItem *item in [scriptItems sortedArrayUsingComparator:^NSComparisonResult(iTermScriptItem * _Nonnull obj1, iTermScriptItem * _Nonnull obj2) {
        return [obj1.name compare:obj2.name];
    }]) {
        if (item.isFolder) {
            [self addScriptItems:item.children breadcrumbs:[breadcrumbs arrayByAddingObject:item.name]];
            continue;
        }
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:[[breadcrumbs arrayByAddingObject:item.name] componentsJoinedByString:@"/"]
                                                          action:nil
                                                   keyEquivalent:@""];
        menuItem.tag = _scriptItems.count;
        [_scriptsButton.menu addItem:menuItem];
        [_scriptItems addObject:item];
    }
}

- (void)pip3UpgradeDidFinish:(iTermTuple<NSString *, NSString *> *)tuple
                       index:(NSInteger)index
                  scriptPath:(NSString *)scriptPath {
    if (_packageTuples.count <= index) {
        return;
    }
    if (_packageTuples[index] == tuple) {
        [self loadPackageAtIndex:index completion:^(BOOL ok, NSString *result) {
            if (!ok) {
                return;
            }
            // Re-pin to the just-installed version using the bare name, so an already
            // versioned dependency does not become "aiohttp>=3.14.3>=3.14.3".
            NSString *baseName = [tuple.firstObject pythonPackage] ?: tuple.firstObject;
            [iTermDependencyEditorWindowController setDependency:[NSString stringWithFormat:@"%@>=%@", baseName, result]
                                                      scriptPath:scriptPath];
        }];
    }
}

- (void)pip3UninstallDidFinish:(iTermTuple<NSString *, NSString *> *)tuple
                         index:(NSInteger)index
            selectedScriptPath:(NSString *)selectedScriptPath {
    if (_packageTuples.count <= index) {
        return;
    }
    if (_packageTuples[index] != tuple) {
        return;
    }
    __weak __typeof(self) weakSelf = self;
    [self fetchVersionOfPackage:tuple.firstObject completion:^(BOOL ok, NSString *result) {
        [weakSelf uninstallDidFetchPackageVersionSuccessfully:ok
                                                      package:tuple.firstObject
                                           selectedScriptPath:selectedScriptPath];
    }];
}

- (void)uninstallDidFetchPackageVersionSuccessfully:(BOOL)ok
                                            package:(NSString *)package
                                 selectedScriptPath:(NSString *)selectedScriptPath {
    if (ok) {
        [self uninstallDidFailForPackage:package];
        return;
    }

    NSString *path = [selectedScriptPath stringByAppendingPathComponent:@"setup.cfg"];
    iTermSetupCfgParser *parser = [[iTermSetupCfgParser alloc] initWithPath:path];
    [iTermSetupCfgParser writeSetupCfgToFile:path
                                        name:parser.name
                                dependencies:[parser.dependencies arrayByRemovingObject:package]
                         ensureiTerm2Present:NO
                               pythonVersion:parser.pythonVersion
                          environmentVersion:parser.minimumEnvironmentVersion];

    [self didSelectScriptAtIndex:_scriptsButton.indexOfSelectedItem];
}

- (void)requestDependencyName:(void (^)(NSString *name))completion {
    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [textField setEditable:YES];
    [textField setSelectable:YES];

    iTermWarning *warning = [[iTermWarning alloc] init];
    warning.heading = NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.add_dependency.50f0a75f", nil, NSBundle.mainBundle, @"Add Dependency", @"User-facing text in iTermDependencyEditorWindowController (heading).");
    warning.title = NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.what_dependency_would_you_like_to_add.cc6af951", nil, NSBundle.mainBundle, @"What dependency would you like to add?", @"User-facing text in iTermDependencyEditorWindowController (title).");
    warning.actionLabels = @[ NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.ok.565339bc", nil, NSBundle.mainBundle, @"OK", @"User-facing action label in iTermDependencyEditorWindowController (actionLabels)."), NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.cancel.19766ed6", nil, NSBundle.mainBundle, @"Cancel", @"User-facing action label in iTermDependencyEditorWindowController (actionLabels).") ];
    warning.accessory = textField;
    warning.warningType = kiTermWarningTypePersistent;
    warning.window = self.window;
    warning.initialFirstResponder = textField;
    __weak __typeof(self) weakSelf = self;
    [warning runModalAsync:^(iTermWarningSelection selection, iTermWarning *warning) {
        if (selection == kiTermWarningSelection1) {
            completion(nil);
            return;
        }
        NSString *name = [textField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (name.length == 0) {
            [weakSelf requestDependencyName:completion];
        } else {
            completion(name);
        }
    }];
}

- (void)runPip3WithArguments:(NSArray<NSString *> *)arguments completion:(void (^)(void))completion {
    NSString *executable;
    NSArray<NSString *> *executableArguments;
    NSDictionary<NSString *, NSString *> *environment;
    if ([self selectedScriptIsUv]) {
        NSString *venvPython = [iTermScriptRuntime uvInterpreterPathForScriptContainer:_selectedScriptItem.path];
        executable = [iTermUvProvisioner uvBinaryPath];
        executableArguments = [iTermUvProvisioner uvPipArgumentsWithPipArguments:arguments venvPython:venvPython];
        environment = [iTermUvProvisioner provisionEnvironment];
    } else {
        executable = [[iTermPythonRuntimeDownloader sharedInstance] pip3At:[_selectedScriptItem.path stringByAppendingPathComponent:@"iterm2env"]
                                                             pythonVersion:_pythonVersion];
        executableArguments = arguments;
        environment = nil;
    }
    NSString *command =
    [[executable stringWithBackslashEscapedShellCharactersIncludingNewlines:YES]
     stringByAppendingFormat:@" %@", [[executableArguments mapWithBlock:^id(NSString *anObject) {
        return [anObject stringWithBackslashEscapedShellCharactersIncludingNewlines:YES];
    }] componentsJoinedByString:@" "]];
    iTermWarningSelection selection = [iTermWarning showWarningWithTitle:command
                                                                 actions:@[ NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.ok.565339bc", nil, NSBundle.mainBundle, @"OK", @"User-facing action label in iTermDependencyEditorWindowController (actions)."), NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.cancel.19766ed6", nil, NSBundle.mainBundle, @"Cancel", @"User-facing action label in iTermDependencyEditorWindowController (actions).") ]
                                                               accessory:nil
                                                              identifier:@"DependencyEditorPip3Confirmation"
                                                             silenceable:kiTermWarningTypePersistent
                                                                 heading:NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.run_this_command.fd55ac77", nil, NSBundle.mainBundle, @"Run this Command?", @"User-facing text in iTermDependencyEditorWindowController (heading).")
                                                                  window:self.window];
    if (selection == kiTermWarningSelection1) {
        return;
    }
    // Escape the path because it gets evaluated as a swifty string.
    [[iTermController sharedInstance] openSingleUseWindowWithCommand:executable
                                                           arguments:executableArguments
                                                              inject:nil
                                                         environment:environment
                                                                 pwd:nil
                                                             options:iTermSingleUseWindowOptionsCommandNotSwiftyString
                                                      didMakeSession:nil
                                                          completion:^{
                                                              completion();
                                                          }];
}

- (void)pip3InstallDidFinish:(NSString *)selectedScriptPath newDependencyName:(NSString *)newDependencyName {
    if (![selectedScriptPath isEqualToString:_selectedScriptItem.path]) {
        return;
    }
    __weak __typeof(self) weakSelf = self;
    [self fetchVersionOfPackage:newDependencyName completion:^(BOOL ok, NSString *result) {
        [weakSelf installDidFinishSuccessfully:ok selectedScriptPath:selectedScriptPath newDependencyName:newDependencyName];
    }];
}

- (void)uninstallDidFailForPackage:(NSString *)package {
    [iTermWarning showWarningWithTitle:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.uninstall_of_failed_check_the_pip_output_for.7cc43555", nil, NSBundle.mainBundle, @"Uninstall of %@ failed. Check the pip output for errors.", @"User-facing text in iTermDependencyEditorWindowController (showWarningWithTitle)."),package]
                               actions:@[ NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.ok.565339bc", nil, NSBundle.mainBundle, @"OK", @"User-facing action label in iTermDependencyEditorWindowController (actions).") ]
                             accessory:nil
                            identifier:@"DependencyEditorInstallationFailed"
                           silenceable:kiTermWarningTypePersistent
                               heading:NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.removal_failed.1bf55f77", nil, NSBundle.mainBundle, @"Removal Failed", @"User-facing text in iTermDependencyEditorWindowController (heading).")
                                window:self.window];
}

- (void)installDidFinishSuccessfully:(BOOL)ok
                  selectedScriptPath:(NSString *)selectedScriptPath
                   newDependencyName:(NSString *)newDependencyName {
    if (!ok) {
        [iTermWarning showWarningWithTitle:NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.check_the_pip_output_for_errors.5f954975", nil, NSBundle.mainBundle, @"Check the pip output for errors.", @"User-facing warning message.")
                                   actions:@[ NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.ok.565339bc", nil, NSBundle.mainBundle, @"OK", @"User-facing action label in iTermDependencyEditorWindowController (actions).") ]
                                 accessory:nil
                                identifier:@"DependencyEditorInstallationFailed"
                               silenceable:kiTermWarningTypePersistent
                                   heading:NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.installation_failed.faa69b07", nil, NSBundle.mainBundle, @"Installation Failed", @"User-facing text in iTermDependencyEditorWindowController (heading).")
                                    window:self.window];
        return;
    }
    if (![selectedScriptPath isEqualToString:_selectedScriptItem.path]) {
        return;
    }
    NSString *path = [selectedScriptPath stringByAppendingPathComponent:@"setup.cfg"];
    iTermSetupCfgParser *parser = [[iTermSetupCfgParser alloc] initWithPath:path];
    [iTermSetupCfgParser writeSetupCfgToFile:path
                                        name:parser.name
                                dependencies:[parser.dependencies arrayByAddingObject:newDependencyName]
                         ensureiTerm2Present:NO
                               pythonVersion:parser.pythonVersion
                          environmentVersion:parser.minimumEnvironmentVersion];
    [self didSelectScriptAtIndex:_scriptsButton.selectedTag];
}

+ (void)setDependency:(NSString *)dependency scriptPath:(NSString *)scriptPath {
    RLog(@"Set dependency %@ in %@", dependency, scriptPath);
    NSString *path = [scriptPath stringByAppendingPathComponent:@"setup.cfg"];
    iTermSetupCfgParser *parser = [[iTermSetupCfgParser alloc] initWithPath:path];
    [iTermSetupCfgParser writeSetupCfgToFile:path
                                        name:parser.name
                                dependencies:[parser.dependencies ?: @[] arrayBySettingPythonDependency:dependency]
                         ensureiTerm2Present:NO
                               pythonVersion:parser.pythonVersion
                          environmentVersion:parser.minimumEnvironmentVersion];
}

#pragma mark - Actions

- (IBAction)upgrade:(id)sender {
    if (_rebuildInProgress) {
        return;
    }
    if (!_selectedScriptItem) {
        return;
    }

    NSString *name = _selectedScriptItem.path.lastPathComponent.stringByDeletingPathExtension;
    NSURL *folder = [[[NSURL fileURLWithPath:_selectedScriptItem.path] URLByDeletingLastPathComponent] URLByAppendingPathComponent:name];
    if ([[NSFileManager defaultManager] fileExistsAtPath:folder.path]) {
        iTermWarning *warning = [[iTermWarning alloc] init];
        warning.title = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.can_t_upgrade_because_already_exists.3e553583", nil, NSBundle.mainBundle, @"Can’t upgrade because %@ already exists", @"User-facing text in iTermDependencyEditorWindowController (title)."), folder.path];
        warning.heading = NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.error.54a0e8c1", nil, NSBundle.mainBundle, @"Error", @"User-facing text in iTermDependencyEditorWindowController (heading).");
        warning.actionLabels = @[ NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.ok.565339bc", nil, NSBundle.mainBundle, @"OK", @"User-facing action label in iTermDependencyEditorWindowController (actionLabels).") ];
        warning.warningType = kiTermWarningTypePersistent;
        warning.window = self.window;
        [warning runModal];
        return;
    }

    iTermScriptItem *item = _selectedScriptItem;
    __weak __typeof(self) weakSelf = self;
    NSString *pythonVersion =
    [iTermAPIScriptLauncher inferredPythonVersionFromScriptAt:item.path];
    __block iTermProvisioningProgressWindowController *progress = nil;
    void (^upgradeCompletion)(NSError *) = ^(NSError *errorStatus) {
        [progress dismiss];
        progress = nil;
        if (errorStatus != nil) {
            if ([iTermUvProvisioner isCancelationError:errorStatus]) {
                // The user declined the download; do not report a failure.
                return;
            }
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.installation_failed.faa69b07", nil, NSBundle.mainBundle, @"Installation Failed", @"User-facing text in iTermDependencyEditorWindowController (source UI).");
            alert.informativeText = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.please_file_a_bug_report_at_https_iterm2.de0c0bb5", nil, NSBundle.mainBundle, @"Please file a bug report at https://iterm2.com/bugs. The following error occurred while upgrading a dependency: %@", @"User-facing text in iTermDependencyEditorWindowController (informativeText)."), errorStatus.localizedDescription];
            [alert runModal];
            return;
        }
        [weakSelf finishUpgradingScriptItem:item toFullEnvironmentAt:folder];
        // TODO: Rebuild menus
    };
    if ([iTermAdvancedSettingsModel pythonRuntimeUsesUV]) {
        // Converting a basic script to a full environment is a form of migration, so
        // honor the gate and build a uv .venv rather than a legacy iterm2env.
        progress = [[iTermProvisioningProgressWindowController alloc] init];
        // Show progress only once the download phase is done and the venv build starts,
        // so it does not float over the download confirmation and progress window.
        [[iTermUvProvisioner shared] downloadAndProvisionFullEnvironmentWithContainer:folder.path
                                                              requestedPythonVersion:pythonVersion ?: [iTermScriptRuntime defaultPythonVersion]
                                                                        dependencies:@[]
                                                                      createSetupCfg:YES
                                                                provisioningDidBegin:^{
            [progress showWithMessage:NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.setting_up_python_environment.32371e53", nil, NSBundle.mainBundle, @"Setting up the Python environment…", @"Progress message while setting up a script's Python environment.")];
        }
                                                                          completion:upgradeCompletion];
    } else {
        [[iTermPythonRuntimeDownloader sharedInstance] installPythonEnvironmentTo:folder
                                                                     dependencies:@[]
                                                                    pythonVersion:pythonVersion
                                                                       completion:upgradeCompletion];
    }
}

- (void)finishUpgradingScriptItem:(iTermScriptItem *)item
              toFullEnvironmentAt:(NSURL *)url {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // Create Scripts/Foo/Foo
    NSString *innerFolder = [url.path stringByAppendingPathComponent:url.path.lastPathComponent];
    NSError *error = nil;
    [fileManager createDirectoryAtPath:innerFolder
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:&error];
    if (error) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.installation_failed.faa69b07", nil, NSBundle.mainBundle, @"Installation Failed", @"User-facing text in iTermDependencyEditorWindowController (finishUpgradingScriptItem:toFullEnvironmentAt:).");
        alert.informativeText = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.error_creating.afb7612f", nil, NSBundle.mainBundle, @"Error creating %@: %@", @"User-facing text in iTermDependencyEditorWindowController (informativeText)."), innerFolder, error.localizedDescription];
        [alert runModal];
        return;
    }
    // Move Scripts/Foo.py to Scripts/Foo/Foo/Foo.py
    NSString *name = item.path.lastPathComponent;
    NSString *destination = [innerFolder stringByAppendingPathComponent:name];
    [fileManager moveItemAtPath:item.path
                         toPath:destination
                          error:&error];
    if (error) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.installation_failed.faa69b07", nil, NSBundle.mainBundle, @"Installation Failed", @"User-facing text in iTermDependencyEditorWindowController (finishUpgradingScriptItem:toFullEnvironmentAt:).");
        alert.informativeText = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.error_moving_to.e465d251", nil, NSBundle.mainBundle, @"Error moving %@ to %@: %@", @"User-facing text in iTermDependencyEditorWindowController (informativeText)."), item.path, destination, error.localizedDescription];
        [alert runModal];
        return;
    }

    [self populateScripts];
    NSInteger index = [_scriptItems indexOfObjectPassingTest:^BOOL(iTermScriptItem * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        return [item.path isEqual:url.path];
    }];
    if (index >= 0 && index < _scriptItems.count) {
        [_scriptsButton selectItemAtIndex:index];
        [self didSelectScriptAtIndex:index];
    }
}

- (IBAction)checkForUpdates:(id)sender {
    const NSInteger index = _tableView.selectedRow;
    if (index < 0 || !_selectedScriptItem) {
        return;
    }
    iTermScriptItem *selectedScriptItem = _selectedScriptItem;
    iTermTuple<NSString *, NSString *> *tuple = _packageTuples[_tableView.selectedRow];
    NSString *selectedDependencyName = tuple.firstObject;
    __weak __typeof(self) weakSelf = self;
    [self runPip3WithArguments:@[ @"install", selectedDependencyName, @"--upgrade" ] completion:^{
        [weakSelf pip3UpgradeDidFinish:tuple
                                 index:index
                            scriptPath:selectedScriptItem.path];
    }];
}

- (IBAction)add:(id)sender {
    if (_rebuildInProgress) {
        return;
    }
    iTermScriptItem *selectedScriptItem = _selectedScriptItem;
    if (!selectedScriptItem) {
        return;
    }
    __weak __typeof(self) weakSelf = self;
    [self requestDependencyName:^(NSString *newDependencyName) {
        if (!newDependencyName) {
            return;
        }
        [weakSelf install:newDependencyName selectedScriptPath:selectedScriptItem.path completion:nil];
    }];
}

- (void)install:(NSString *)newDependencyName selectedScriptPath:(NSString *)selectedScriptPath completion:(void (^)(void))completion {
    __weak __typeof(self) weakSelf = self;
    [self runPip3WithArguments:@[ @"install", newDependencyName ] completion:^{
        [weakSelf pip3InstallDidFinish:selectedScriptPath newDependencyName:newDependencyName];
        if (completion) {
            completion();
        }
    }];
}

- (IBAction)remove:(id)sender {
    if (_rebuildInProgress) {
        return;
    }
    const NSInteger index = _tableView.selectedRow;
    if (index < 0) {
        return;
    }
    iTermTuple<NSString *, NSString *> *tuple = _packageTuples[_tableView.selectedRow];
    NSString *selectedDependencyName = tuple.firstObject;
    iTermScriptItem *selectedScriptItem = _selectedScriptItem;
    __weak __typeof(self) weakSelf = self;
    [self runPip3WithArguments:@[ @"uninstall", selectedDependencyName ] completion:^{
        [weakSelf pip3UninstallDidFinish:tuple index:index selectedScriptPath:selectedScriptItem.path];
    }];
}

- (IBAction)scriptDidChange:(id)sender {
    [self didSelectScriptAtIndex:_scriptsButton.selectedTag];
}

- (IBAction)closeCurrentSession:(id)sender {
    [self close];
}

- (IBAction)dismissController:(id)sender {
    [self close];
}

- (IBAction)pythonVersionChanged:(id)sender {
    if (_rebuildInProgress) {
        return;
    }
    NSString *selectedVersion = [[_pythonVersionButton selectedItem] title];
    if ([selectedVersion isEqualToString:_pythonVersion]) {
        return;
    }
    SUStandardVersionComparator *comparator = [[SUStandardVersionComparator alloc] init];
    if ([comparator compareVersion:selectedVersion toVersion:_pythonVersion] == NSOrderedAscending) {
        iTermWarning *warning = [[iTermWarning alloc] init];
        warning.title = NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.you_have_asked_to_downgrade_to_an_older.c6e37fcf", nil, NSBundle.mainBundle, @"You have asked to downgrade to an older Python version. Dependencies will need to be reinstalled. This may go badly. Are you sure you want to do this?", @"User-facing text in iTermDependencyEditorWindowController (title).");
        warning.heading = NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.confirm_python_downgrade.ecad1e97", nil, NSBundle.mainBundle, @"Confirm Python Downgrade", @"User-facing text in iTermDependencyEditorWindowController (heading).");
        warning.actionLabels = @[ NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.ok.565339bc", nil, NSBundle.mainBundle, @"OK", @"User-facing action label in iTermDependencyEditorWindowController (actionLabels)."), NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.cancel.19766ed6", nil, NSBundle.mainBundle, @"Cancel", @"User-facing action label in iTermDependencyEditorWindowController (actionLabels).") ];
        warning.identifier = @"DependencyEditorConfirmDowngrade";
        warning.warningType = kiTermWarningTypePersistent;
        warning.window = self.window;

        const iTermWarningSelection selection = [warning runModal];
        if (selection == kiTermWarningSelection1) {
            [_pythonVersionButton selectItemWithTitle:_pythonVersion];
            return;
        }
    } else {
        iTermWarning *warning = [[iTermWarning alloc] init];
        warning.title = NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.you_have_asked_to_upgrade_to_a_newer.4b9defa8", nil, NSBundle.mainBundle, @"You have asked to upgrade to a newer Python version. Dependencies will need to be reinstalled. OK to continue?", @"User-facing text in iTermDependencyEditorWindowController (title).");
        warning.heading = NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.confirm_python_upgrade.d65a137b", nil, NSBundle.mainBundle, @"Confirm Python Upgrade", @"User-facing text in iTermDependencyEditorWindowController (heading).");
        warning.actionLabels = @[ NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.ok.565339bc", nil, NSBundle.mainBundle, @"OK", @"User-facing action label in iTermDependencyEditorWindowController (actionLabels)."), NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.cancel.19766ed6", nil, NSBundle.mainBundle, @"Cancel", @"User-facing action label in iTermDependencyEditorWindowController (actionLabels).") ];
        warning.identifier = @"DependencyEditorConfirmUpgrade";
        warning.warningType = kiTermWarningTypePersistent;
        warning.window = self.window;

        const iTermWarningSelection selection = [warning runModal];
        if (selection == kiTermWarningSelection1) {
            [_pythonVersionButton selectItemWithTitle:_pythonVersion];
            return;
        }
    }

    _pythonVersion = selectedVersion;
    NSString *path = [_selectedScriptItem.path stringByAppendingPathComponent:@"setup.cfg"];
    iTermSetupCfgParser *parser = [[iTermSetupCfgParser alloc] initWithPath:path];
    NSArray<NSString *> *dependencies = [parser.dependencies copy];
    if ([self selectedScriptIsUv]) {
        // For uv, `uv pip install` would keep the existing interpreter, so actually
        // rebuild the .venv at the new version. downloadAndProvisionFullEnvironment
        // rebuilds the venv, reinstalls the dependencies (and iterm2), and rewrites
        // setup.cfg with the new version.
        NSString *container = _selectedScriptItem.path;
        // Lock out edits while the rebuild runs: its `dependencies` is a click-time snapshot
        // and the venv is swapped atomically at the end, so a package added meanwhile would
        // install into the discarded venv and then be erased when setup.cfg is rewritten.
        _rebuildInProgress = YES;
        [self setEditingControlsEnabled:NO];
        __block iTermProvisioningProgressWindowController *progress = [[iTermProvisioningProgressWindowController alloc] init];
        __weak __typeof(self) weakSelf = self;
        [[iTermUvProvisioner shared] downloadAndProvisionFullEnvironmentWithContainer:container
                                                              requestedPythonVersion:selectedVersion
                                                                        dependencies:dependencies ?: @[]
                                                                      createSetupCfg:YES
                                                                provisioningDidBegin:^{
            [progress showWithMessage:NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.rebuilding_the_python_environment.44036a59", nil, NSBundle.mainBundle, @"Rebuilding the Python environment…", @"Progress message while rebuilding a script environment.")];
        }
                                                                          completion:^(NSError *error) {
            [progress dismiss];
            progress = nil;
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            strongSelf->_rebuildInProgress = NO;
            [strongSelf setEditingControlsEnabled:YES];
            if (error != nil && ![iTermUvProvisioner isCancelationError:error]) {
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.could_not_change_python_version.d53fe669", nil, NSBundle.mainBundle, @"Could Not Change Python Version", @"User-facing text in iTermDependencyEditorWindowController (source UI).");
                alert.informativeText = error.localizedDescription ?: NSLocalizedStringWithDefaultValue(@"ui.api.itermdependencyeditorwindowcontroller.unknown_error.27c2ccd9", nil, NSBundle.mainBundle, @"Unknown error", @"Fallback error description when rebuilding a script environment fails.");
                [alert runModal];
            }
            // Refresh the editor from the (rebuilt) environment and setup.cfg.
            [strongSelf didSelectScriptAtIndex:strongSelf->_scriptsButton.indexOfSelectedItem];
        }];
        return;
    }
    [iTermSetupCfgParser writeSetupCfgToFile:path
                                        name:parser.name
                                dependencies:@[]
                         ensureiTerm2Present:NO
                               pythonVersion:_pythonVersion
                          environmentVersion:parser.minimumEnvironmentVersion];
    [self installPackages:dependencies selectedScriptPath:_selectedScriptItem.path];
}

- (void)installPackages:(NSArray<NSString *> *)packages selectedScriptPath:(NSString *)selectedScriptPath {
    if (packages.count == 0) {
        return;
    }
    NSString *newDependencyName = packages.firstObject;
    [self install:newDependencyName selectedScriptPath:selectedScriptPath completion:^{
        [self installPackages:[packages subarrayFromIndex:1] selectedScriptPath:selectedScriptPath];
    }];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _packageTuples.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *const identifier = NSStringFromClass(self.class);
    NSTableCellView *view = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!view) {
        view = [[NSTableCellView alloc] init];

        NSTextField *textField = [NSTextField it_textFieldForTableViewWithIdentifier:identifier];
        textField.font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
        view.textField = textField;
        [view addSubview:textField];
        textField.frame = view.bounds;
        textField.autoresizingMask = (NSViewWidthSizable | NSViewHeightSizable);
    }
    if ([tableColumn.identifier isEqualToString:@"package"]) {
        view.textField.stringValue = _packageTuples[row].firstObject;
    } else {
        view.textField.stringValue = _packageTuples[row].secondObject;
    }
    return view;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    const BOOL haveSelection = _tableView.selectedRow >= 0;
    _checkForUpdate.enabled = haveSelection;
    _remove.enabled = haveSelection;
}

@end
