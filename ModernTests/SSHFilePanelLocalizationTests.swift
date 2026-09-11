import XCTest
@testable import iTerm2SharedARC

final class SSHFilePanelLocalizationTests: XCTestCase {
    @MainActor
    private final class RecordingMkdirEndpoint: LocalhostEndpoint {
        var paths: [String] = []
        var didCreate: (() -> Void)?

        override func mkdir(_ file: String) async throws {
            // Record the real panel action's argument; never touch the filesystem.
            paths.append(file)
            didCreate?()
        }
    }

    @MainActor
    private func identity() -> SSHIdentity {
        SSHIdentity(host: "synthetic.invalid", hostname: "synthetic.invalid",
                    username: "fixture", port: 22)
    }

    private var endpointErrors: [(SSHEndpointException, String, String, String)] {
        [(.connectionClosed, "connectionClosed", "Connection closed", "Connection closed"),
         (.fileNotFound, "fileNotFound", "File not found", "File not found"),
         (.internalError, "internalError", "Internal error", "内部错误"),
         (.transferCanceled, "transferCanceled", "File transfer canceled", "文件传输已取消")]
    }

    @MainActor
    func testEndpointErrorsKeepSwiftLogIdentityAndPresentationBoundary() throws {
        let language = try XCTUnwrap(Bundle.main.preferredLocalizations.first)
        XCTAssertTrue(["en", "zh-Hans"].contains(language))
        let previousCallback = iTermCallbackLogging.callback
        defer { iTermCallbackLogging.callback = previousCallback }
        var messages: [String] = []
        iTermCallbackLogging.callback = { messages.append($0) }
        for (failure, caseName, english, chinese) in endpointErrors {
            let error: any Error = failure
            let retrospective: RLogMessage = "Download error: \(error)"
            XCTAssertEqual(retrospective.rendered, "Download error: " + caseName)
            XCTAssertEqual("\(error)", caseName)
            XCTAssertEqual(error.localizedDescription, language == "zh-Hans" ? chinese : english)
            messages.removeAll()
            XCTAssertThrowsError(try logging("endpoint localization") { () throws -> Void in
                throw error
            }) { thrown in
                XCTAssertEqual(thrown as? SSHEndpointException, failure)
            }
            XCTAssertEqual(messages, ["begin", "end",
                                      "Exiting logging scope with uncaught error " + caseName])
        }
    }

    @MainActor
    func testRemoteCreateCallbackPreservesAIToolDiagnostic() async throws {
        let conductor = Conductor(
            "synthetic.invalid", boolArgs: "", dcsID: "endpoint-error-test",
            clientUniqueID: "synthetic", varsToSend: [:], clientVars: [:],
            initialDirectory: nil, shouldInjectShellIntegration: false, parent: nil)
        // An unhooked conductor only queues requests; it cannot send to SSH.
        conductor.state = .unhooked
        let previousCallback = iTermCallbackLogging.callback
        defer {
            conductor.cancelEnqueuedRequests { _ in true }
            conductor.queue = []
            iTermCallbackLogging.callback = previousCallback
        }
        let path = "/synthetic/文件.txt"
        let content = Data([0, 1, 255])
        let cases: [(Int32, SSHEndpointException, String)] = [
            (-1, .connectionClosed, "Connection closed"),
            (1, .fileNotFound, "File not found")
        ]
        for (code, expectedError, diagnostic) in cases {
            let enqueued = expectation(description: "Conductor queues the create request")
            iTermCallbackLogging.callback = { message in
                if message.hasPrefix("append ") {
                    enqueued.fulfill()
                }
            }
            let completed = expectation(description: "Conductor reports create failure")
            var descriptions: [String?] = []
            conductor.create(file: path, content: content) { error in
                // PTYSession.createRemoteFile consumes this exact callback's
                // localizedDescription in its AI tool result and activity text.
                XCTAssertEqual(error as? SSHEndpointException, expectedError)
                descriptions.append(error?.localizedDescription)
                completed.fulfill()
            }
            await fulfillment(of: [enqueued], timeout: 5)
            XCTAssertEqual(conductor.queue.count, 1)
            let request = try XCTUnwrap(conductor.queue.first)
            guard case .framerFile(.create(let requestedPath, let requestedContent)) = request.command,
                  case .handleFile(_, let reply) = request.handler else {
                XCTFail("Expected a queued create-file request and reply handler")
                return
            }
            XCTAssertEqual(requestedPath, Data(path.utf8))
            XCTAssertEqual(requestedContent, content)
            conductor.queue = []
            // Deliver a synthetic remote failure at the existing transport seam.
            reply.call("", code)
            await fulfillment(of: [completed], timeout: 5)
            XCTAssertEqual(descriptions, [diagnostic])
            XCTAssertTrue(conductor.queue.isEmpty)
        }
    }

