//
//  NSBundle+iTerm.m
//  iTerm2
//
//  Created by George Nachman on 6/29/17.
//
//

#import "NSBundle+iTerm.h"

@implementation NSBundle (iTerm)

+ (BOOL)it_isNightlyBuild {
    static dispatch_once_t onceToken;
    static BOOL result;
    dispatch_once(&onceToken, ^{
        NSString *testingFeed = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SUFeedURLForTesting"];
        result = [testingFeed containsString:@"nightly"];
    });
    return result;
}

+ (BOOL)it_isEarlyAdopter {
    NSString *testingFeed = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SUFeedURLForTesting"];
    return [testingFeed containsString:@"testing3.xml"];
}

+ (BOOL)it_isCNCommunityBuild {
    return [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"iTermCNCommunityBuild"] boolValue];
}

+ (void)it_applyCNUpdatePolicyToUserDefaults:(NSUserDefaults *)userDefaults
                           isCNCommunityBuild:(BOOL)isCNCommunityBuild {
    if (!isCNCommunityBuild) {
        return;
    }
    NSMutableDictionary<NSString *, id> *argumentDomain =
        [[userDefaults volatileDomainForName:NSArgumentDomain] mutableCopy];
    if (!argumentDomain) {
        argumentDomain = [NSMutableDictionary dictionary];
    }
    argumentDomain[@"SUEnableAutomaticChecks"] = @NO;
    argumentDomain[@"SUAutomaticallyUpdate"] = @NO;
    argumentDomain[@"SUFeedURL"] = @"";
    [userDefaults setVolatileDomain:argumentDomain forName:NSArgumentDomain];
}

+ (void)it_applyCNUpdatePolicyToUserDefaults:(NSUserDefaults *)userDefaults {
    [self it_applyCNUpdatePolicyToUserDefaults:userDefaults
                           isCNCommunityBuild:[self it_isCNCommunityBuild]];
}

+ (NSDate *)it_buildDate {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]];
    [dateFormatter setDateFormat:@"LLL d yyyy HH:mm:ss v"];
    NSString *string = [NSString stringWithFormat:@"%s %s PT", __DATE__, __TIME__];
    return [dateFormatter dateFromString:string];
}

@end
