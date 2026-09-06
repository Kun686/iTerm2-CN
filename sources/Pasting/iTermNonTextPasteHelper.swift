//
//  iTermNonTextPasteHelper.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 3/9/26.
//

import AppKit
import UniformTypeIdentifiers

@objc(iTermNonTextPasteHelperDelegate)
protocol iTermNonTextPasteHelperDelegate: AnyObject {
    func nonTextPasteHelper(_ sender: iTermNonTextPasteHelper, pasteString string: String)
    func nonTextPasteHelperWindow(_ sender: iTermNonTextPasteHelper) -> NSWindow?
    func nonTextPasteHelperCanUpload(_ sender: iTermNonTextPasteHelper) -> Bool
    func nonTextPasteHelper(_ sender: iTermNonTextPasteHelper, uploadFiles paths: [String])
    func nonTextPasteHelper(_ sender: iTermNonTextPasteHelper, uploadFileAndPastePath path: String)
}

@objc(iTermNonTextPasteHelper)
class iTermNonTextPasteHelper: NSObject {
    @objc weak var delegate: iTermNonTextPasteHelperDelegate?

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    @objc static func pasteboardHasNonTextContent() -> Bool {
        let pb = NSPasteboard.general
        return pb.hasFileURLs() || pb.hasRawImageData()
    }

    @objc func pasteNonTextContent() -> Bool {
        DLog("pasteNonTextContent called")
        let pb = NSPasteboard.general
        if pb.hasFileURLs() {
            guard let paths = pb.filePaths(), !paths.isEmpty else {
                RLog("hasFileURLs but no paths found")
                return false
            }
            RLog("Handling file paste with \(paths.count) paths")
            return handleFilePaste(paths)
        } else if pb.hasRawImageData() {
            guard let imageData = pb.rawImageData() else {
                RLog("hasRawImageData but rawImageData() returned nil")
                return false
            }
            // Try to determine the file extension, but proceed even if we can't
            var fileExtension: String? = nil
            if let utType = pb.rawImageDataUTType(),
               let type = UTType(utType) {
                fileExtension = type.preferredFilenameExtension
            }
            RLog("Handling image data paste: \(imageData.count) bytes, extension=\(fileExtension ?? "unknown")")
            return handleImageDataPaste(imageData: imageData, fileExtension: fileExtension)
        }
        DLog("No non-text content found on pasteboard")
        return false
    }

    @objc func showPasteOptionsForFiles(_ files: [String]) {
        _ = handleFilePaste(files)
    }

    private enum FilePasteAction: String {
        case pastePath = "Paste Path"
        case pastePaths = "Paste Paths"
        case pasteBase64 = "Paste Base64-Encoded Contents"
        case pasteBase64Archive = "Paste Base64-Encoded Archive (tar.gz)"
        case pasteAsText = "Paste as Text"
        case upload = "Upload"
        case uploadAndPastePath = "Upload and Paste Path"
        case cancel = "Cancel"

