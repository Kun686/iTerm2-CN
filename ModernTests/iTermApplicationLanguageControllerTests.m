//
//  iTermApplicationLanguageControllerTests.m
//  ModernTests
//

#import <XCTest/XCTest.h>

#import "iTermApplicationLanguageController.h"

@interface iTermApplicationLanguageController (Testing)

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

@interface iTermApplicationLanguageRejectingUserDefaults : NSUserDefaults

@property(nonatomic, copy) NSString *testDomainName;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *testDomain;
@property(nonatomic) NSInteger successfulWritesBeforeRejection;
@property(nonatomic) BOOL rejectedWrite;

@end

@implementation iTermApplicationLanguageRejectingUserDefaults

- (NSDictionary<NSString *,id> *)persistentDomainForName:(NSString *)domainName {
    return [domainName isEqual:self.testDomainName] ? [self.testDomain copy] : nil;
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    if (self.successfulWritesBeforeRejection > 0) {
        self.successfulWritesBeforeRejection--;
    } else if (!self.rejectedWrite) {
        self.rejectedWrite = YES;
        return;
    }
    self.testDomain[defaultName] = value;
}

- (void)removeObjectForKey:(NSString *)defaultName {
    [self.testDomain removeObjectForKey:defaultName];
}

- (BOOL)synchronize {
    return YES;
}

@end

@interface iTermApplicationLanguageControllerTests : XCTestCase
@end

@implementation iTermApplicationLanguageControllerTests {
    NSString *_suiteName;
    NSUserDefaults *_userDefaults;
    NSDictionary<NSString *, id> *_argumentDomain;
}

- (void)setUp {
    [super setUp];
    _suiteName = [@"com.iterm2.tests.application-language." stringByAppendingString:NSUUID.UUID.UUIDString];
    _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:_suiteName];
    [_userDefaults removePersistentDomainForName:_suiteName];
    _argumentDomain = [_userDefaults volatileDomainForName:NSArgumentDomain];
    NSMutableDictionary<NSString *, id> *testArgumentDomain = [_argumentDomain mutableCopy];
    [testArgumentDomain removeObjectForKey:@"AppleLanguages"];
    [_userDefaults setVolatileDomain:testArgumentDomain forName:NSArgumentDomain];
}

- (void)tearDown {
    [_userDefaults setVolatileDomain:_argumentDomain forName:NSArgumentDomain];
    [_userDefaults removePersistentDomainForName:_suiteName];
    _argumentDomain = nil;
    _userDefaults = nil;
    _suiteName = nil;
    [super tearDown];
}

- (void)testFirstLaunchDefaultsToSimplifiedChinese {
    NSString *selection =
        [iTermApplicationLanguageController selectedLanguageIdentifierInUserDefaults:_userDefaults
                                                                applicationDomainName:_suiteName];

    XCTAssertEqualObjects(selection, iTermApplicationLanguageIdentifierSimplifiedChinese);
}

- (void)testReadsEnglishSelection {
    [_userDefaults setObject:iTermApplicationLanguageIdentifierEnglish
                      forKey:iTermApplicationLanguagePreferenceKey];

    NSString *selection =
        [iTermApplicationLanguageController selectedLanguageIdentifierInUserDefaults:_userDefaults
                                                                applicationDomainName:_suiteName];

    XCTAssertEqualObjects(selection, iTermApplicationLanguageIdentifierEnglish);
}

- (void)testReadsFollowSystemSelection {
    [_userDefaults setObject:iTermApplicationLanguageIdentifierSystem
                      forKey:iTermApplicationLanguagePreferenceKey];

    NSString *selection =
        [iTermApplicationLanguageController selectedLanguageIdentifierInUserDefaults:_userDefaults
                                                                applicationDomainName:_suiteName];

    XCTAssertEqualObjects(selection, iTermApplicationLanguageIdentifierSystem);
}

- (void)testUnknownSelectionFallsBackToEnglish {
    [_userDefaults setObject:@"removed-language"
                      forKey:iTermApplicationLanguagePreferenceKey];

    NSString *selection =
        [iTermApplicationLanguageController selectedLanguageIdentifierInUserDefaults:_userDefaults
                                                                applicationDomainName:_suiteName];

    XCTAssertEqualObjects(selection, iTermApplicationLanguageIdentifierEnglish);
}