    @MainActor
    func testEndpointErrorsSurviveObjectiveCPromiseBridge() throws {
        for (failure, _, _, _) in endpointErrors {
            let original = failure as NSError
            let promise = iTermRenegablePromise<NSURL> { seal in
                seal.reject(failure)
            } renege: {
                XCTFail("A rejected promise must not cancel an operation")
            }
            let bridged = try XCTUnwrap(promise.maybeError) as NSError
            XCTAssertEqual(bridged.domain, original.domain)
            XCTAssertEqual(bridged.code, original.code)
            XCTAssertEqual(bridged.localizedDescription, original.localizedDescription)
            XCTAssertEqual(bridged as? SSHEndpointException, failure)
            var callbacks = 0
            promise.catchError { error in
                callbacks += 1
                XCTAssertEqual(error as? SSHEndpointException, failure)
            }
            promise.renege()
            XCTAssertEqual(callbacks, 1)
            XCTAssertTrue(promise.hasValue)
            XCTAssertNil(promise.maybeValue)
        }
    }

    @MainActor
    private final class FailingDownloadEndpoint: LocalhostEndpoint {
        var failure = SSHEndpointException.connectionClosed
        var paths: [String] = []

        override func download(_ path: String, chunk: DownloadChunk?, uniqueID: String?) async throws -> Data {
            paths.append(path)
            XCTAssertNil(chunk)
            XCTAssertNil(uniqueID)
            // Fail before the panel can write data; no network or file access.
            throw failure
        }
    }

    @MainActor
    func testPanelDownloadFailurePreservesTypedErrorInCallback() async throws {
        let panel = SSHFilePanel()
        let endpoint = FailingDownloadEndpoint()
        let file = RemoteFile(kind: .file(.init(size: 1)), absolutePath: "/synthetic/文件.txt")
        let node = SSHFilePanelFileList.FileNode(sshIdentity: identity(), file: file, path: "/synthetic")
        for (failure, _, _, _) in endpointErrors {
            endpoint.failure = failure
            let completed = expectation(description: "Panel reports the endpoint error")
            var results: [SSHEndpointException?] = []
            panel.sshFilePanelList(write: node, endpoint: endpoint,
                                  to: URL(fileURLWithPath: "/synthetic/not-written.txt")) { error in
                results.append(error as? SSHEndpointException)
                completed.fulfill()
            }
            await fulfillment(of: [completed], timeout: 5)
            XCTAssertEqual(results, [failure])
        }
        XCTAssertEqual(endpoint.paths, Array(repeating: file.absolutePath, count: endpointErrors.count))
        XCTAssertEqual(node.file, file)
    }

    @MainActor
    private func checkNewFolderName(enteredName: String?, expectedName: String) async throws {
        let panel = SSHFilePanel()
        let endpoint = RecordingMkdirEndpoint()
        // Do not attach a data source or prepare the full panel. The synthetic
        // identity cannot resolve to a local endpoint during post-create refresh.
        panel.includeLocalhost = false
        panel.currentEndpoint = endpoint
        panel.currentPath = SSHFileDescriptor(absolutePath: "/synthetic/父目录",
                                              isDirectory: true, sshIdentity: identity())
        let window = try XCTUnwrap(panel.window)
        defer {
            if let sheet = window.attachedSheet {
                window.endSheet(sheet)
                sheet.orderOut(nil)
            }
            window.close()
        }
        let action = NSSelectorFromString("newFolderButtonClicked:")
        XCTAssertTrue(panel.responds(to: action))
        panel.perform(action, with: NSButton())
        let sheet = try XCTUnwrap(window.attachedSheet)
        let content = try XCTUnwrap(sheet.contentView)
        let field = try XCTUnwrap(content.subviews.compactMap { $0 as? NSTextField }
            .first { $0.isEditable })
        if let enteredName {
            field.stringValue = enteredName
        }
        let buttons = content.subviews.compactMap { $0 as? NSStackView }
            .flatMap(\.arrangedSubviews).compactMap { $0 as? NSButton }
        let create = try XCTUnwrap(buttons.first { $0.action == NSSelectorFromString("createNewFolder:") })
        let created = expectation(description: "Panel calls recording mkdir")
        endpoint.didCreate = { created.fulfill() }
        create.performClick(nil)
        await fulfillment(of: [created], timeout: 5)
        XCTAssertEqual(endpoint.paths, ["/synthetic/父目录/" + expectedName])
        XCTAssertEqual(panel.currentPath?.absolutePath, "/synthetic/父目录")
    }

