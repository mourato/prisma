import Foundation

public enum BrowserProviderRegistry {
    public static func defaultProviders() -> [String: BrowserActiveTabURLProviding] {
        let providers: [String: BrowserActiveTabURLProviding?] = [
            "com.apple.Safari": BrowserActiveTabURLProvider(
                applicationName: "Safari",
                scriptTemplate: BrowserScriptTemplates.safari
            ),
            "com.google.Chrome": BrowserActiveTabURLProvider(
                applicationName: "Google Chrome",
                scriptTemplate: BrowserScriptTemplates.chromium
            ),
            "com.microsoft.edgemac": BrowserActiveTabURLProvider(
                applicationName: "Microsoft Edge",
                scriptTemplate: BrowserScriptTemplates.chromium
            ),
        ]

        var resolved: [String: BrowserActiveTabURLProviding] = [:]
        for (bundleId, provider) in providers {
            if let provider {
                resolved[normalizeBundleIdentifier(bundleId)] = provider
            }
        }
        return resolved
    }

    private static func normalizeBundleIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
