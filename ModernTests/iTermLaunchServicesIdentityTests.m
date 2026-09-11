//
//  iTermLaunchServicesIdentityTests.m
//  ModernTests
//

#import <XCTest/XCTest.h>

#import "iTermLaunchServices.h"

@interface iTermLaunchServices (IdentityTesting)
+ (BOOL)handlerDisplayName:(NSString *)handlerDisplayName
    matchesApplicationDisplayName:(NSString *)applicationDisplayName;
@end

@interface iTermLaunchServicesIdentityTests : XCTestCase
@end

@implementation iTermLaunchServicesIdentityTests

- (void)testRecognizesStockAndCNApplicationDisplayNames {
    XCTAssertTrue([iTermLaunchServices handlerDisplayName:@"iTerm 2"
                            matchesApplicationDisplayName:@"iTerm2"]);
    XCTAssertTrue([iTermLaunchServices handlerDisplayName:@"iTerm2-CN"
                            matchesApplicationDisplayName:@"iTerm2-CN"]);
}

- (void)testDoesNotTreatArbitraryMatchingDisplayNameAsThisApplication {
    XCTAssertFalse([iTermLaunchServices handlerDisplayName:@"Other Terminal"
                             matchesApplicationDisplayName:@"Other Terminal"]);
    XCTAssertFalse([iTermLaunchServices handlerDisplayName:nil
                             matchesApplicationDisplayName:@"iTerm2-CN"]);
    XCTAssertFalse([iTermLaunchServices handlerDisplayName:@"iTerm2-CN"
                             matchesApplicationDisplayName:@"iTerm2"]);
}

@end
