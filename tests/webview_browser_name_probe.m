// Real production getter and title expression; synthetic OS/name boundaries.
#import <AppKit/AppKit.h>
#include <stdio.h>

static NSBundle *probeBundle;
static NSURL *probeQuery;
static BOOL probeRoleMatches;

#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, defaultValue, comment) \
    [probeBundle localizedStringForKey:(key) value:(defaultValue) table:(tableName)]

@interface SyntheticApplicationURL : NSObject
@property(nonatomic, copy) NSString *displayName;
- (BOOL)getResourceValue:(id *)value forKey:(NSURLResourceKey)key error:(NSError **)error;
@end
@implementation SyntheticApplicationURL
- (BOOL)getResourceValue:(id *)value forKey:(NSURLResourceKey)key error:(NSError **)error {
    *value = [key isEqualToString:NSURLLocalizedNameKey] ? self.displayName : nil;
    return *value != nil;
}
@end

static SyntheticApplicationURL *probeApplication;
static CFURLRef ProbeDefaultApplicationURL(CFURLRef url, LSRolesMask role, CFErrorRef *error) {
    probeQuery = (__bridge NSURL *)url;
    probeRoleMatches = (role == kLSRolesAll);
    return probeApplication ? (CFURLRef)CFBridgingRetain(probeApplication) : NULL;
}
#define LSCopyDefaultApplicationURLForURL ProbeDefaultApplicationURL

@interface SyntheticWebView : NSObject
@property(nonatomic, copy) NSURL *URL;
@end
@implementation SyntheticWebView
@end

@interface SyntheticButton : NSObject
@property(nonatomic, copy) NSString *title;
@end
@implementation SyntheticButton
@end

@interface BrowserNameProbe : NSObject
@property(nonatomic, strong) SyntheticWebView *webView;
- (NSString *)browserName;
- (NSString *)buttonTitle;
@end
@implementation BrowserNameProbe
#include "browser-name.inc"
- (NSString *)buttonTitle {
    SyntheticButton *button = [[SyntheticButton alloc] init];
#include "browser-button-title.inc"
    return button.title;
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) { return 2; }
        probeBundle = [NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]];
        if (!probeBundle) { return 3; }
        BrowserNameProbe *wrapper = [[BrowserNameProbe alloc] init];
        wrapper.webView = [[SyntheticWebView alloc] init];
        NSMutableArray *rows = [NSMutableArray array];
        for (NSInteger index = 0; index < 5; index++) {
            wrapper.webView.URL = index == 0 ? nil : [NSURL URLWithString:@"https://example.invalid/raw?q=%25%40"];
            probeApplication = index < 2 ? nil : [[SyntheticApplicationURL alloc] init];
            probeApplication.displayName = index == 3 ? @"Synthetic %@ 中文 Browser" : (index == 4 ? @"" : nil);
            [rows addObject:@{ @"name": wrapper.browserName, @"title": wrapper.buttonTitle,
                              @"query": probeQuery.absoluteString, @"role": @(probeRoleMatches) }];
        }
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:rows options:0 error:&error];
        if (!data) { fprintf(stderr, "%s\n", error.localizedDescription.UTF8String); return 4; }
        if (fwrite(data.bytes, 1, data.length, stdout) != data.length) { return 5; }
        return 0;
    }
}
