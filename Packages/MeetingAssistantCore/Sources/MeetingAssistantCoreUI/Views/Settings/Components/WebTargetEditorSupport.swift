import Foundation

struct WebTargetBrowserOption: Identifiable {
    let name: String
    let bundleIdentifier: String

    var id: String {
        bundleIdentifier
    }
}

enum WebTargetEditorSupport {
    static let browserOptions: [WebTargetBrowserOption] = [
        WebTargetBrowserOption(name: "Safari", bundleIdentifier: "com.apple.Safari"),
        WebTargetBrowserOption(name: "Google Chrome", bundleIdentifier: "com.google.Chrome"),
        WebTargetBrowserOption(name: "Microsoft Edge", bundleIdentifier: "com.microsoft.edgemac"),
    ]

    static var defaultBrowserBundleIdentifiers: [String] {
        browserOptions.map(\.bundleIdentifier)
    }

    static func browserDisplayName(for bundleIdentifier: String) -> String {
        browserOptions.first(where: { $0.bundleIdentifier == bundleIdentifier })?.name ?? bundleIdentifier
    }

    static func parseURLPatterns(from text: String) -> [String] {
        text
            .replacingOccurrences(of: ",", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
