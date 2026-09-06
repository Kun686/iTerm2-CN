//
//  NSFileManager+iTerm.swift
//  iTerm2
//
//  Created by George Nachman on 2/5/25.
//

extension FileManager {
    @objc
    func it_promptToCreateEnclosingDirectory(for filePath: String,
                                             title: String,
                                             identifier: String,
                                             window: NSWindow?) -> Bool {
        let directoryPath = (filePath as NSString).deletingLastPathComponent
        var isDir: ObjCBool = false

        if fileExists(atPath: directoryPath, isDirectory: &isDir) && isDir.boolValue {
            return true
        }
        let selection = iTermWarning.show(withTitle: String(localized: "ui.swift.categories.nsfilemanager_iterm.would_you_like_to_create_the_directory_at.17345ba4", defaultValue: "Would you like to create the directory at \(directoryPath)?", bundle: .main, comment: "User-facing text in NSFileManager+iTerm."),
                                          actions: [String(localized: "ui.swift.categories.nsfilemanager_iterm.ok.565339bc", defaultValue: "OK", bundle: .main, comment: "User-facing text in NSFileManager+iTerm."), String(localized: "ui.swift.categories.nsfilemanager_iterm.cancel.19766ed6", defaultValue: "Cancel", bundle: .main, comment: "User-facing text in NSFileManager+iTerm.")],
                                          accessory: nil,
                                          identifier: "CreateDirectory_" + identifier,
                                          silenceable: .kiTermWarningTypePermanentlySilenceable,
                                          heading: title,
                                          window: window
                                          )
        if selection == .kiTermWarningSelection0 {
            do {
                try createDirectory(atPath: directoryPath,
                                    withIntermediateDirectories: true,
                                    attributes: nil)
                return true
            } catch {
                let selection = iTermWarning.show(withTitle: String(localized: "ui.swift.categories.nsfilemanager_iterm.failed_to_create_0_1.138c7e09", defaultValue: "Failed to create \(directoryPath):\n\n\(error.localizedDescription)", bundle: .main, comment: "User-facing text in NSFileManager+iTerm."),
                                                  actions: [String(localized: "ui.swift.categories.nsfilemanager_iterm.try_again.df0fe9e0", defaultValue: "Try Again", bundle: .main, comment: "User-facing text in NSFileManager+iTerm."), String(localized: "ui.swift.categories.nsfilemanager_iterm.cancel.19766ed6", defaultValue: "Cancel", bundle: .main, comment: "User-facing text in NSFileManager+iTerm.")],
                                                  accessory: nil,
                                                  identifier: nil,
                                                  silenceable: .kiTermWarningTypePersistent,
                                                  heading: title,
                                                  window: window)
                if selection == .kiTermWarningSelection0 {
                    return it_promptToCreateEnclosingDirectory(for: filePath,
                                                               title: title,
                                                               identifier: identifier,
                                                               window: window)
                }
            }
        }
        return false
    }
}

extension FileManager {
    struct RecursiveRegularFileIterator: Sequence, IteratorProtocol {
        private let enumerator: FileManager.DirectoryEnumerator
        private let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]

        init?(directoryURL: URL, fileManager: FileManager) {
            guard let enumerator =
                    fileManager.enumerator(
                        at: directoryURL,
                        includingPropertiesForKeys: Array(resourceKeys),
                        options: [],
                        errorHandler: nil
                    )
            else {
                return nil
            }

            self.enumerator = enumerator
        }

        mutating func next() -> URL? {
            while let fileURL = enumerator.nextObject() as? URL {
                do {
                    let values = try fileURL.resourceValues(forKeys: resourceKeys)
                    if values.isRegularFile == true {
                        return fileURL
                    }
                } catch {
                }
            }

            return nil
        }
    }

    func recursiveRegularFileIterator(at url: URL) -> RecursiveRegularFileIterator? {
        return RecursiveRegularFileIterator(directoryURL: url, fileManager: self)
    }

    func realPath(of path: String) -> String {
        let buf = UnsafeMutablePointer<Int8>.allocate(
            capacity: Int(PATH_MAX)
        )
        defer { buf.deallocate() }

        guard realpath(path, buf) != nil else {
            return path
        }

        return String(cString: buf)
    }
}
