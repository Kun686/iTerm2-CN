// Synthetic rows exercise real counting/filtering and display expressions.
// No AppKit window, PTY, preferences, status notification or network is used.
import Foundation

let probeBundle: Bundle = {
    guard CommandLine.arguments.count == 2,
          let bundle = Bundle(path: CommandLine.arguments[1]) else { exit(2) }
    return bundle
}()

final class CockpitRow {
    enum Identity: Hashable { case session(String) }
    enum Kind { case session, window, buriedRoot, workgroup, tab, group }
    let identity: Identity
    let kind: Kind = .session
    let title: String
    let status: String?
    var children: [CockpitRow] = []
    init(id: Int, status: String?) {
        identity = .session(String(id))
        title = String(id)
        self.status = status
    }
}

struct StatusPrioritySettings {
    static let shared = StatusPrioritySettings()
    func priority(for status: String) -> Int { 0 }
}

final class CockpitWindowController {
    private var statusFilter: String?
    private var statusCounts: [String: Int] = [:]
    private var statusFilterItems: [(title: String, status: String?)] = []
    // COCKPIT-PRODUCTION-MEMBERS

    func snapshot(_ inputs: [String?]) -> [String: Any] {
        let rows = inputs.enumerated().map { CockpitRow(id: $0.offset, status: $0.element) }
        let rebuiltRoots = rows
        let freshCache = Dictionary(uniqueKeysWithValues: rows.map { ($0.identity, $0) })
        // COCKPIT-PRE-FILTER-COUNTS
        // COCKPIT-FILTER-ITEMS
        var bucketed: [String: [CockpitRow]] = [:]
        for row in rows {
            let status = row.status.map { (text: $0, color: "synthetic") }
            // COCKPIT-BUCKET-KEY
            bucketed[bucketKey, default: []].append(row)
        }
        let groups: [[String: Any]] = bucketed.keys.sorted().map { status in
            let members = bucketed[status] ?? []
            // COCKPIT-GROUP-LABEL
            return ["key": status, "label": label, "ids": members.map { $0.title }]
        }
        var selected: [String: [String]] = [:]
        for key in statusCounts.keys {
            var keptCache = freshCache
            selected[key] = Self.prune(rows, needle: "", status: key,
                                      keptCache: &keptCache).map { $0.title }
        }
        return ["sentinel": Self.noStatusLabel, "counts": statusCounts,
                "groups": groups, "selected": selected,
                "filters": statusFilterItems.map {
                    ["title": $0.title, "key": $0.status as Any? ?? NSNull()]
                }, "sentinelSortLast": statusSortKey("No status").0 == Int.max]
    }
}

let fixtures: [[String?]] = [
    [], [nil, nil, "无状态", "Waiting"],
    [nil, "No status", "无状态", "Custom %@ 用户"],
    ["No status"], [nil], ["", "无状态", "Custom %@ 用户"]
]
let snapshots = fixtures.map { CockpitWindowController().snapshot($0) }
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: snapshots))
