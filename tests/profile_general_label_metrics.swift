import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else { exit(2) }
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let xib = try XMLDocument(contentsOf: root.appendingPathComponent(
    "sources/Settings/Base.lproj/PreferencePanel.xib"))
let catalogData = try Data(contentsOf: root.appendingPathComponent(
    "sources/Settings/PreferencePanel.xcstrings"))
guard let catalog = try JSONSerialization.jsonObject(with: catalogData) as? [String: Any],
      let strings = catalog["strings"] as? [String: [String: Any]] else { exit(2) }

let labels: [(view: String, cell: String, right: Double)] = [
    ("Xzz-Fo-TWV", "Bp6-8q-9J8", 121),
    ("iet-o6-fEv", "cKG-uJ-P2E", 45)
]
var measurements: [[String: Any]] = []
var passed = true
for label in labels {
    guard let frame = try xib.nodes(forXPath: "//textField[@id='\(label.view)']/rect[@key='frame']").first as? XMLElement,
          let x = Double(frame.attribute(forName: "x")?.stringValue ?? ""),
          let width = Double(frame.attribute(forName: "width")?.stringValue ?? ""),
          let localizations = strings[label.cell + ".title"]?["localizations"] as? [String: [String: Any]] else {
        exit(2)
    }
    for language in ["en", "zh-Hans"] {
        guard let unit = localizations[language]?["stringUnit"] as? [String: Any],
              let title = unit["value"] as? String else { exit(2) }
        let textWidth = ceil((title as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
        ]).width)
        // NSTextField has two-point horizontal text insets.
        let requiredWidth = textWidth + 4
        let fits = width >= requiredWidth && abs(x + width - label.right) < 0.01 && x >= 0
        passed = passed && fits
        measurements.append(["cell": label.cell, "language": language,
                             "width": width, "requiredWidth": requiredWidth,
                             "rightEdgePreserved": abs(x + width - label.right) < 0.01,
                             "passed": fits])
    }
}
let result = try JSONSerialization.data(withJSONObject: measurements, options: [.sortedKeys])
FileHandle.standardOutput.write(result)
FileHandle.standardOutput.write(Data("\n".utf8))
exit(passed ? 0 : 1)