        var localizedTitle: String {
            switch self {
            case .pastePath:
                return String(localized: "ui.swift.pasting.itermnontextpastehelper.paste_path.d1469211", defaultValue: "Paste Path", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
            case .pastePaths:
                return String(localized: "ui.swift.pasting.itermnontextpastehelper.paste_paths.de9285ea", defaultValue: "Paste Paths", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
            case .pasteBase64:
                return String(localized: "ui.swift.pasting.itermnontextpastehelper.paste_base64_encoded_contents.c81e6080", defaultValue: "Paste Base64-Encoded Contents", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
            case .pasteBase64Archive:
                return String(localized: "ui.swift.pasting.itermnontextpastehelper.paste_base64_encoded_archive_tar_gz.428692a0", defaultValue: "Paste Base64-Encoded Archive (tar.gz)", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
            case .pasteAsText:
                return String(localized: "ui.swift.pasting.itermnontextpastehelper.paste_as_text.38b74cec", defaultValue: "Paste as Text", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
            case .upload:
                return String(localized: "ui.swift.pasting.itermnontextpastehelper.upload.865e89de", defaultValue: "Upload", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
            case .uploadAndPastePath:
                return String(localized: "ui.swift.pasting.itermnontextpastehelper.upload_and_paste_path.6906be67", defaultValue: "Upload and Paste Path", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
            case .cancel:
                return String(localized: "ui.swift.pasting.itermnontextpastehelper.cancel.19766ed6", defaultValue: "Cancel", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
            }
        }
    }

    private func handleFilePaste(_ paths: [String]) -> Bool {
        guard !paths.isEmpty else {
            return false
        }

        // Verify files exist
        let existingPaths = paths.filter { FileManager.default.fileExists(atPath: $0) }
        if existingPaths.isEmpty {
            showError(String(localized: "ui.swift.pasting.itermnontextpastehelper.the_copied_file_no_longer_exists.22541a18", defaultValue: "The copied file no longer exists.", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper."))
            return true
        }
        if existingPaths.count < paths.count {
            let missing = paths.count - existingPaths.count
            showError(String(localized: "ui.swift.pasting.itermnontextpastehelper.0_of_1_files_no_longer_exist_proceeding.58f31189", defaultValue: "\(missing) of \(paths.count) files no longer exist. Proceeding with remaining files.", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper."))
        }

        let singleFile = existingPaths.count == 1
        let canUpload = delegate?.nonTextPasteHelperCanUpload(self) ?? false
        let isDirectory = singleFile && isDirectoryPath(existingPaths.first!)
        let canPasteAsText = singleFile && !isDirectory && firstFileIsValidUTF8(existingPaths)

        RLog("handleFilePaste: singleFile=\(singleFile) canUpload=\(canUpload) isDirectory=\(isDirectory) canPasteAsText=\(canPasteAsText)")

        // Build actions list and track what each index means
        var actions = [FilePasteAction]()
        if singleFile {
            if canUpload {
                // Remote host: offer upload options and base64
                if !isDirectory {
                    actions.append(.uploadAndPastePath)
                }
                actions.append(.upload)
                if isDirectory {
                    actions.append(.pasteBase64Archive)
                } else {
                    actions.append(.pasteBase64)
                }
            } else {
                // Local host: offer path and base64 options
                actions.append(.pastePath)
                if isDirectory {
                    actions.append(.pasteBase64Archive)
                } else {
                    actions.append(.pasteBase64)
                    if canPasteAsText {
                        actions.append(.pasteAsText)
                    }
                }
            }
        } else {
            // Multiple files
            if canUpload {
                actions.append(.upload)
            }
            actions.append(.pastePaths)
        }
        actions.append(.cancel)

        DLog("handleFilePaste: actions=\(actions.map { $0.rawValue })")

        // Build description of files for the dialog
        let fileDescription = descriptionForFiles(existingPaths, isDirectory: isDirectory)

        let warning = iTermWarning()
        warning.title = String(localized: "ui.swift.pasting.itermnontextpastehelper.how_would_you_like_to_paste_0.b66b5bc3", defaultValue: "How would you like to paste \(fileDescription)?", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
        warning.actionLabels = actions.map { $0.localizedTitle }
        warning.identifier = singleFile ? "NoSyncPasteNonTextFile" : "NoSyncPasteNonTextFiles"
        warning.warningType = .kiTermWarningTypePermanentlySilenceable
        warning.heading = isDirectory ? String(localized: "ui.swift.pasting.itermnontextpastehelper.paste_folder.983be332", defaultValue: "Paste Folder", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.") : (singleFile ? String(localized: "ui.swift.pasting.itermnontextpastehelper.paste_file.b0f37197", defaultValue: "Paste File", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.") : String(localized: "ui.swift.pasting.itermnontextpastehelper.paste_files.31c633b2", defaultValue: "Paste Files", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper."))
        warning.cancelLabel = FilePasteAction.cancel.localizedTitle
        warning.window = delegate?.nonTextPasteHelperWindow(self)

        warning.runModalAsync { [weak self] selection, _ in
            guard let self = self else {
                DLog("handleFilePaste: self was deallocated")
                return
            }
            let index = self.selectionToIndex(selection)
            RLog("handleFilePaste: user selected index \(index)")
            guard index >= 0 && index < actions.count else {
                RLog("handleFilePaste: invalid selection index")
                return
            }

            switch actions[index] {
            case .pastePath:
                DLog("handleFilePaste: pastePath")
                self.delegate?.nonTextPasteHelper(self, pasteString: existingPaths.first!.quotedStringForPaste())
            case .pastePaths:
                DLog("handleFilePaste: pastePaths")
                let escapedPaths = existingPaths.map { $0.quotedStringForPaste() }.joined(separator: " ")
                self.delegate?.nonTextPasteHelper(self, pasteString: escapedPaths)
            case .pasteBase64:
                DLog("handleFilePaste: pasteBase64")
                self.pasteBase64EncodedContents(of: existingPaths.first!)
            case .pasteBase64Archive:
                DLog("handleFilePaste: pasteBase64Archive")
                self.pasteBase64EncodedArchive(of: existingPaths.first!)
            case .pasteAsText:
                DLog("handleFilePaste: pasteAsText")
                self.pasteFileAsText(existingPaths.first!)
            case .upload:
                DLog("handleFilePaste: upload")
                self.delegate?.nonTextPasteHelper(self, uploadFiles: existingPaths)
            case .uploadAndPastePath:
                DLog("handleFilePaste: uploadAndPastePath")
                self.delegate?.nonTextPasteHelper(self, uploadFileAndPastePath: existingPaths.first!)
            case .cancel:
                DLog("handleFilePaste: cancelled")
                break
            }
        }
        return true
    }

    private func descriptionForFiles(_ paths: [String], isDirectory: Bool = false) -> String {
        if paths.count == 1 {
            let filename = (paths.first! as NSString).lastPathComponent
            let prefix = isDirectory ? String(localized: "ui.swift.pasting.itermnontextpastehelper.the_folder.c20f1852", defaultValue: " the folder ", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.") : ""
            return "\(prefix)\u{201C}\(filename)\u{201D}"
        } else if paths.count <= 3 {
            let filenames = paths.map { "\u{201C}\(($0 as NSString).lastPathComponent)\u{201D}" }
            return filenames.joined(separator: String(localized: "ui.swift.pasting.itermnontextpastehelper.symbol.0a07f659", defaultValue: ", ", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper."))
        } else {
            let first = (paths.first! as NSString).lastPathComponent
            return String(localized: "ui.swift.pasting.itermnontextpastehelper.0_and_1_other_files.e643b6d9", defaultValue: "\u{201C}\(first)\u{201D} and \(paths.count - 1) other files", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
        }
    }

    private func isDirectoryPath(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    private func selectionToIndex(_ selection: iTermWarningSelection) -> Int {
        switch selection {
        case .kiTermWarningSelection0: return 0
        case .kiTermWarningSelection1: return 1
        case .kiTermWarningSelection2: return 2
        case .kiTermWarningSelection3: return 3
        case .kiTermWarningSelection4: return 4
        case .kiTermWarningSelection5: return 5
        case .kiTermWarningSelection6: return 6
        default: return -1
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = String(localized: "ui.swift.pasting.itermnontextpastehelper.paste_failed.3b3af9fe", defaultValue: "Paste Failed", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "ui.swift.pasting.itermnontextpastehelper.ok.565339bc", defaultValue: "OK", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper."))
        if let window = delegate?.nonTextPasteHelperWindow(self) {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    private enum ImagePasteAction: String {
        case saveTempAndPastePath = "Save to Temp File and Paste Path"
        case pasteBase64 = "Paste Base64-Encoded Contents"
        case upload = "Upload"
        case uploadAndPastePath = "Upload and Paste Path"
        case cancel = "Cancel"

        var localizedTitle: String {
            switch self {
            case .saveTempAndPastePath:
                return String(localized: "ui.swift.pasting.itermnontextpastehelper.save_to_temp_file_and_paste_path.d67a6865", defaultValue: "Save to Temp File and Paste Path", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
            case .pasteBase64:
                return String(localized: "ui.swift.pasting.itermnontextpastehelper.paste_base64_encoded_contents.c81e6080", defaultValue: "Paste Base64-Encoded Contents", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
            case .upload:
                return String(localized: "ui.swift.pasting.itermnontextpastehelper.upload.865e89de", defaultValue: "Upload", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
            case .uploadAndPastePath:
                return String(localized: "ui.swift.pasting.itermnontextpastehelper.upload_and_paste_path.6906be67", defaultValue: "Upload and Paste Path", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
            case .cancel:
                return String(localized: "ui.swift.pasting.itermnontextpastehelper.cancel.19766ed6", defaultValue: "Cancel", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
            }
        }
    }

    private func handleImageDataPaste(imageData: Data, fileExtension: String?) -> Bool {
        DLog("handleImageDataPaste: \(imageData.count) bytes, extension=\(fileExtension ?? "nil")")
        let canUpload = delegate?.nonTextPasteHelperCanUpload(self) ?? false
        let sizeDescription = ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file)
        let typeDescription = fileExtension.map { imageTypeDescription($0) } ?? String(localized: "ui.swift.pasting.itermnontextpastehelper.some.a6b46dd0", defaultValue: "some", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")

        DLog("handleImageDataPaste: canUpload=\(canUpload)")

        // Build actions based on whether we can upload and whether we know the file type
        var actions = [ImagePasteAction]()
        if fileExtension != nil {
            if canUpload {
                actions.append(.uploadAndPastePath)
                actions.append(.upload)
            } else {
                actions.append(.saveTempAndPastePath)
            }
        }
        actions.append(.pasteBase64)
        actions.append(.cancel)

        DLog("handleImageDataPaste: actions=\(actions.map { $0.rawValue })")

        let warning = iTermWarning()
        warning.title = String(localized: "ui.swift.pasting.itermnontextpastehelper.the_clipboard_contains_0_image_data_1_how.52bb0d4c", defaultValue: "The clipboard contains \(typeDescription) image data (\(sizeDescription)). How would you like to paste it?", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
        warning.actionLabels = actions.map { $0.localizedTitle }
        warning.identifier = canUpload ? "NoSyncPasteImageDataRemote" : "NoSyncPasteImageData"
        warning.warningType = .kiTermWarningTypePermanentlySilenceable
        warning.heading = String(localized: "ui.swift.pasting.itermnontextpastehelper.paste_image.dfb9095f", defaultValue: "Paste Image", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
        warning.cancelLabel = ImagePasteAction.cancel.localizedTitle
        warning.window = delegate?.nonTextPasteHelperWindow(self)

        warning.runModalAsync { [weak self] selection, _ in
            guard let self = self else {
                DLog("handleImageDataPaste: self was deallocated")
                return
            }
            let index = self.selectionToIndex(selection)
            RLog("handleImageDataPaste: user selected index \(index)")
            guard index >= 0 && index < actions.count else {
                RLog("handleImageDataPaste: invalid selection index")
                return
            }

            switch actions[index] {
            case .saveTempAndPastePath:
                DLog("handleImageDataPaste: saveTempAndPastePath")
                self.saveTempFileAndPastePath(imageData: imageData, fileExtension: fileExtension!)
            case .pasteBase64:
                DLog("handleImageDataPaste: pasteBase64")
                let base64 = (imageData as NSData).stringWithBase64Encoding(withLineBreak: "\r")
                self.pasteBase64WithConfirmationIfNeeded(base64)
            case .upload:
                DLog("handleImageDataPaste: upload")
                self.uploadImageData(imageData, fileExtension: fileExtension!, pastePath: false)
            case .uploadAndPastePath:
                DLog("handleImageDataPaste: uploadAndPastePath")
                self.uploadImageData(imageData, fileExtension: fileExtension!, pastePath: true)
            case .cancel:
                DLog("handleImageDataPaste: cancelled")
                break
            }
        }
        return true
    }

    private func uploadImageData(_ imageData: Data, fileExtension: String, pastePath: Bool) {
        DLog("uploadImageData: \(imageData.count) bytes, extension=\(fileExtension), pastePath=\(pastePath)")
        guard let tempPath = saveImageToTempFile(imageData: imageData, fileExtension: fileExtension) else {
            RLog("uploadImageData: failed to save temp file")
            return
        }
        if pastePath {
            DLog("uploadImageData: calling delegate uploadFileAndPastePath")
            delegate?.nonTextPasteHelper(self, uploadFileAndPastePath: tempPath)
        } else {
            DLog("uploadImageData: calling delegate uploadFiles")
            delegate?.nonTextPasteHelper(self, uploadFiles: [tempPath])
        }
    }

    private func saveImageToTempFile(imageData: Data, fileExtension: String) -> String? {
        DLog("saveImageToTempFile: \(imageData.count) bytes, extension=\(fileExtension)")
        guard let tempDir = FileManager.default.it_temporaryDirectory() else {
            RLog("saveImageToTempFile: failed to get temporary directory")
            showError(String(localized: "ui.swift.pasting.itermnontextpastehelper.could_not_create_temporary_directory.b5e94574", defaultValue: "Could not create temporary directory.", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper."))
            return nil
        }

        let timestamp = Self.timestampFormatter.string(from: Date())
        let filename = "pasted-image-\(timestamp).\(fileExtension)"
        let tempPath = (tempDir as NSString).appendingPathComponent(filename)

        do {
            try imageData.write(to: URL(fileURLWithPath: tempPath))
            DLog("saveImageToTempFile: saved to \(tempPath)")
            return tempPath
        } catch {
            RLog("saveImageToTempFile: failed to write: \(error)")
            showError(String(localized: "ui.swift.pasting.itermnontextpastehelper.could_not_save_image_to_temporary_file_0.f09c505b", defaultValue: "Could not save image to temporary file: \(error.localizedDescription)", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper."))
            return nil
        }
    }

    private func imageTypeDescription(_ fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "png": return String(localized: "ui.swift.pasting.itermnontextpastehelper.a_png.f0a92ace", defaultValue: "a PNG", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
        case "jpg", "jpeg": return String(localized: "ui.swift.pasting.itermnontextpastehelper.a_jpeg.b902cb24", defaultValue: "a JPEG", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
        case "gif": return String(localized: "ui.swift.pasting.itermnontextpastehelper.a_gif.90b2ec5c", defaultValue: "a GIF", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
        case "tiff", "tif": return String(localized: "ui.swift.pasting.itermnontextpastehelper.a_tiff.c1cfeeea", defaultValue: "a TIFF", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
        case "bmp": return String(localized: "ui.swift.pasting.itermnontextpastehelper.a_bmp.f5185165", defaultValue: "a BMP", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
        case "webp": return String(localized: "ui.swift.pasting.itermnontextpastehelper.a_webp.e845f50c", defaultValue: "a WebP", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
        case "heic": return String(localized: "ui.swift.pasting.itermnontextpastehelper.a_heic.9abea504", defaultValue: "a HEIC", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
        default: return String(localized: "ui.swift.pasting.itermnontextpastehelper.an.ea325d76", defaultValue: "an", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
        }
    }

    private func firstFileIsValidUTF8(_ paths: [String]) -> Bool {
        guard let firstPath = paths.first,
              let data = FileManager.default.contents(atPath: firstPath) else {
            return false
        }
        return String(data: data, encoding: .utf8) != nil
    }

    private func pasteBase64EncodedContents(of path: String) {
        DLog("pasteBase64EncodedContents: \(path)")
        guard let data = FileManager.default.contents(atPath: path) else {
            RLog("pasteBase64EncodedContents: failed to read file")
            let filename = (path as NSString).lastPathComponent
            showError(String(localized: "ui.swift.pasting.itermnontextpastehelper.could_not_read_file_0.d3f052b2", defaultValue: "Could not read file \u{201C}\(filename)\u{201D}.", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper."))
            return
        }
        DLog("pasteBase64EncodedContents: read \(data.count) bytes")
        let base64 = (data as NSData).stringWithBase64Encoding(withLineBreak: "\r")
        pasteBase64WithConfirmationIfNeeded(base64)
    }

    private func pasteBase64EncodedArchive(of folderPath: String) {
        DLog("pasteBase64EncodedArchive: \(folderPath)")
        let folderName = (folderPath as NSString).lastPathComponent
        let parentPath = (folderPath as NSString).deletingLastPathComponent

        do {
            // Create archive with just the folder name, relative to parent
            let data = try NSData(tgzContainingFiles: [folderName],
                                  relativeToPath: parentPath,
                                  includeExtendedAttrs: false)
            DLog("pasteBase64EncodedArchive: created archive of \(data.count) bytes")
            let base64 = data.stringWithBase64Encoding(withLineBreak: "\r")
            pasteBase64WithConfirmationIfNeeded(base64)
        } catch {
            RLog("pasteBase64EncodedArchive: failed to create archive: \(error)")
            showError(String(localized: "ui.swift.pasting.itermnontextpastehelper.could_not_create_archive_of_0_1.a325b315", defaultValue: "Could not create archive of \u{201C}\(folderName)\u{201D}: \(error.localizedDescription)", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper."))
        }
    }

    private func pasteBase64WithConfirmationIfNeeded(_ base64: String) {
        let threshold = 10_000
        if base64.count <= threshold {
            delegate?.nonTextPasteHelper(self, pasteString:base64)
            return
        }

        let warning = iTermWarning()
        warning.title = String(localized: "ui.swift.pasting.itermnontextpastehelper.ok_to_paste_0_bytes_of_base64_encoded.7ed27d72", defaultValue: "OK to paste \(base64.count.formatted()) bytes of base64-encoded data?", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
        warning.actionLabels = [String(localized: "ui.swift.pasting.itermnontextpastehelper.ok.565339bc", defaultValue: "OK", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper."), ImagePasteAction.cancel.localizedTitle]
        warning.identifier = "NoSyncPasteLargeBase64"
        warning.warningType = .kiTermWarningTypePermanentlySilenceable
        warning.heading = String(localized: "ui.swift.pasting.itermnontextpastehelper.large_paste.97d7e880", defaultValue: "Large Paste", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper.")
        warning.cancelLabel = ImagePasteAction.cancel.localizedTitle
        warning.window = delegate?.nonTextPasteHelperWindow(self)

        warning.runModalAsync { [weak self] selection, _ in
            guard let self = self else { return }
            if selection == .kiTermWarningSelection0 {
                self.delegate?.nonTextPasteHelper(self, pasteString: base64)
            }
        }
    }

    private func pasteFileAsText(_ path: String) {
        let filename = (path as NSString).lastPathComponent
        guard let data = FileManager.default.contents(atPath: path) else {
            showError(String(localized: "ui.swift.pasting.itermnontextpastehelper.could_not_read_file_0.d3f052b2", defaultValue: "Could not read file \u{201C}\(filename)\u{201D}.", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper."))
            return
        }
        guard let text = String(data: data, encoding: .utf8) else {
            showError(String(localized: "ui.swift.pasting.itermnontextpastehelper.file_0_is_not_valid_utf_8_text.a0c08656", defaultValue: "File \u{201C}\(filename)\u{201D} is not valid UTF-8 text.", bundle: .main, comment: "User-facing text in iTermNonTextPasteHelper."))
            return
        }
        delegate?.nonTextPasteHelper(self, pasteString: text)
    }

    private func saveTempFileAndPastePath(imageData: Data, fileExtension: String) {
        DLog("saveTempFileAndPastePath: \(imageData.count) bytes, extension=\(fileExtension)")
        guard let tempPath = saveImageToTempFile(imageData: imageData, fileExtension: fileExtension) else {
            DLog("saveTempFileAndPastePath: failed to save temp file")
            return
        }
        let escapedPath = tempPath.quotedStringForPaste()
        DLog("saveTempFileAndPastePath: pasting path \(escapedPath)")
        delegate?.nonTextPasteHelper(self, pasteString: escapedPath)
    }
}
