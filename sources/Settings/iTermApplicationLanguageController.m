//
//  iTermApplicationLanguageController.m
//  iTerm2
//

#import "iTermApplicationLanguageController.h"

#import "iTermUserDefaults.h"

iTermApplicationLanguageIdentifier const iTermApplicationLanguageIdentifierSimplifiedChinese = @"zh-Hans";
iTermApplicationLanguageIdentifier const iTermApplicationLanguageIdentifierEnglish = @"en";
iTermApplicationLanguageIdentifier const iTermApplicationLanguageIdentifierSystem = @"system";
NSString *const iTermApplicationLanguagePreferenceKey = @"NoSyncApplicationLanguage";

static NSString *const iTermApplicationLanguageRegistryIdentifierKey = @"identifier";
static NSString *const iTermApplicationLanguageRegistryDisplayNameKey = @"displayName";
static NSString *const iTermApplicationLanguageRegistryLocalizationKey = @"localizationKey";

static NSArray<NSDictionary<NSString *, NSString *> *> *iTermApplicationLanguageRegistry(void) {
    static NSArray<NSDictionary<NSString *, NSString *> *> *registry;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        registry = @[
            @{
                iTermApplicationLanguageRegistryIdentifierKey:
                    iTermApplicationLanguageIdentifierSimplifiedChinese,
                iTermApplicationLanguageRegistryDisplayNameKey: @"Simplified Chinese",
                iTermApplicationLanguageRegistryLocalizationKey:
                    @"settings.general.language.option.zh-Hans",
            },
            @{
                iTermApplicationLanguageRegistryIdentifierKey:
                    iTermApplicationLanguageIdentifierEnglish,
                iTermApplicationLanguageRegistryDisplayNameKey: @"English",
                iTermApplicationLanguageRegistryLocalizationKey:
                    @"settings.general.language.option.en",
            },
            @{
                iTermApplicationLanguageRegistryIdentifierKey:
                    iTermApplicationLanguageIdentifierSystem,
                iTermApplicationLanguageRegistryDisplayNameKey: @"Follow System",
                iTermApplicationLanguageRegistryLocalizationKey:
                    @"settings.general.language.option.system",
            },
        ];
    });
    return registry;
}

static NSArray<iTermApplicationLanguageIdentifier> *iTermApplicationLanguageIdentifiers(void) {
    return [iTermApplicationLanguageRegistry() valueForKey:iTermApplicationLanguageRegistryIdentifierKey];
}

static NSDictionary<NSString *, NSString *> *iTermApplicationLanguageRegistryEntry(
    iTermApplicationLanguageIdentifier identifier) {
    for (NSDictionary<NSString *, NSString *> *entry in iTermApplicationLanguageRegistry()) {
        if ([entry[iTermApplicationLanguageRegistryIdentifierKey] isEqual:identifier]) {
            return entry;
        }
    }
    return nil;
}

static NSString *iTermApplicationLanguageLocalizedString(NSString *key, NSString *fallback) {
    return [NSBundle.mainBundle localizedStringForKey:key value:fallback table:nil];
}

static NSError *iTermApplicationLanguageError(NSInteger code,
                                               NSString *localizationKey,
                                               NSString *fallback) {
    return [NSError errorWithDomain:@"com.iterm2.application-language"
                               code:code
                           userInfo:@{
                               NSLocalizedDescriptionKey:
                                   iTermApplicationLanguageLocalizedString(localizationKey, fallback),
                               NSDebugDescriptionErrorKey: fallback,
                           }];
}

static NSString *iTermApplicationLanguageDomainName(void) {
    NSString *suiteName = iTermUserDefaults.customSuiteName;
    if (suiteName.length > 0) {
        return suiteName;
    }
    return NSBundle.mainBundle.bundleIdentifier;
}

