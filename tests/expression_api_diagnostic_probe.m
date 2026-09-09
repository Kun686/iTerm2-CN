// Real parser constructor, API completion method and console-format expression.
#import <Foundation/Foundation.h>
#include <stdio.h>

static NSBundle *probeBundle;
#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, defaultValue, comment) \
    [probeBundle localizedStringForKey:(key) value:(defaultValue) table:(tableName)]

enum { iTermParsedExpressionTypeError = 1,
       ITMInvokeFunctionResponse_Status_Timeout = 1,
       ITMInvokeFunctionResponse_Status_Failed = 2 };

@interface ParsedProbe : NSObject {
    int _expressionType;
    NSError *_object;
}
- (instancetype)initWithErrorCode:(int)code reason:(NSString *)reason;
- (NSError *)error;
@end
@implementation ParsedProbe
#include "parser-error.inc"
- (NSError *)error { return _object; }
@end

@interface ResponseError : NSObject
@property(nonatomic) NSInteger status;
@property(nonatomic, copy) NSString *errorReason;
@end
@implementation ResponseError
@end
@interface ResponseSuccess : NSObject
@property(nonatomic, copy) NSString *jsonResult;
@end
@implementation ResponseSuccess
@end
@interface ITMInvokeFunctionResponse : NSObject
@property(nonatomic, strong) ResponseError *error;
@property(nonatomic, strong) ResponseSuccess *success;
@end
@implementation ITMInvokeFunctionResponse
- (instancetype)init {
    self = [super init];
    if (self) { _error = [[ResponseError alloc] init]; _success = [[ResponseSuccess alloc] init]; }
    return self;
}
@end

@interface NSJSONSerialization(Probe)
+ (NSString *)it_jsonStringForObject:(id)object;
@end
@implementation NSJSONSerialization(Probe)
+ (NSString *)it_jsonStringForObject:(id)object {
    NSData *data = [self dataWithJSONObject:object options:NSJSONWritingFragmentsAllowed error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}
@end

@interface APIProbe : NSObject
- (void)functionInvocationDidCompleteWithObject:(id)object error:(NSError *)error completion:(void (^)(ITMInvokeFunctionResponse *))completion;
@end
@implementation APIProbe
#include "api-response.inc"
@end

static NSDictionary *snapshot(NSError *error) {
    __block ITMInvokeFunctionResponse *result;
    [[[APIProbe alloc] init] functionInvocationDidCompleteWithObject:nil error:error completion:^(ITMInvokeFunctionResponse *response) { result = response; }];
    NSString *invocation = @"iterm2.synthetic()";
    NSString *traceback = @"synthetic traceback";
#include "script-console.inc"
    return @{ @"domain": error.domain, @"code": @(error.code), @"userInfo": error.userInfo,
              @"apiReason": result.error.errorReason, @"failed": @(result.error.status == ITMInvokeFunctionResponse_Status_Failed),
              @"console": consoleMessage };
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3 || !(probeBundle = [NSBundle bundleWithPath:@(argv[1])])) { return 2; }
        NSData *input = [NSData dataWithContentsOfFile:@(argv[2])];
        if (!input) { return 3; }
        NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:input options:0 error:nil];
        if (![payload isKindOfClass:NSDictionary.class]) { return 4; }
        NSMutableArray *builtins = [NSMutableArray array];
        for (NSDictionary *row in payload[@"errors"]) {
            [builtins addObject:snapshot([NSError errorWithDomain:row[@"domain"] code:[row[@"code"] integerValue] userInfo:row[@"userInfo"]])];
        }
        NSMutableArray *parser = [NSMutableArray array];
        for (id reason in @[[NSNull null], @"", @"Supplied 用户 %@"]) {
            ParsedProbe *expression = [[ParsedProbe alloc] initWithErrorCode:7 reason:reason == [NSNull null] ? nil : reason];
            [parser addObject:snapshot(expression.error)];
        }
        NSData *data = [NSJSONSerialization dataWithJSONObject:@{ @"builtins": builtins, @"parser": parser } options:0 error:nil];
        return data && fwrite(data.bytes, 1, data.length, stdout) == data.length ? 0 : 5;
    }
}
