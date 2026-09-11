//
//  iTermLaunchServices.m
//  iTerm
//
//  Created by George Nachman on 4/14/14.
//
//

#import "iTermLaunchServices.h"

#import "DebugLogging.h"
#import "ITAddressBookMgr.h"
#import "NSWorkspace+iTerm.h"
#import "iTermUserDefaults.h"

static NSString *const kUrlHandlersUserDefaultsKey = @"URLHandlersByGuid";
static NSString *const kOldStyleUrlHandlersUserDefaultsKey = @"URLHandlers";

@interface iTermLaunchServices()<NSOpenSavePanelDelegate>
@end

@implementation iTermLaunchServices {
    NSMutableDictionary *_urlHandlersByGuid;  // NSString scheme -> NSString guid
    NSURL *_currentFileUrlForOpenPanel;
}

+ (BOOL)handlerDisplayName:(NSString *)handlerDisplayName
    matchesApplicationDisplayName:(NSString *)applicationDisplayName {
    return [handlerDisplayName isEqualToString:@"iTerm 2"] ||
        ([applicationDisplayName isEqualToString:@"iTerm2-CN"] &&
         [handlerDisplayName isEqualToString:@"iTerm2-CN"]);
}

+ (instancetype)sharedInstance {
    static id instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSUserDefaults *userDefaults = [iTermUserDefaults userDefaults];
        ProfileModel *profileModel = [ProfileModel sharedInstance];

        // read in the handlers by converting the index back to bookmarks
        _urlHandlersByGuid = [[NSMutableDictionary alloc] init];
        NSDictionary *tempDict = [userDefaults objectForKey:kUrlHandlersUserDefaultsKey];
        if (!tempDict) {
            // Iterate over old style url handlers (which stored bookmark by index)
            // and add guid->urlkey to urlHandlersByGuid.
            tempDict = [userDefaults objectForKey:kOldStyleUrlHandlersUserDefaultsKey];

            for (id key in tempDict) {
                int theIndex = [[tempDict objectForKey:key] intValue];
                if (theIndex >= 0 &&
                    theIndex  < [profileModel numberOfBookmarks]) {
                    NSString *guid = [[profileModel profileAtIndex:theIndex] objectForKey:KEY_GUID];
                    _urlHandlersByGuid[key] = guid;
                }
            }
        } else {
            for (id key in tempDict) {
                NSString* guid = [tempDict objectForKey:key];
                if ([profileModel indexOfProfileWithGuid:guid] >= 0) {
                    _urlHandlersByGuid[key] = guid;
                }
            }
        }
    }
    return self;
}

- (void)connectBookmarkWithGuid:(NSString*)guid toScheme:(NSString*)scheme {
    NSURL *appURL = nil;
    BOOL set = YES;

    appURL = (NSURL *)LSCopyDefaultApplicationURLForURL((CFURLRef)[NSURL URLWithString:[scheme stringByAppendingString:@":"]],
                                                        kLSRolesAll,
                                                        NULL);
    [appURL autorelease];

    NSString *handlerDisplayName = appURL ? [[NSFileManager defaultManager] displayNameAtPath:appURL.path] : nil;
    NSString *applicationDisplayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    const BOOL handlerIsThisApplication =
        [self.class handlerDisplayName:handlerDisplayName
         matchesApplicationDisplayName:applicationDisplayName];

    if (appURL == nil) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        alert.messageText = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.system.itermlaunchservices.iterm_is_not_the_default_handler_for_would.a645bf0d", nil, NSBundle.mainBundle, @"iTerm is not the default handler for %@. "
                             @"Would you like to set iTerm as the default handler?", @"User-facing text in iTermLaunchServices (messageText)."),
                             scheme];
        alert.informativeText = NSLocalizedStringWithDefaultValue(@"ui.system.itermlaunchservices.there_is_currently_no_handler.483cc1c7", nil, NSBundle.mainBundle, @"There is currently no handler.", @"User-facing text in iTermLaunchServices (informativeText).");
        [alert addButtonWithTitle:NSLocalizedStringWithDefaultValue(@"ui.system.itermlaunchservices.ok.565339bc", nil, NSBundle.mainBundle, @"OK", @"User-facing text in iTermLaunchServices (addButtonWithTitle).")];
        [alert addButtonWithTitle:NSLocalizedStringWithDefaultValue(@"ui.system.itermlaunchservices.cancel.19766ed6", nil, NSBundle.mainBundle, @"Cancel", @"User-facing text in iTermLaunchServices (addButtonWithTitle).")];
        set = ([alert runModal] == NSAlertFirstButtonReturn);
    } else if (!handlerIsThisApplication) {
        NSString *theTitle = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.system.itermlaunchservices.iterm_is_not_the_default_handler_for_would.a645bf0d",
                                                                                           nil,
                                                                                           NSBundle.mainBundle,
                                                                                           @"iTerm is not the default handler for %@. Would you like to set iTerm as the default handler?",
                                                                                           @"Prompt to make iTerm the default URL-scheme handler."),
                              scheme];
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        alert.messageText = theTitle;
        alert.informativeText = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.system.itermlaunchservices.the_current_handler_is.22350534", nil, NSBundle.mainBundle, @"The current handler is: %@", @"User-facing text in iTermLaunchServices (informativeText)."),
                                 handlerDisplayName];
        [alert addButtonWithTitle:NSLocalizedStringWithDefaultValue(@"ui.system.itermlaunchservices.ok.565339bc", nil, NSBundle.mainBundle, @"OK", @"User-facing text in iTermLaunchServices (connectBookmarkWithGuid:toScheme:).")];
        [alert addButtonWithTitle:NSLocalizedStringWithDefaultValue(@"ui.system.itermlaunchservices.cancel.19766ed6", nil, NSBundle.mainBundle, @"Cancel", @"User-facing text in iTermLaunchServices (connectBookmarkWithGuid:toScheme:).")];
        set = ([alert runModal] == NSAlertFirstButtonReturn);
    }

    if (set) {
        _urlHandlersByGuid[scheme] = guid;
        LSSetDefaultHandlerForURLScheme((CFStringRef)scheme,
                                        (CFStringRef)[[NSBundle mainBundle] bundleIdentifier]);
    }
    [self updateUserDefaults];
}