    @MainActor
    func testNewFolderDefaultKeepsOriginalFilesystemName() async throws {
        try await checkNewFolderName(enteredName: nil, expectedName: "untitled folder")
    }

    @MainActor
    func testNewFolderPreservesExplicitUserNameAndWhitespaceRule() async throws {
        try await checkNewFolderName(enteredName: "  My 文件夹  \n", expectedName: "My 文件夹")
    }

    @MainActor
    func testKindDisplaySortingPreservesRemoteFileIdentityAndMetadata() throws {
        let list = SSHFilePanelFileList()
        defer { list.clear() }
        let outline = try XCTUnwrap(list.documentView as? NSOutlineView)
        let kindColumn = try XCTUnwrap(outline.tableColumn(withIdentifier: .init("KindColumn")))
        let language = try XCTUnwrap(Bundle.main.preferredLocalizations.first)
        XCTAssertTrue(["en", "zh-Hans"].contains(language))
        let kinds: [(String, String, String)] = [
            ("image.PNG", "PNG image", "PNG 图像"),
            ("text.txt", "Text document", "文本文稿"),
            ("doc.pdf", "PDF document", "PDF 文稿"),
            ("movie.mp4", "Video", "视频"),
            ("sound.mp3", "Audio", "音频"),
            ("archive.zip", "Archive", "归档"),
            ("script.lua", "Lua script", "Lua 脚本"),
            ("config.nvim", "Neovim config", "Neovim 配置"),
            ("script.sh", "Shell script", "Shell 脚本"),
            ("source.m", "Objective-C source", "Objective-C 源文件"),
            ("unknown.extension", "Document", "文稿"),
            ("folder", "Folder", "文件夹"),
            ("host", "Host", "主机"),
            ("link", "Alias", "替身")
        ]
        let sshIdentity = identity()
        var originals: [String: RemoteFile] = [:]
        var labels: [String: String] = [:]
        for (index, fixture) in kinds.enumerated() {
            let (name, english, chinese) = fixture
            let kind: RemoteFile.Kind
            switch name {
            case "folder": kind = .folder
            case "host": kind = .host
            case "link": kind = .symlink("../合成目标")
            default: kind = .file(.init(size: index))
            }
            let path = "/synthetic/路径/" + name
            let file = RemoteFile(kind: kind, absolutePath: path,
                                  permissions: .init(r: true, w: false, x: false),
                                  ctime: Date(timeIntervalSince1970: Double(index)),
                                  mtime: Date(timeIntervalSince1970: Double(index + 1)))
            originals[path] = file
            labels[path] = language == "zh-Hans" ? chinese : english
            list.addItem(sshIdentity: sshIdentity, file: file)
        }
        for ascending in [true, false] {
            let previous = outline.sortDescriptors
            outline.sortDescriptors = [NSSortDescriptor(key: "KindColumn", ascending: ascending)]
            list.outlineView(outline, sortDescriptorsDidChange: previous)
            XCTAssertEqual(outline.numberOfRows, kinds.count)
            var displayed: [String] = []
            var nodes: [SSHFilePanelFileList.FileNode] = []
            for row in 0..<outline.numberOfRows {
                let node = try XCTUnwrap(outline.item(atRow: row) as? SSHFilePanelFileList.FileNode)
                let cell = try XCTUnwrap(list.outlineView(outline, viewFor: kindColumn, item: node)
                    as? NSTableCellView)
                let label = try XCTUnwrap(cell.textField?.stringValue)
                XCTAssertEqual(label, labels[node.file.absolutePath])
                XCTAssertEqual(node.file, originals[node.file.absolutePath])
                XCTAssertEqual(node.sshIdentity, sshIdentity)
                XCTAssertEqual(node.pathToParent, "/synthetic/路径")
                displayed.append(label)
                nodes.append(node)
            }
            let expected = labels.values.sorted {
                $0.localizedCaseInsensitiveCompare($1) == (ascending ? .orderedAscending : .orderedDescending)
            }
            XCTAssertEqual(displayed, expected)
            outline.selectRowIndexes(IndexSet([1, 3]), byExtendingSelection: false)
            XCTAssertEqual(list.selectedFiles.map(\.file), [nodes[1].file, nodes[3].file])
        }
    }
}
