import Foundation
import os.log

public protocol BrowserActiveTabURLProviding {
    func activeTabURL() -> URL?
}

public final class BrowserActiveTabURLProvider: BrowserActiveTabURLProviding {
    private let logger = Logger(subsystem: "MeetingAssistant", category: "BrowserActiveTabURLProvider")
    private let script: NSAppleScript

    public init?(applicationName: String, scriptTemplate: String) {
        let source = String(format: scriptTemplate, applicationName)
        guard let script = NSAppleScript(source: source) else {
            return nil
        }
        self.script = script
    }

    public func activeTabURL() -> URL? {
        var errorInfo: NSDictionary?
        let output = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            logger.debug("AppleScript error: \(errorInfo)")
            return nil
        }

        let urlString = output.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let urlString, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
}

public enum BrowserScriptTemplates {
    public static let safari = "tell application \"%@\" to get URL of current tab of front window"
    public static let chromium = "tell application \"%@\" to get URL of active tab of front window"
}