- (void)registerForiTerm2Scheme {
    LSSetDefaultHandlerForURLScheme((CFStringRef)@"iterm2",
                                    (CFStringRef)[[NSBundle mainBundle] bundleIdentifier]);
}


- (void)disconnectHandlerForScheme:(NSString*)scheme {
    [_urlHandlersByGuid removeObjectForKey:scheme];
    [self updateUserDefaults];
}

- (NSString *)guidForScheme:(NSString *)scheme {
    return _urlHandlersByGuid[scheme];
}

- (void)updateUserDefaults {
    [[iTermUserDefaults userDefaults] setObject:_urlHandlersByGuid
                                              forKey:kUrlHandlersUserDefaultsKey];
}

- (NSString *)bundleIDForDefaultHandlerForScheme:(NSString *)scheme {
    NSURL *schemeAsURL = [NSURL URLWithString:[scheme stringByAppendingString:@":"]];
    if (!schemeAsURL) {
        return nil;
    }
    NSURL *appURL = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:schemeAsURL];
    if (!appURL) {
        return nil;
    }
    NSBundle *bundle = [NSBundle bundleWithURL:appURL];
    return bundle.bundleIdentifier;
}

- (Profile *)profileForScheme:(NSString *)scheme {
    if (![self iTermIsDefaultForScheme:scheme]) {
        return nil;
    }
    return [[ProfileModel sharedInstance] bookmarkWithGuid:[self guidForScheme:scheme]];
}

- (BOOL)pickApplicationToOpenFile:(NSString *)fullPath {
    DLog(@"Showing app open panel");
    BOOL picked = NO;
    _currentFileUrlForOpenPanel = [NSURL fileURLWithPath:fullPath];
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    panel.delegate = self;
    panel.allowsMultipleSelection = NO;
    if ([panel runModal] == NSModalResponseOK) {
        picked = YES;
        RLog(@"Selected app has url %@", panel.URL);
        NSBundle *appBundle = [NSBundle bundleWithURL:panel.URL];
        NSString *bundleId = [appBundle bundleIdentifier];
        DLog(@"Bundle id is %@", bundleId);
        if (bundleId) {
            NSString *uti;
            NSError *error;
            if ([_currentFileUrlForOpenPanel getResourceValue:&uti forKey:NSURLTypeIdentifierKey error:&error]) {
                RLog(@"UTI is %@. Make it the default viewer.", uti);
                LSSetDefaultRoleHandlerForContentType((CFStringRef)uti,
                                                      kLSRolesViewer,
                                                      (CFStringRef)bundleId);
                _currentFileUrlForOpenPanel = nil;
            }
        }
    }
    return picked;
}

