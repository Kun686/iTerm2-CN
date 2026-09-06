//
//  SSHEndpointException.swift
//  iTerm2
//
//  Created by George Nachman on 7/1/25.
//

enum SSHEndpointException: LocalizedError {
    case connectionClosed
    case fileNotFound
    case internalError  // e.g., non-decodable data from fetch
    case transferCanceled

    var errorDescription: String? {
        get {
            switch self {
            case .connectionClosed:
                return String(localized: "ui.swift.ssh.sshendpointexception.connection_closed.fdb770cf", defaultValue: "Connection closed", bundle: .main, comment: "User-facing text in SSHEndpointException.")
            case .fileNotFound:
                return String(localized: "ui.swift.ssh.sshendpointexception.file_not_found.3521021a", defaultValue: "File not found", bundle: .main, comment: "User-facing text in SSHEndpointException.")
            case .internalError:
                return String(localized: "ui.swift.ssh.sshendpointexception.internal_error.1dac8dea", defaultValue: "Internal error", bundle: .main, comment: "User-facing text in SSHEndpointException.")
            case .transferCanceled:
                return String(localized: "ui.swift.ssh.sshendpointexception.file_transfer_canceled.699d73cf", defaultValue: "File transfer canceled", bundle: .main, comment: "User-facing text in SSHEndpointException.")
            }
        }
    }
}