- (void)testReadingUnknownSelectionDoesNotMutateStorage {
    [_userDefaults setObject:@"removed-language"
                      forKey:iTermApplicationLanguagePreferenceKey];
    NSDictionary *before = [_userDefaults persistentDomainForName:_suiteName];

    NSString *selection =
        [iTermApplicationLanguageController selectedLanguageIdentifierInUserDefaults:_userDefaults
                                                                applicationDomainName:_suiteName];

    XCTAssertEqualObjects(selection, iTermApplicationLanguageIdentifierEnglish);
    XCTAssertEqualObjects([_userDefaults persistentDomainForName:_suiteName], before);
}

- (void)testExistingApplicationLanguageOverrideIsRespectedOnFirstLaunch {
    [_userDefaults setObject:@[ @"en-US" ] forKey:@"AppleLanguages"];

    NSString *selection =
        [iTermApplicationLanguageController selectedLanguageIdentifierInUserDefaults:_userDefaults
                                                                applicationDomainName:_suiteName];

    XCTAssertEqualObjects(selection, iTermApplicationLanguageIdentifierEnglish);
}

- (void)testFirstLaunchAppliesSimplifiedChineseToApplicationDomain {
    NSError *error = nil;
    BOOL ok = [iTermApplicationLanguageController applySavedLanguagePreferenceInUserDefaults:_userDefaults
                                                                        applicationDomainName:_suiteName
                                                                                       error:&error];

    XCTAssertTrue(ok, @"%@", error);
    XCTAssertEqualObjects([_userDefaults persistentDomainForName:_suiteName][@"AppleLanguages"],
                          (@[ @"zh-Hans" ]));
    XCTAssertEqualObjects([_userDefaults volatileDomainForName:NSArgumentDomain][@"AppleLanguages"],
                          (@[ @"zh-Hans" ]));
}

- (void)testSavedEnglishSelectionAppliesEnglishToApplicationDomain {
    [_userDefaults setObject:iTermApplicationLanguageIdentifierEnglish
                      forKey:iTermApplicationLanguagePreferenceKey];
    [_userDefaults setObject:@[ @"zh-Hans" ] forKey:@"AppleLanguages"];

    NSError *error = nil;
    BOOL ok = [iTermApplicationLanguageController applySavedLanguagePreferenceInUserDefaults:_userDefaults
                                                                        applicationDomainName:_suiteName
                                                                                       error:&error];

    XCTAssertTrue(ok, @"%@", error);
    XCTAssertEqualObjects([_userDefaults persistentDomainForName:_suiteName][@"AppleLanguages"],
                          (@[ @"en" ]));
    XCTAssertEqualObjects([_userDefaults volatileDomainForName:NSArgumentDomain][@"AppleLanguages"],
                          (@[ @"en" ]));
}

- (void)testFollowSystemSelectionRemovesApplicationOverride {
    [_userDefaults setObject:iTermApplicationLanguageIdentifierSystem
                      forKey:iTermApplicationLanguagePreferenceKey];
    [_userDefaults setObject:@[ @"zh-Hans" ] forKey:@"AppleLanguages"];

    NSError *error = nil;
    BOOL ok = [iTermApplicationLanguageController applySavedLanguagePreferenceInUserDefaults:_userDefaults
                                                                        applicationDomainName:_suiteName
                                                                                       error:&error];

    XCTAssertTrue(ok, @"%@", error);
    XCTAssertNil([_userDefaults persistentDomainForName:_suiteName][@"AppleLanguages"]);
    XCTAssertNil([_userDefaults volatileDomainForName:NSArgumentDomain][@"AppleLanguages"]);
}

- (void)testSavingEnglishPersistsSelectionWithoutChangingCurrentProcessLanguage {
    NSDictionary *argumentDomain = @{
        @"AppleLanguages": @[ @"zh-Hans" ],
        @"UnrelatedArgument": @"preserve-me",
    };
    [_userDefaults setVolatileDomain:argumentDomain forName:NSArgumentDomain];
    BOOL didChange = NO;
    NSError *error = nil;
    BOOL ok = [iTermApplicationLanguageController setSelectedLanguageIdentifier:iTermApplicationLanguageIdentifierEnglish
                                                                  inUserDefaults:_userDefaults
                                                           applicationDomainName:_suiteName
                                                                       didChange:&didChange
                                                                           error:&error];

    NSDictionary *domain = [_userDefaults persistentDomainForName:_suiteName];
    XCTAssertTrue(ok, @"%@", error);
    XCTAssertTrue(didChange);
    XCTAssertEqualObjects(domain[iTermApplicationLanguagePreferenceKey], @"en");
    XCTAssertEqualObjects(domain[@"AppleLanguages"], (@[ @"en" ]));
    XCTAssertEqualObjects([_userDefaults volatileDomainForName:NSArgumentDomain], argumentDomain);
}