- (BOOL)offerToPickApplicationToOpenFile:(NSString *)fullPath {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    alert.messageText = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"ui.system.itermlaunchservices.there_is_no_application_set_to_open_the.56b3c8b2", nil, NSBundle.mainBundle, @"There is no application set to open the document “%@”", @"User-facing text in iTermLaunchServices (messageText)."), [fullPath lastPathComponent]];
    alert.informativeText = NSLocalizedStringWithDefaultValue(@"ui.system.itermlaunchservices.choose_an_application_on_your_computer_to_open.9ca251aa", nil, NSBundle.mainBundle, @"Choose an application on your computer to open this file.", @"User-facing text in iTermLaunchServices (offerToPickApplicationToOpenFile:).");
    [alert addButtonWithTitle:NSLocalizedStringWithDefaultValue(@"ui.system.itermlaunchservices.choose_application.cc53a4fa", nil, NSBundle.mainBundle, @"Choose Application…", @"User-facing text in iTermLaunchServices (offerToPickApplicationToOpenFile:).")];
    [alert addButtonWithTitle:NSLocalizedStringWithDefaultValue(@"ui.system.itermlaunchservices.cancel.19766ed6", nil, NSBundle.mainBundle, @"Cancel", @"User-facing text in iTermLaunchServices (offerToPickApplicationToOpenFile:).")];

    DLog(@"Offer to pick an app to open %@", fullPath);
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        return [self pickApplicationToOpenFile:fullPath];
    } else {
        DLog(@"Offer declined");
        return NO;
    }
}

- (void)openFile:(NSString *)fullPath
          window:(NSWindow *)window
      completion:(void (^)(BOOL ok))completion {
    [self openFile:fullPath fragment:nil target:nil window:window completion:completion];
}

- (void)openFile:(NSString *)fullPath
        fragment:(NSString *)fragment
          target:(NSString *)target
          window:(NSWindow *)window
      completion:(void (^)(BOOL ok))completion {
    RLog(@"openFile: %@ with fragment %@", fullPath, fragment);
    NSURL *url;
    BOOL shouldOfferToPickAppOnError = NO;
    if (fragment) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:[NSURL fileURLWithPath:fullPath]
                                                 resolvingAgainstBaseURL:NO];
        components.fragment = fragment;
        url = components.URL;
    } else {
        url = [NSURL fileURLWithPath:fullPath];
        shouldOfferToPickAppOnError = YES;
    }
    [[NSWorkspace sharedWorkspace] it_asyncOpenURL:url
                                            target:target
                                     configuration:[NSWorkspaceOpenConfiguration configuration]
                                             style:iTermOpenStyleTab
                                            upsell:YES
                                            window:window
                                        completion:^(NSRunningApplication *app, NSError *error) {
        if (error &&
            shouldOfferToPickAppOnError &&
            [self offerToPickApplicationToOpenFile:fullPath]) {
            DLog(@"Try to open %@ again", fullPath);
            const BOOL ok = [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:fullPath]];
            DLog(@"ok=%d", (int)ok);
            completion(ok);
            return;
        }
        completion(error == nil);
    }];
}

#pragma mark - Default Terminal

- (void)makeITermDefaultTerminal {
    NSString *iTermBundleId = [[NSBundle mainBundle] bundleIdentifier];
    [self setDefaultTerminal:iTermBundleId];
}

- (void)makeTerminalDefaultTerminal {
    [self setDefaultTerminal:@"com.apple.terminal"];
}

- (BOOL)iTermIsDefaultTerminal {
    CFStringRef unixExecutableContentType = (CFStringRef)@"public.unix-executable";
    CFStringRef unixHandler = LSCopyDefaultRoleHandlerForContentType(unixExecutableContentType, kLSRolesShell);
    NSString *iTermBundleId = [[NSBundle mainBundle] bundleIdentifier];
    BOOL result = [iTermBundleId isEqualToString:(NSString *)unixHandler];
    if (unixHandler) {
        CFRelease(unixHandler);
    }
    return result;
}

- (BOOL)iTermIsDefaultForScheme:(NSString *)scheme {
    NSString *handlerId = [self bundleIDForDefaultHandlerForScheme:scheme];
    NSString *iTermBundleId = [[NSBundle mainBundle] bundleIdentifier];
    BOOL result = [handlerId isEqualToString:iTermBundleId] || [@"net.sourceforge.iterm" isEqualToString:handlerId];
    return result;
}

- (void)setDefaultTerminal:(NSString *)bundleId {
    CFStringRef unixExecutableContentType = (CFStringRef)@"public.unix-executable";
    LSSetDefaultRoleHandlerForContentType(unixExecutableContentType,
                                          kLSRolesShell,
                                          (CFStringRef) bundleId);
}

#pragma mark - NSOpenSavePanelDelegate

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url {
    Boolean acceptsItem = NO;
    LSCanURLAcceptURL((CFURLRef)_currentFileUrlForOpenPanel,
                      (CFURLRef)url,
                      kLSRolesViewer,
                      kLSAcceptDefault,
                      &acceptsItem);
    return (BOOL)acceptsItem;
}

@end
