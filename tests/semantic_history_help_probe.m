// Actual help expressions and detail method with only the selected tag stubbed.
// No application, window, command, preference, or link is opened.
#import <Foundation/Foundation.h>

static NSBundle *probeBundle;

@interface ProbeSelection : NSObject
@property(nonatomic) NSInteger tag;
- (ProbeSelection *)selectedItem;
@end
@implementation ProbeSelection
- (ProbeSelection *)selectedItem { return self; }
@end

@interface HelpProbe : NSObject {
    ProbeSelection *action_;
}
- (instancetype)initWithTag:(NSInteger)tag;
- (NSString *)detailTextForCurrentMode;
@end
@implementation HelpProbe
- (instancetype)initWithTag:(NSInteger)tag {
    self = [super init];
    if (self) {
        action_ = [[ProbeSelection alloc] init];
        action_.tag = tag;
    }
    return self;
}
// HELP-DETAIL-METHOD
@end

static NSString *ShortHelp(NSInteger tag) {
    switch (tag) {
        // HELP-SHORT-CASES
        default: return @"";
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) { return 2; }
        probeBundle = [NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]];
        if (!probeBundle) { return 2; }
        NSMutableArray *rows = [NSMutableArray array];
        for (NSInteger tag = 1; tag <= 7; tag++) {
            HelpProbe *probe = [[HelpProbe alloc] initWithTag:tag];
            [rows addObject:@{ @"tag": @(tag), @"short": ShortHelp(tag),
                               @"detail": [probe detailTextForCurrentMode] }];
        }
        NSDictionary *result = @{ @"rows": rows,
                                  @"linkURL": /* HELP-LINK-URL */,
                                  @"linkTitle": /* HELP-LINK-TITLE */ };
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:&error];
        if (!data) { return 3; }
        [[NSFileHandle fileHandleWithStandardOutput] writeData:data];
    }
    return 0;
}
