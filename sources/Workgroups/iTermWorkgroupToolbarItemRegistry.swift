//
//  iTermWorkgroupToolbarItemRegistry.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 4/23/26.
//

import CoreGraphics
import Foundation

// Metadata catalog for the toolbar tools the user can attach to a
// workgroup session's toolbar. Phase 1 uses this to populate the settings
// UI's item-picker. Phase 2 will add the runtime factory that turns a
// concrete iTermWorkgroupToolbarItem value into a SessionToolbarGeneric-
// View, taking the runtime context (git poller, button delegates, etc.)
// that the settings UI doesn't have access to.
struct iTermWorkgroupToolbarItemMetadata {
    let kind: iTermWorkgroupToolbarItemKind
    let displayName: String
    let hasParameters: Bool          // true for .spacer
    let defaultValue: iTermWorkgroupToolbarItem
}

enum iTermWorkgroupToolbarItemRegistry {
    // Order here is the order the picker UI lists items.
    static let all: [iTermWorkgroupToolbarItemMetadata] = [
        .init(kind: .gitStatus,
              displayName: String(localized: "ui.swift.workgroups.itermworkgrouptoolbaritemregistry.git_status.acdb254d", defaultValue: "Git Status", bundle: .main, comment: "User-facing text in iTermWorkgroupToolbarItemRegistry."),
              hasParameters: false,
              defaultValue: .gitStatus),
        .init(kind: .changedFileSelector,
              displayName: String(localized: "ui.swift.workgroups.itermworkgrouptoolbaritemregistry.changed_file_selector.db51ec3c", defaultValue: "Changed File Selector", bundle: .main, comment: "User-facing text in iTermWorkgroupToolbarItemRegistry."),
              hasParameters: false,
              defaultValue: .changedFileSelector),
        .init(kind: .modeSwitcher,
              displayName: String(localized: "ui.swift.workgroups.itermworkgrouptoolbaritemregistry.peer_mode_switcher.d05e59f9", defaultValue: "Peer Mode Switcher", bundle: .main, comment: "User-facing text in iTermWorkgroupToolbarItemRegistry."),
              hasParameters: false,
              defaultValue: .modeSwitcher),
        .init(kind: .navigation,
              displayName: String(localized: "ui.swift.workgroups.itermworkgrouptoolbaritemregistry.navigation_buttons.c15c6ba1", defaultValue: "Navigation Buttons", bundle: .main, comment: "User-facing text in iTermWorkgroupToolbarItemRegistry."),
              hasParameters: false,
              defaultValue: .navigation(WorkgroupNavigationShortcuts.defaults)),
        .init(kind: .reload,
              displayName: String(localized: "ui.swift.workgroups.itermworkgrouptoolbaritemregistry.reload.bdc090ec", defaultValue: "Reload", bundle: .main, comment: "User-facing text in iTermWorkgroupToolbarItemRegistry."),
              hasParameters: false,
              defaultValue: .reload(WorkgroupToolbarShortcut.reloadDefault)),
        .init(kind: .gitBaseSelector,
              displayName: String(localized: "ui.swift.workgroups.itermworkgrouptoolbaritemregistry.git_base_selector.c7c90c76", defaultValue: "Git Base Selector", bundle: .main, comment: "User-facing text in iTermWorkgroupToolbarItemRegistry."),
              hasParameters: false,
              defaultValue: .gitBaseSelector),
        .init(kind: .autoSendClippingsWhenIdle,
              displayName: String(localized: "ui.swift.workgroups.itermworkgrouptoolbaritemregistry.auto_send_clippings_when_idle.c3ce5c8f", defaultValue: "Auto-Send Clippings When Idle", bundle: .main, comment: "User-facing text in iTermWorkgroupToolbarItemRegistry."),
              hasParameters: false,
              defaultValue: .autoSendClippingsWhenIdle),
        .init(kind: .autoRequestReviewWhenIdle,
              displayName: String(localized: "ui.swift.workgroups.itermworkgrouptoolbaritemregistry.auto_request_review_when_idle.a94cf679", defaultValue: "Auto-Request Review When Idle", bundle: .main, comment: "User-facing text in iTermWorkgroupToolbarItemRegistry."),
              hasParameters: false,
              defaultValue: .autoRequestReviewWhenIdle),
        .init(kind: .spacer,
              displayName: String(localized: "ui.swift.workgroups.itermworkgrouptoolbaritemregistry.spacer.74d47474", defaultValue: "Spacer", bundle: .main, comment: "User-facing text in iTermWorkgroupToolbarItemRegistry."),
              hasParameters: true,
              defaultValue: .spacer(minWidth: 4, maxWidth: 4)),
    ]

    static func metadata(forKind kind: iTermWorkgroupToolbarItemKind) -> iTermWorkgroupToolbarItemMetadata? {
        return all.first(where: { $0.kind == kind })
    }

    static func metadata(for item: iTermWorkgroupToolbarItem) -> iTermWorkgroupToolbarItemMetadata? {
        return metadata(forKind: item.kind)
    }
}
