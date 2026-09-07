// Compile the actual PTYTask error-construction excerpt without starting a PTY
// or asking for notification permission. The Python driver supplies resources.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

// Resolve the real catalog values from an explicitly selected test bundle.
// This does not change AppleLanguages or the user's preferences.
#undef NSLocalizedStringWithDefaultValue
#define NSLocalizedStringWithDefaultValue(key, tableName, bundle, defaultValue, comment) \
    [probeBundle localizedStringForKey:(key) value:(defaultValue) table:(tableName)]

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            return 2;
        }
        NSBundle *probeBundle = [NSBundle bundleWithPath:@(argv[1])];
        if (!probeBundle) {
            return 3;
        }
        NSNumber *optionalErrorCode = strcmp(argv[2], "none") == 0 ? nil : @([@(argv[2]) intValue]);

#include "fork-error.inc"

        if (!error || puts(error.UTF8String) < 0) {
            return 4;
        }
        return 0;
    }
}
