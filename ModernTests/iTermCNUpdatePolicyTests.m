//
//  iTermCNUpdatePolicyTests.m
//  ModernTests
//

#import <XCTest/XCTest.h>

#import "NSBundle+iTerm.h"

@interface NSBundle (iTermCNUpdatePolicyTesting)

+ (void)it_applyCNUpdatePolicyToUserDefaults:(NSUserDefaults *)userDefaults
                           isCNCommunityBuild:(BOOL)isCNCommunityBuild;

@end

@interface iTermCNUpdatePolicyTests : XCTestCase
@property(nonatomic) NSUserDefaults *userDefaults;
@property(nonatomic) NSString *suiteName;
@property(nonatomic) NSDictionary<NSString *, id> *argumentDomain;
@end

@implementation iTermCNUpdatePolicyTests

- (void)setUp {
    [super setUp];
    self.suiteName = [@"com.iterm2.tests.cn-update-policy." stringByAppendingString:NSUUID.UUID.UUIDString];
    self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.suiteName];
    self.argumentDomain = [self.userDefaults volatileDomainForName:NSArgumentDomain];
    // A CN test host already disables updates in its process argument domain.
    // Isolate the fixture inputs; tearDown restores the host's original domain.
    NSMutableDictionary<NSString *, id> *testArgumentDomain = [self.argumentDomain mutableCopy];
    [testArgumentDomain removeObjectsForKeys:@[ @"SUEnableAutomaticChecks",
                                               @"SUAutomaticallyUpdate",
                                               @"SUFeedURL" ]];
    [self.userDefaults setVolatileDomain:testArgumentDomain forName:NSArgumentDomain];
}

- (void)tearDown {
    [self.userDefaults setVolatileDomain:self.argumentDomain forName:NSArgumentDomain];
    [self.userDefaults removePersistentDomainForName:self.suiteName];
    self.argumentDomain = nil;
    self.userDefaults = nil;
    self.suiteName = nil;
    [super tearDown];
}

- (void)testCNUpdatePolicyDisablesUpdatesForProcessWithoutChangingPersistentPreferences {
    [self.userDefaults setBool:YES forKey:@"SUEnableAutomaticChecks"];
    [self.userDefaults setBool:YES forKey:@"SUAutomaticallyUpdate"];
    [self.userDefaults setObject:@"https://iterm2.com/appcasts/final_modern.xml"
                          forKey:@"SUFeedURL"];
    NSDictionary *persistentDomain =
        [self.userDefaults persistentDomainForName:self.suiteName];
    NSMutableDictionary<NSString *, id> *argumentDomain = [self.argumentDomain mutableCopy];
    argumentDomain[@"AppleLanguages"] = @[ @"zh-Hans" ];
    argumentDomain[@"UnrelatedArgument"] = @"preserve-me";
    [self.userDefaults setVolatileDomain:argumentDomain forName:NSArgumentDomain];

    [NSBundle it_applyCNUpdatePolicyToUserDefaults:self.userDefaults
                                isCNCommunityBuild:YES];

    XCTAssertEqualObjects([self.userDefaults persistentDomainForName:self.suiteName],
                          persistentDomain);
    XCTAssertFalse([self.userDefaults boolForKey:@"SUEnableAutomaticChecks"]);
    XCTAssertFalse([self.userDefaults boolForKey:@"SUAutomaticallyUpdate"]);
    XCTAssertEqualObjects([self.userDefaults stringForKey:@"SUFeedURL"], @"");
    NSDictionary<NSString *, id> *appliedArgumentDomain =
        [self.userDefaults volatileDomainForName:NSArgumentDomain];
    XCTAssertEqualObjects(appliedArgumentDomain[@"SUEnableAutomaticChecks"], @NO);
    XCTAssertEqualObjects(appliedArgumentDomain[@"SUAutomaticallyUpdate"], @NO);
    XCTAssertEqualObjects(appliedArgumentDomain[@"SUFeedURL"], @"");
    XCTAssertEqualObjects(appliedArgumentDomain[@"AppleLanguages"], (@[ @"zh-Hans" ]));
    XCTAssertEqualObjects(appliedArgumentDomain[@"UnrelatedArgument"], @"preserve-me");
}

