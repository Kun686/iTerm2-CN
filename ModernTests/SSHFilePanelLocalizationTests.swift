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