- (void)testSelectingEnglishFallbackPersistsExplicitSelection {
    [_userDefaults setObject:@[ @"fr-FR" ] forKey:@"AppleLanguages"];
    XCTAssertEqualObjects(
        [iTermApplicationLanguageController selectedLanguageIdentifierInUserDefaults:_userDefaults
                                                                applicationDomainName:_suiteName],
        iTermApplicationLanguageIdentifierEnglish);
    BOOL didChange = NO;
    NSError *error = nil;

    BOOL ok = [iTermApplicationLanguageController
        setSelectedLanguageIdentifier:iTermApplicationLanguageIdentifierEnglish
                       inUserDefaults:_userDefaults
                applicationDomainName:_suiteName
                            didChange:&didChange
                                error:&error];

    NSDictionary *domain = [_userDefaults persistentDomainForName:_suiteName];
    XCTAssertTrue(ok, @"%@", error);
    XCTAssertTrue(didChange);
    XCTAssertEqualObjects(domain[iTermApplicationLanguagePreferenceKey], @"en");
    XCTAssertEqualObjects(domain[@"AppleLanguages"], (@[ @"en" ]));
}

- (void)testSupportedLanguageRegistryContainsTheThreeMVPChoices {
    XCTAssertEqualObjects(iTermApplicationLanguageController.supportedLanguageIdentifiers,
                          (@[ @"zh-Hans", @"en", @"system" ]));
}

- (void)testEveryRegisteredConcreteLanguageCanBeResolvedFromExistingOverride {
    for (iTermApplicationLanguageIdentifier identifier in
         iTermApplicationLanguageController.supportedLanguageIdentifiers) {
        if ([identifier isEqual:iTermApplicationLanguageIdentifierSystem]) {
            continue;
        }
        [_userDefaults setObject:@[ identifier ] forKey:@"AppleLanguages"];

        XCTAssertEqualObjects(
            [iTermApplicationLanguageController selectedLanguageIdentifierInUserDefaults:_userDefaults
                                                                    applicationDomainName:_suiteName],
            identifier);
    }
}

- (void)testReadsSimplifiedChineseSelection {
    [_userDefaults setObject:iTermApplicationLanguageIdentifierSimplifiedChinese
                      forKey:iTermApplicationLanguagePreferenceKey];

    XCTAssertEqualObjects(
        [iTermApplicationLanguageController selectedLanguageIdentifierInUserDefaults:_userDefaults
                                                                applicationDomainName:_suiteName],
        iTermApplicationLanguageIdentifierSimplifiedChinese);
}

- (void)testEmptySelectionFallsBackToEnglish {
    [_userDefaults setObject:@"" forKey:iTermApplicationLanguagePreferenceKey];

    XCTAssertEqualObjects(
        [iTermApplicationLanguageController selectedLanguageIdentifierInUserDefaults:_userDefaults
                                                                applicationDomainName:_suiteName],
        iTermApplicationLanguageIdentifierEnglish);
}

- (void)testSavingCurrentSelectionIsIdempotent {
    [_userDefaults setObject:iTermApplicationLanguageIdentifierEnglish
                      forKey:iTermApplicationLanguagePreferenceKey];
    [_userDefaults setObject:@[ @"en" ] forKey:@"AppleLanguages"];
    NSDictionary *before = [_userDefaults persistentDomainForName:_suiteName];
    BOOL didChange = YES;
    NSError *error = nil;

    BOOL ok = [iTermApplicationLanguageController setSelectedLanguageIdentifier:iTermApplicationLanguageIdentifierEnglish
                                                                  inUserDefaults:_userDefaults
                                                           applicationDomainName:_suiteName
                                                                       didChange:&didChange
                                                                           error:&error];

    XCTAssertTrue(ok, @"%@", error);
    XCTAssertFalse(didChange);
    XCTAssertEqualObjects([_userDefaults persistentDomainForName:_suiteName], before);
}

