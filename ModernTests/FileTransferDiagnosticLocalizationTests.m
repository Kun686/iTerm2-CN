// Shared transfer errors reach logs and completion handlers, not just UI.
#import <XCTest/XCTest.h>
#import "FileTransferManager.h"

// Objective-C can exercise the manager's nil-description fallback without
// inventing an invalid Swift String or opening a real transfer.
@interface MissingTransferErrorDescription : NSError
@end

@implementation MissingTransferErrorDescription
- (NSString *)localizedDescription {
    return nil;
}
@end

@interface DiagnosticRecordingTransfer : TransferrableFile
@property(nonatomic, strong) NSMutableArray<NSString *> *reportedErrors;
@end

@implementation DiagnosticRecordingTransfer
- (instancetype)init {
    self = [super init];
    if (self) {
        _reportedErrors = [NSMutableArray array];
    }
    return self;
}

- (void)didFailWithError:(NSString *)error {
    // Replace only the notification sink; the real manager and callback run.
    // Setting FinishedWithError instead would itself request notification access.
    [self.reportedErrors addObject:error];
}
@end

@interface FileTransferDiagnosticLocalizationTests : XCTestCase
@end

@implementation FileTransferDiagnosticLocalizationTests

- (void)testMissingDescriptionPreservesOriginalFallbackAndNilCompletionError {
    DiagnosticRecordingTransfer *file = [[DiagnosticRecordingTransfer alloc] init];
    NSError *error = [[MissingTransferErrorDescription alloc] initWithDomain:@"synthetic.transfer"
                                                                      code:1
                                                                  userInfo:nil];
    __block NSUInteger calls = 0;
    file.completionBlock = ^(BOOL success, NSString *message) {
        calls++;
        XCTAssertFalse(success);
        // The upstream callback receives nil, not the display/log fallback.
        XCTAssertNil(message);
    };
    FileTransferManager *manager = [FileTransferManager sharedInstance];
    [manager transferrableFile:file didFinishTransmissionWithError:error];
    XCTAssertEqualObjects(file.reportedErrors, (@[ @"File transfer failed with an unknown error" ]));
    XCTAssertEqual(calls, 1u);
    XCTAssertNil(file.completionBlock);
    [manager transferrableFile:file didFinishTransmissionWithError:error];
    XCTAssertEqual(calls, 1u);
}

- (void)testExternalDiagnosticPassesThroughUnchanged {
    DiagnosticRecordingTransfer *file = [[DiagnosticRecordingTransfer alloc] init];
    NSString *original = @"synthetic: cannot read /synthetic/Example 文件.txt (EIO)";
    NSError *error = [NSError errorWithDomain:@"synthetic.transfer"
                                       code:2
                                   userInfo:@{ NSLocalizedDescriptionKey: original }];
    __block NSUInteger calls = 0;
    file.completionBlock = ^(BOOL success, NSString *message) {
        calls++;
        XCTAssertFalse(success);
        XCTAssertEqualObjects(message, original);
    };
    [[FileTransferManager sharedInstance] transferrableFile:file didFinishTransmissionWithError:error];
    XCTAssertEqualObjects(file.reportedErrors, (@[ original ]));
    XCTAssertEqual(calls, 1u);
    XCTAssertNil(file.completionBlock);
}

- (void)testCancellationPreservesOriginalCallbackAndState {
    DiagnosticRecordingTransfer *file = [[DiagnosticRecordingTransfer alloc] init];
    __block NSUInteger calls = 0;
    file.completionBlock = ^(BOOL success, NSString *message) {
        calls++;
        XCTAssertFalse(success);
        XCTAssertEqualObjects(message, @"Transfer cancelled");
    };
    FileTransferManager *manager = [FileTransferManager sharedInstance];
    [manager transferrableFileWillStop:file];
    XCTAssertEqual(file.status, kTransferrableFileStatusCancelling);
    [manager transferrableFileDidStopTransfer:file];
    XCTAssertEqual(file.status, kTransferrableFileStatusCancelled);
    XCTAssertEqual(file.reportedErrors.count, 0u);
    XCTAssertEqual(calls, 1u);
    XCTAssertNil(file.completionBlock);
    [manager transferrableFileDidStopTransfer:file];
    XCTAssertEqual(calls, 1u);
}

@end