- (void)testUpstreamUpdatePolicyDoesNotChangeExistingPreferences {
    [self.userDefaults setBool:YES forKey:@"SUEnableAutomaticChecks"];
    [self.userDefaults setBool:YES forKey:@"SUAutomaticallyUpdate"];
    [self.userDefaults setObject:@"https://iterm2.com/appcasts/final_modern.xml"
                          forKey:@"SUFeedURL"];
    NSDictionary *persistentDomain =
        [self.userDefaults persistentDomainForName:self.suiteName];
    NSDictionary *argumentDomain = [self.userDefaults volatileDomainForName:NSArgumentDomain];

    XCTAssertTrue([self.userDefaults boolForKey:@"SUEnableAutomaticChecks"]);
    XCTAssertTrue([self.userDefaults boolForKey:@"SUAutomaticallyUpdate"]);
    XCTAssertEqualObjects([self.userDefaults stringForKey:@"SUFeedURL"],
                          @"https://iterm2.com/appcasts/final_modern.xml");

    [NSBundle it_applyCNUpdatePolicyToUserDefaults:self.userDefaults
                                isCNCommunityBuild:NO];

    XCTAssertEqualObjects([self.userDefaults persistentDomainForName:self.suiteName],
                          persistentDomain);
    XCTAssertEqualObjects([self.userDefaults volatileDomainForName:NSArgumentDomain],
                          argumentDomain);
    XCTAssertTrue([self.userDefaults boolForKey:@"SUEnableAutomaticChecks"]);
    XCTAssertTrue([self.userDefaults boolForKey:@"SUAutomaticallyUpdate"]);
    XCTAssertEqualObjects([self.userDefaults stringForKey:@"SUFeedURL"],
                          @"https://iterm2.com/appcasts/final_modern.xml");
}

- (void)testUpstreamUpdatePolicyPreservesPreexistingArgumentOverrides {
    [self.userDefaults setBool:YES forKey:@"SUEnableAutomaticChecks"];
    [self.userDefaults setBool:YES forKey:@"SUAutomaticallyUpdate"];
    [self.userDefaults setObject:@"https://iterm2.com/appcasts/final_modern.xml"
                          forKey:@"SUFeedURL"];
    NSDictionary *persistentDomain =
        [self.userDefaults persistentDomainForName:self.suiteName];
    NSMutableDictionary<NSString *, id> *argumentDomain =
        [[self.userDefaults volatileDomainForName:NSArgumentDomain] mutableCopy];
    argumentDomain[@"SUEnableAutomaticChecks"] = @NO;
    argumentDomain[@"SUAutomaticallyUpdate"] = @NO;
    argumentDomain[@"SUFeedURL"] = @"";
    argumentDomain[@"UnrelatedArgument"] = @"preserve-me";
    [self.userDefaults setVolatileDomain:argumentDomain forName:NSArgumentDomain];

    [NSBundle it_applyCNUpdatePolicyToUserDefaults:self.userDefaults
                                isCNCommunityBuild:NO];

    XCTAssertEqualObjects([self.userDefaults persistentDomainForName:self.suiteName],
                          persistentDomain);
    XCTAssertEqualObjects([self.userDefaults volatileDomainForName:NSArgumentDomain],
                          argumentDomain);
    XCTAssertFalse([self.userDefaults boolForKey:@"SUEnableAutomaticChecks"]);
    XCTAssertFalse([self.userDefaults boolForKey:@"SUAutomaticallyUpdate"]);
    XCTAssertEqualObjects([self.userDefaults stringForKey:@"SUFeedURL"], @"");
}

@end