- (void)testSavingImplicitFirstLaunchSelectionIsIdempotent {
    NSError *error = nil;
    BOOL applied =
        [iTermApplicationLanguageController applySavedLanguagePreferenceInUserDefaults:_userDefaults
                                                                   applicationDomainName:_suiteName
                                                                                  error:&error];
    XCTAssertTrue(applied, @"%@", error);
    NSDictionary *before = [_userDefaults persistentDomainForName:_suiteName];
    XCTAssertNil(before[iTermApplicationLanguagePreferenceKey]);
    XCTAssertEqualObjects(before[@"AppleLanguages"], (@[ @"zh-Hans" ]));

    BOOL didChange = YES;
    error = nil;
    BOOL ok = [iTermApplicationLanguageController
        setSelectedLanguageIdentifier:iTermApplicationLanguageIdentifierSimplifiedChinese
                       inUserDefaults:_userDefaults
                applicationDomainName:_suiteName
                            didChange:&didChange
                                error:&error];

    XCTAssertTrue(ok, @"%@", error);
    XCTAssertFalse(didChange);
    XCTAssertEqualObjects([_userDefaults persistentDomainForName:_suiteName], before);
}

- (void)testSavingFollowSystemPersistsSelectionAndRemovesOverride {
    [_userDefaults setObject:iTermApplicationLanguageIdentifierEnglish
                      forKey:iTermApplicationLanguagePreferenceKey];
    [_userDefaults setObject:@[ @"en" ] forKey:@"AppleLanguages"];
    NSDictionary *argumentDomain = @{
        @"AppleLanguages": @[ @"en" ],
        @"UnrelatedArgument": @"preserve-me",
    };
    [_userDefaults setVolatileDomain:argumentDomain forName:NSArgumentDomain];
    BOOL didChange = NO;
    NSError *error = nil;

    BOOL ok = [iTermApplicationLanguageController setSelectedLanguageIdentifier:iTermApplicationLanguageIdentifierSystem
                                                                  inUserDefaults:_userDefaults
                                                           applicationDomainName:_suiteName
                                                                       didChange:&didChange
                                                                           error:&error];

    NSDictionary *domain = [_userDefaults persistentDomainForName:_suiteName];
    XCTAssertTrue(ok, @"%@", error);
    XCTAssertTrue(didChange);
    XCTAssertEqualObjects(domain[iTermApplicationLanguagePreferenceKey], @"system");
    XCTAssertNil(domain[@"AppleLanguages"]);
    XCTAssertEqualObjects([_userDefaults volatileDomainForName:NSArgumentDomain], argumentDomain);
}

- (void)testRejectingUnsupportedSelectionPreservesPreviousValues {
    [_userDefaults setObject:iTermApplicationLanguageIdentifierEnglish
                      forKey:iTermApplicationLanguagePreferenceKey];
    [_userDefaults setObject:@[ @"en" ] forKey:@"AppleLanguages"];
    NSDictionary *before = [_userDefaults persistentDomainForName:_suiteName];
    BOOL didChange = YES;
    NSError *error = nil;

    BOOL ok = [iTermApplicationLanguageController setSelectedLanguageIdentifier:@"fr"
                                                                  inUserDefaults:_userDefaults
                                                           applicationDomainName:_suiteName
                                                                       didChange:&didChange
                                                                           error:&error];

    XCTAssertFalse(ok);
    XCTAssertFalse(didChange);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects([_userDefaults persistentDomainForName:_suiteName], before);
}

- (void)testUnsupportedSelectionErrorCarriesStableDiagnosticDescription {
    NSError *error = nil;

    BOOL ok = [iTermApplicationLanguageController setSelectedLanguageIdentifier:@"fr"
                                                                  inUserDefaults:_userDefaults
                                                           applicationDomainName:_suiteName
                                                                       didChange:NULL
                                                                           error:&error];

    XCTAssertFalse(ok);
    XCTAssertEqualObjects(error.userInfo[NSDebugDescriptionErrorKey],
                          @"The selected application language is not supported.");
}

