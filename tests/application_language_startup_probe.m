#import <Foundation/Foundation.h>

#import "NSBundle+iTerm.h"
#import "iTermApplicationLanguageController.h"

// Only satisfy the linker: the injected-defaults seam never uses this facade.
@interface iTermUserDefaults : NSObject
@end
@implementation iTermUserDefaults
@end

@interface iTermApplicationLanguageController (StartupTesting)
+ (BOOL)applySavedLanguagePreferenceInUserDefaults:(NSUserDefaults *)defaults
                           applicationDomainName:(NSString *)name
                                          error:(NSError **)error;
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 3) {
            return 2;
        }
        // Match main.m: checking the edition must not resolve a localization.
        if (![NSBundle it_isCNCommunityBuild]) {
            return 3;
        }
        NSString *selection = [NSString stringWithUTF8String:argv[1]];
        NSString *expected = [NSString stringWithUTF8String:argv[2]];
        NSString *suite = [@"com.iterm2.tests.language-startup."
            stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        NSDictionary *globalBefore = [defaults persistentDomainForName:NSGlobalDomain];
        [defaults setObject:selection forKey:iTermApplicationLanguagePreferenceKey];
        NSError *error = nil;
        BOOL applied = [iTermApplicationLanguageController
            applySavedLanguagePreferenceInUserDefaults:defaults
                                applicationDomainName:suite
                                               error:&error];
        NSString *localized = [NSBundle.mainBundle localizedStringForKey:@"probe"
                                                                  value:@"MISSING"
                                                                  table:nil];
        NSDictionary *globalAfter = [defaults persistentDomainForName:NSGlobalDomain];
        BOOL globalUnchanged = (globalBefore == globalAfter) || [globalBefore isEqual:globalAfter];
        BOOL ok = applied && [localized isEqual:expected] && globalUnchanged;
        printf("selected=%s localized=%s expected=%s applied=%d globalUnchanged=%d\n",
               selection.UTF8String, localized.UTF8String, expected.UTF8String,
               applied, globalUnchanged);
        [defaults removePersistentDomainForName:suite];
        [defaults synchronize];
        return ok ? 0 : 1;
    }
}