static iTermApplicationLanguageIdentifier iTermApplicationLanguageIdentifierForAppleLanguages(id value) {
    if (![value isKindOfClass:NSArray.class]) {
        return iTermApplicationLanguageIdentifierEnglish;
    }
    NSArray *languages = value;
    if (![languages.firstObject isKindOfClass:NSString.class]) {
        return iTermApplicationLanguageIdentifierEnglish;
    }
    NSMutableArray<iTermApplicationLanguageIdentifier> *registeredLanguageIdentifiers =
        [NSMutableArray array];
    for (NSDictionary<NSString *, NSString *> *entry in iTermApplicationLanguageRegistry()) {
        iTermApplicationLanguageIdentifier identifier =
            entry[iTermApplicationLanguageRegistryIdentifierKey];
        if (![identifier isEqual:iTermApplicationLanguageIdentifierSystem]) {
            [registeredLanguageIdentifiers addObject:identifier];
        }
    }
    NSArray<NSString *> *preferred =
        [NSBundle preferredLocalizationsFromArray:registeredLanguageIdentifiers
                                   forPreferences:languages];
    iTermApplicationLanguageIdentifier resolvedIdentifier = preferred.firstObject;
    if ([registeredLanguageIdentifiers containsObject:resolvedIdentifier]) {
        return resolvedIdentifier;
    }
    return iTermApplicationLanguageIdentifierEnglish;
}

static void iTermApplicationLanguageApplyCurrentProcessOverride(
    NSUserDefaults *userDefaults,
    NSArray<NSString *> *languages) {
    NSMutableDictionary<NSString *, id> *argumentDomain =
        [[userDefaults volatileDomainForName:NSArgumentDomain] mutableCopy];
    if (!argumentDomain) {
        argumentDomain = [NSMutableDictionary dictionary];
    }
    if (languages) {
        argumentDomain[@"AppleLanguages"] = languages;
    } else {
        [argumentDomain removeObjectForKey:@"AppleLanguages"];
    }
    [userDefaults setVolatileDomain:argumentDomain forName:NSArgumentDomain];
}

@interface iTermApplicationLanguageController ()

+ (iTermApplicationLanguageIdentifier)selectedLanguageIdentifierInUserDefaults:(NSUserDefaults *)userDefaults
                                                           applicationDomainName:(NSString *)applicationDomainName;

+ (BOOL)applySavedLanguagePreferenceInUserDefaults:(NSUserDefaults *)userDefaults
                              applicationDomainName:(NSString *)applicationDomainName
                                             error:(NSError * _Nullable * _Nullable)error;

+ (BOOL)setSelectedLanguageIdentifier:(iTermApplicationLanguageIdentifier)identifier
                         inUserDefaults:(NSUserDefaults *)userDefaults
                  applicationDomainName:(NSString *)applicationDomainName
                              didChange:(BOOL * _Nullable)didChange
                                  error:(NSError * _Nullable * _Nullable)error;

@end

@implementation iTermApplicationLanguageController

+ (NSArray<iTermApplicationLanguageIdentifier> *)supportedLanguageIdentifiers {
    return iTermApplicationLanguageIdentifiers();
}

+ (iTermApplicationLanguageIdentifier)selectedLanguageIdentifier {
    NSString *domainName = iTermApplicationLanguageDomainName();
    if (domainName.length == 0) {
        return iTermApplicationLanguageIdentifierEnglish;
    }
    return [self selectedLanguageIdentifierInUserDefaults:iTermUserDefaults.userDefaults
                                    applicationDomainName:domainName];
}

+ (NSString *)localizedDisplayNameForLanguageIdentifier:(iTermApplicationLanguageIdentifier)identifier {
    NSDictionary<NSString *, NSString *> *entry = iTermApplicationLanguageRegistryEntry(identifier);
    if (!entry) {
        entry = iTermApplicationLanguageRegistryEntry(iTermApplicationLanguageIdentifierEnglish);
    }
    return iTermApplicationLanguageLocalizedString(
        entry[iTermApplicationLanguageRegistryLocalizationKey],
        entry[iTermApplicationLanguageRegistryDisplayNameKey]);
}

