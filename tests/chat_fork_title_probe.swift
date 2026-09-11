// Executes the actual title-construction block with synthetic titles and time.
// No chat database, window, preferences, or AI connection is opened.
import Foundation

guard CommandLine.arguments.count >= 4,
      let probeBundle = Bundle(path: CommandLine.arguments[1]) else { exit(2) }

func forkTitle(_ originalTitle: String, nowString: String) -> String {
    // FORK-TITLE-PRODUCTION
    return title
}

let titles = CommandLine.arguments.dropFirst(3).map {
    forkTitle($0, nowString: CommandLine.arguments[2])
}
do {
    let data = try JSONSerialization.data(withJSONObject: titles, options: [.sortedKeys])
    FileHandle.standardOutput.write(data)
} catch {
    FileHandle.standardError.write(Data("Cannot serialize title probe result\n".utf8))
    exit(3)
}
