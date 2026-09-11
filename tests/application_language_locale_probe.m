#import <Foundation/Foundation.h>
#import "NSBundle+iTerm.h"
#import "iTermApplicationLanguageController.h"

@interface iTermUserDefaults : NSObject
+ (NSUserDefaults *)userDefaults;
+ (NSString *)customSuiteName;
@end

// Substitute only the preferences backing store. The language controller and
// the entire locale inference implementation are compiled from production.
@interface LocaleProbeDefaults : NSUserDefaults
@property(nonatomic, copy) NSDictionary *globalFixture;
@end

@implementation LocaleProbeDefaults
- (NSDictionary *)persistentDomainForName:(NSString *)name {
    if ([name isEqual:NSGlobalDomain]) {
        return self.globalFixture;
    }
    return [super persistentDomainForName:name];
}
@end

static LocaleProbeDefaults *probeDefaults;
static NSString *probeSuite;
static NSUserDefaults *globalObserver;
static NSDictionary *globalBefore;

@implementation iTermUserDefaults
+ (NSUserDefaults *)userDefaults {
    return probeDefaults;
}
+ (NSString *)customSuiteName {
    return probeSuite;
}
@end

BOOL PrepareLocaleProbe(NSString *selection, NSString *fixtureJSON) {
    NSData *data = [fixtureJSON dataUsingEncoding:NSUTF8StringEncoding];
    id fixture = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![fixture isKindOfClass:NSDictionary.class]) {
        return NO;
    }
    probeSuite = [@"com.iterm2.tests.locale-input." stringByAppendingString:NSUUID.UUID.UUIDString];
    globalObserver = [[NSUserDefaults alloc] initWithSuiteName:probeSuite];
    globalBefore = [globalObserver persistentDomainForName:NSGlobalDomain];
    probeDefaults = [[LocaleProbeDefaults alloc] initWithSuiteName:probeSuite];
    probeDefaults.globalFixture = fixture;
    // Simulate a previously saved UI selection, with an old persistent override.
    [probeDefaults setObject:selection forKey:iTermApplicationLanguagePreferenceKey];
    [probeDefaults setObject:@[ @"zh-Hans" ] forKey:@"AppleLanguages"];
    if ([NSBundle it_isCNCommunityBuild]) {
        return [iTermApplicationLanguageController applySavedLanguagePreferenceWithError:nil];
    }
    return YES;
}

BOOL FinishLocaleProbe(void) {
    NSDictionary *globalAfter = [globalObserver persistentDomainForName:NSGlobalDomain];
    BOOL unchanged = (globalBefore == globalAfter) || [globalBefore isEqual:globalAfter];
    [probeDefaults removePersistentDomainForName:probeSuite];
    return [probeDefaults synchronize] && unchanged;
}