+ (BOOL)applySavedLanguagePreferenceWithError:(NSError **)error {
    NSString *domainName = iTermApplicationLanguageDomainName();
    if (domainName.length == 0) {
        if (error) {
            *error = iTermApplicationLanguageError(
                3,
                @"settings.general.language.error.missing_application_domain",
                @"The application language could not be saved because the application domain is unavailable.");
        }
        return NO;
    }
    return [self applySavedLanguagePreferenceInUserDefaults:iTermUserDefaults.userDefaults
                                      applicationDomainName:domainName
                                                     error:error];
}

+ (BOOL)setSelectedLanguageIdentifier:(iTermApplicationLanguageIdentifier)identifier
                             didChange:(BOOL *)didChange
                                 error:(NSError **)error {
    NSString *domainName = iTermApplicationLanguageDomainName();
    if (domainName.length == 0) {
        if (didChange) {
            *didChange = NO;
        }
        if (error) {
            *error = iTermApplicationLanguageError(
                3,
                @"settings.general.language.error.missing_application_domain",
                @"The application language could not be saved because the application domain is unavailable.");
        }
        return NO;
    }
    return [self setSelectedLanguageIdentifier:identifier
                                 inUserDefaults:iTermUserDefaults.userDefaults
                          applicationDomainName:domainName
                                      didChange:didChange
                                          error:error];
}

+ (iTermApplicationLanguageIdentifier)selectedLanguageIdentifierInUserDefaults:(NSUserDefaults *)userDefaults
                                                           applicationDomainName:(NSString *)applicationDomainName {
    NSDictionary<NSString *, id> *applicationDomain =
        [userDefaults persistentDomainForName:applicationDomainName] ?: @{};
    id storedValue = applicationDomain[iTermApplicationLanguagePreferenceKey];
    if (!storedValue) {
        id existingOverride = applicationDomain[@"AppleLanguages"];
        if (existingOverride) {
            return iTermApplicationLanguageIdentifierForAppleLanguages(existingOverride);
        }
        return iTermApplicationLanguageIdentifierSimplifiedChinese;
    }
    if ([storedValue isKindOfClass:NSString.class] &&
        [iTermApplicationLanguageIdentifiers() containsObject:storedValue]) {
        return storedValue;
    }
    return iTermApplicationLanguageIdentifierEnglish;
}

+ (BOOL)applySavedLanguagePreferenceInUserDefaults:(NSUserDefaults *)userDefaults
                              applicationDomainName:(NSString *)applicationDomainName
                                             error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    NSDictionary<NSString *, id> *applicationDomain =
        [userDefaults persistentDomainForName:applicationDomainName] ?: @{};
    id storedValue = applicationDomain[iTermApplicationLanguagePreferenceKey];
    if (!storedValue && applicationDomain[@"AppleLanguages"]) {
        iTermApplicationLanguageIdentifier selection =
            iTermApplicationLanguageIdentifierForAppleLanguages(applicationDomain[@"AppleLanguages"]);
        iTermApplicationLanguageApplyCurrentProcessOverride(userDefaults, @[ selection ]);
        return YES;
    }
    iTermApplicationLanguageIdentifier selection =
        [self selectedLanguageIdentifierInUserDefaults:userDefaults
                                 applicationDomainName:applicationDomainName];
    NSArray<NSString *> *languages = nil;
    if ([selection isEqual:iTermApplicationLanguageIdentifierSystem]) {
        [userDefaults removeObjectForKey:@"AppleLanguages"];
    } else {
        languages = @[ selection ];
        [userDefaults setObject:languages forKey:@"AppleLanguages"];
    }
    BOOL synchronized = [userDefaults synchronize];
    id savedLanguages = [userDefaults persistentDomainForName:applicationDomainName][@"AppleLanguages"];
    BOOL saved = synchronized &&
        (languages ? [savedLanguages isEqual:languages] : (savedLanguages == nil));
    if (saved) {
        iTermApplicationLanguageApplyCurrentProcessOverride(userDefaults, languages);
    }
    if (!saved && error) {
        *error = iTermApplicationLanguageError(
            1,
            @"settings.general.language.error.save_failed",
            @"The application language could not be saved.");
    }
    return saved;
}

