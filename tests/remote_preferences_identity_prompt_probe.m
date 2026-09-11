// Real URL-upload help construction; only app/suite identity is synthetic.
// Does not read preferences, run an alert, copy files, or access the network.
#import <Foundation/Foundation.h>

static NSBundle *probeBundle;
static NSString *fixtureBundleID;
static NSString *fixtureSuite;

@interface ProbeIdentity : NSObject
+ (NSString *)bundleIdentifier;
@end
@implementation ProbeIdentity
+ (NSString *)bundleIdentifier { return fixtureBundleID; }
@end

@interface iTermUserDefaults : NSObject
+ (NSString *)customSuiteName;
@end
@implementation iTermUserDefaults
+ (NSString *)customSuiteName { return fixtureSuite; }
@end

static NSString *Prompt(void) {
    // REMOTE-UPLOAD-PROMPT
    return informativeText;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) { return 2; }
        probeBundle = [NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]];
        if (!probeBundle) { return 2; }
        NSArray *fixtures = @[
            @[ @"com.googlecode.iterm2", NSNull.null ],
            @[ @"com.kun686.iterm2-cn", NSNull.null ],
            @[ @"com.kun686.iterm2-cn", @"cn-isolated-synthetic" ],
            @[ @"com.kun686.iterm2-cn", @"cn.测试.synthetic" ]
        ];
        NSMutableArray *rows = [NSMutableArray array];
        for (NSArray *fixture in fixtures) {
            fixtureBundleID = fixture[0];
            fixtureSuite = fixture[1] == NSNull.null ? nil : fixture[1];
            [rows addObject:Prompt()];
        }
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:rows options:0 error:&error];
        if (!data) { return 3; }
        [[NSFileHandle fileHandleWithStandardOutput] writeData:data];
    }
    return 0;
}