- (void)testApplyingFirstLaunchPreservesExistingApplicationOverride {
    [_userDefaults setObject:@[ @"en-US" ] forKey:@"AppleLanguages"];
    NSError *error = nil;

    BOOL ok = [iTermApplicationLanguageController applySavedLanguagePreferenceInUserDefaults:_userDefaults
                                                                        applicationDomainName:_suiteName
                                                                                       error:&error];

    XCTAssertTrue(ok, @"%@", error);
    XCTAssertEqualObjects([_userDefaults persistentDomainForName:_suiteName][@"AppleLanguages"],
                          (@[ @"en-US" ]));
    XCTAssertEqualObjects([_userDefaults volatileDomainForName:NSArgumentDomain][@"AppleLanguages"],
                          (@[ @"en" ]));
}

- (void)testUnknownSavedSelectionAppliesEnglishFallback {
    [_userDefaults setObject:@"removed-language" forKey:iTermApplicationLanguagePreferenceKey];
    NSError *error = nil;

    BOOL ok = [iTermApplicationLanguageController applySavedLanguagePreferenceInUserDefaults:_userDefaults
                                                                        applicationDomainName:_suiteName
                                                                                       error:&error];

    XCTAssertTrue(ok, @"%@", error);
    XCTAssertEqualObjects([_userDefaults persistentDomainForName:_suiteName][@"AppleLanguages"],
                          (@[ @"en" ]));
}

- (void)testLanguagePreferenceUsesNoSyncConvention {
    XCTAssertTrue([iTermApplicationLanguagePreferenceKey hasPrefix:@"NoSync"]);
}

- (void)testSavingLanguageDoesNotWriteTheGlobalDomain {
    NSDictionary *before = [_userDefaults persistentDomainForName:NSGlobalDomain];
    NSError *error = nil;

    BOOL ok = [iTermApplicationLanguageController setSelectedLanguageIdentifier:iTermApplicationLanguageIdentifierEnglish
                                                                  inUserDefaults:_userDefaults
                                                           applicationDomainName:_suiteName
                                                                       didChange:NULL
                                                                           error:&error];

    XCTAssertTrue(ok, @"%@", error);
    XCTAssertEqualObjects([_userDefaults persistentDomainForName:NSGlobalDomain], before);
}

- (void)testFailedSaveRestoresPreviousSelectionAndOverride {
    iTermApplicationLanguageRejectingUserDefaults *defaults =
        [[iTermApplicationLanguageRejectingUserDefaults alloc] init];
    defaults.testDomainName = @"test-domain";
    defaults.testDomain = [@{
        iTermApplicationLanguagePreferenceKey: @"zh-Hans",
        @"AppleLanguages": @[ @"zh-Hans" ],
    } mutableCopy];
    defaults.successfulWritesBeforeRejection = 1;
    NSDictionary *before = [defaults.testDomain copy];
    BOOL didChange = YES;
    NSError *error = nil;

    BOOL ok = [iTermApplicationLanguageController setSelectedLanguageIdentifier:iTermApplicationLanguageIdentifierEnglish
                                                                  inUserDefaults:defaults
                                                           applicationDomainName:defaults.testDomainName
                                                                       didChange:&didChange
                                                                           error:&error];

    XCTAssertFalse(ok);
    XCTAssertFalse(didChange);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(defaults.testDomain, before);
}

- (void)testFailedSaveDoesNotChangeCurrentProcessArgumentDomain {
    iTermApplicationLanguageRejectingUserDefaults *defaults =
        [[iTermApplicationLanguageRejectingUserDefaults alloc] init];
    defaults.testDomainName = @"test-domain";
    defaults.testDomain = [@{
        iTermApplicationLanguagePreferenceKey: @"en",
        @"AppleLanguages": @[ @"en" ],
    } mutableCopy];
    defaults.successfulWritesBeforeRejection = 0;
    NSDictionary *argumentDomain = @{
        @"AppleLanguages": @[ @"zh-Hans" ],
        @"UnrelatedArgument": @"preserve-me",
    };
    [defaults setVolatileDomain:argumentDomain forName:NSArgumentDomain];
    BOOL didChange = YES;
    NSError *error = nil;

    BOOL ok = [iTermApplicationLanguageController
        setSelectedLanguageIdentifier:iTermApplicationLanguageIdentifierSimplifiedChinese
                       inUserDefaults:defaults
                applicationDomainName:defaults.testDomainName
                            didChange:&didChange
                                error:&error];

    XCTAssertFalse(ok);
    XCTAssertFalse(didChange);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects([defaults volatileDomainForName:NSArgumentDomain], argumentDomain);
}

@end