+ (BOOL)setSelectedLanguageIdentifier:(iTermApplicationLanguageIdentifier)identifier
                         inUserDefaults:(NSUserDefaults *)userDefaults
                  applicationDomainName:(NSString *)applicationDomainName
                              didChange:(BOOL *)didChange
                                  error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (didChange) {
        *didChange = NO;
    }
    if (![identifier isKindOfClass:NSString.class] ||
        ![iTermApplicationLanguageIdentifiers() containsObject:identifier]) {
        if (error) {
            *error = iTermApplicationLanguageError(
                2,
                @"settings.general.language.error.unsupported_selection",
                @"The selected application language is not supported.");
        }
        return NO;
    }

    NSDictionary<NSString *, id> *oldDomain =
        [userDefaults persistentDomainForName:applicationDomainName] ?: @{};
    id oldStoredSelection = oldDomain[iTermApplicationLanguagePreferenceKey];
    id oldAppleLanguages = oldDomain[@"AppleLanguages"];
    NSArray<NSString *> *expectedAppleLanguages =
        [identifier isEqual:iTermApplicationLanguageIdentifierSystem] ? nil : @[ identifier ];
    BOOL selectionAlreadyStored = [oldStoredSelection isEqual:identifier];
    BOOL overrideAlreadyStored = expectedAppleLanguages
        ? [oldAppleLanguages isEqual:expectedAppleLanguages]
        : oldAppleLanguages == nil;
    BOOL implicitFirstLaunchDefaultAlreadySelected =
        oldStoredSelection == nil &&
        [identifier isEqual:iTermApplicationLanguageIdentifierSimplifiedChinese] &&
        (oldAppleLanguages == nil ||
         [iTermApplicationLanguageIdentifierForAppleLanguages(oldAppleLanguages)
             isEqual:iTermApplicationLanguageIdentifierSimplifiedChinese]);
    if (implicitFirstLaunchDefaultAlreadySelected) {
        return YES;
    }
    if (selectionAlreadyStored && overrideAlreadyStored) {
        return YES;
    }

    [userDefaults setObject:identifier forKey:iTermApplicationLanguagePreferenceKey];
    if (expectedAppleLanguages) {
        [userDefaults setObject:expectedAppleLanguages forKey:@"AppleLanguages"];
    } else {
        [userDefaults removeObjectForKey:@"AppleLanguages"];
    }
    BOOL synchronized = [userDefaults synchronize];
    NSDictionary<NSString *, id> *newDomain =
        [userDefaults persistentDomainForName:applicationDomainName] ?: @{};
    BOOL selectionSaved = [newDomain[iTermApplicationLanguagePreferenceKey] isEqual:identifier];
    id savedAppleLanguages = newDomain[@"AppleLanguages"];
    BOOL overrideSaved = expectedAppleLanguages
        ? [savedAppleLanguages isEqual:expectedAppleLanguages]
        : savedAppleLanguages == nil;
    if (!synchronized || !selectionSaved || !overrideSaved) {
        if (oldStoredSelection) {
            [userDefaults setObject:oldStoredSelection forKey:iTermApplicationLanguagePreferenceKey];
        } else {
            [userDefaults removeObjectForKey:iTermApplicationLanguagePreferenceKey];
        }
        if (oldAppleLanguages) {
            [userDefaults setObject:oldAppleLanguages forKey:@"AppleLanguages"];
        } else {
            [userDefaults removeObjectForKey:@"AppleLanguages"];
        }
        [userDefaults synchronize];
        if (error && !*error) {
            *error = iTermApplicationLanguageError(
                1,
                @"settings.general.language.error.save_failed",
                @"The application language could not be saved.");
        }
        return NO;
    }

    if (didChange) {
        *didChange = YES;
    }
    return YES;
}

@end
