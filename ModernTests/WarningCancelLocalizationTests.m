#import <XCTest/XCTest.h>
#import "iTermUserDefaults.h"
#import "iTermWarning.h"

@interface iTermCancelLocalizationWarningHandler : NSObject<iTermWarningHandler>
@property(nonatomic) NSModalResponse response;
@property(nonatomic) NSUInteger calls;
@property(nonatomic, strong) NSAlert *alert;
@end

@implementation iTermCancelLocalizationWarningHandler
- (NSModalResponse)warningWouldShowAlert:(NSAlert *)alert identifier:(NSString *)identifier {
    self.alert = alert;
    self.calls++;
    alert.suppressionButton.state = NSControlStateValueOn;
    return self.response;
}
@end

@interface WarningCancelLocalizationTests : XCTestCase
@end

@implementation WarningCancelLocalizationTests

- (NSString *)localizedCancelLabel {
    // Use the same resource as real paste callers of the default warning API.
    return NSLocalizedStringWithDefaultValue(@"ui.pasting.itermpastehelper.cancel.19766ed6",
                                             nil, NSBundle.mainBundle, @"Cancel",
                                             @"Cancel label used by the paste confirmation.");
}

- (void)checkActions:(NSArray<NSString *> *)actions
           response:(NSModalResponse)response
        cancelLabel:(NSString *)explicitCancelLabel
     shouldRemember:(BOOL)shouldRemember {
    if (![NSThread isMainThread] ||
        ![[iTermUserDefaults customSuiteName] isEqualToString:@"iterm2-tests"]) {
        XCTFail(@"Warning fixtures require main and the isolated ModernTests suite");
        return;
    }
    NSString *identifier = [@"NoSyncWarningCancelLocalizationTest-"
        stringByAppendingString:NSUUID.UUID.UUIDString];
    id<iTermWarningHandler> previousHandler = [iTermWarning warningHandler];
    iTermCancelLocalizationWarningHandler *handler = [[iTermCancelLocalizationWarningHandler alloc] init];
    handler.response = response;
    @try {
        [iTermWarning setWarningHandler:handler];
        iTermWarningSelection selection;
        if (explicitCancelLabel) {
            selection = [iTermWarning showWarningWithTitle:@"Synthetic cancellation regression"
                                                   actions:actions
                                             actionMapping:nil
                                                 accessory:nil
                                                identifier:identifier
                                               silenceable:kiTermWarningTypePermanentlySilenceable
                                                   heading:@"Synthetic warning"
                                               cancelLabel:explicitCancelLabel
                                                    window:nil];
        } else {
            // This overload supplies the default cancel label internally, just
            // like the tab-conversion and other localized warning call sites.
            selection = [iTermWarning showWarningWithTitle:@"Synthetic cancellation regression"
                                                   actions:actions
                                                 accessory:nil
                                                identifier:identifier
                                               silenceable:kiTermWarningTypePermanentlySilenceable
                                                   heading:@"Synthetic warning"
                                                    window:nil];
        }
        XCTAssertEqual(handler.calls, 1u);
        XCTAssertTrue(handler.alert.showsSuppressionButton);
        XCTAssertEqual(selection, response - NSAlertFirstButtonReturn);
        XCTAssertEqualObjects(handler.alert.buttons[1].title, actions[1]);
        XCTAssertEqual([iTermWarning identifierIsSilenced:identifier], shouldRemember,
                       @"Cancel must not be remembered even with suppression checked");
        if (shouldRemember) {
            XCTAssertEqualObjects([iTermWarning conditionalSavedSelectionForIdentifier:identifier], @(selection));
        }
    } @finally {
        [iTermWarning clearSavedSelectionForIdentifier:identifier];
        [iTermWarning setWarningHandler:previousHandler];
        XCTAssertFalse([iTermWarning identifierIsSilenced:identifier]);
        XCTAssertTrue([iTermWarning warningHandler] == previousHandler);
    }
}

- (void)testLocalizedCancelIsNotRememberedByDefaultEntryPoint {
    NSString *cancel = [self localizedCancelLabel];
    BOOL chinese = [NSBundle.mainBundle.preferredLocalizations.firstObject isEqualToString:@"zh-Hans"];
    XCTAssertEqualObjects(cancel, chinese ? @"取消" : @"Cancel");
    [self checkActions:@[@"Synthetic proceed", cancel]
              response:NSAlertSecondButtonReturn cancelLabel:nil shouldRemember:NO];
}

- (void)testRawEnglishCancelRemainsCompatible {
    [self checkActions:@[@"Synthetic proceed", @"Cancel"]
              response:NSAlertSecondButtonReturn cancelLabel:nil shouldRemember:NO];
}

- (void)testProceedCanStillBeRemembered {
    [self checkActions:@[@"Synthetic proceed", [self localizedCancelLabel]]
              response:NSAlertFirstButtonReturn cancelLabel:nil shouldRemember:YES];
}

- (void)testExplicitCancelLabelRemainsAuthoritative {
    [self checkActions:@[@"Synthetic proceed", @"Synthetic stop"]
              response:NSAlertSecondButtonReturn cancelLabel:@"Synthetic stop" shouldRemember:NO];
}

- (void)testExplicitLocalizedCancelIsNotRemembered {
    NSString *cancel = [self localizedCancelLabel];
    [self checkActions:@[@"Synthetic proceed", cancel]
              response:NSAlertSecondButtonReturn cancelLabel:cancel shouldRemember:NO];
}
@end
