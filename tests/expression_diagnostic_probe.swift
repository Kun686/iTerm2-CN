// Real error constructors and table formatter; no evaluator or application.
import Foundation

let probeBundle = Bundle(path: CommandLine.arguments[1])!

// TABLE-FORMATTER

class iTermHistogram: NSObject {
    // HISTOGRAM-FORMATTER
}

func errors() -> [NSError] {
    let colorString = "invalid 用户 %@"
    // ERROR-CONSTRUCTORS
}

let formatter = iTermHistogram.tabularFormatterTime
formatter.add(row: ["0.00 µs", "##", "2.00 µs", "3", "1.00 µs", "1.00 µs",
                    "2.00 µs", "3.00 µs", "Synthetic trigger 用户"])
let rows: [[String: Any]] = errors().map {
    ["domain": $0.domain, "code": $0.code, "userInfo": $0.userInfo]
}
let result: [String: Any] = ["errors": rows, "table": formatter.formattedAsText()]
let data = try JSONSerialization.data(withJSONObject: result)
FileHandle.standardOutput.write(data)
