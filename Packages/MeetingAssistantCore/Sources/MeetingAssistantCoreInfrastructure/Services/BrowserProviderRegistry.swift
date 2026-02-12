import AppKit
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

    public static func provider(for bundleIdentifier: String) -> BrowserActiveTabURLProviding? {
        let normalizedBundleIdentifier = normalizeBundleIdentifier(bundleIdentifier)

        if let knownProvider = defaultProviders()[normalizedBundleIdentifier] {
            return knownProvider
        }

        guard
            let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
                ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: normalizedBundleIdentifier)
        else {
            return nil
        }

        let applicationName = appURL.deletingPathExtension().lastPathComponent
        let candidates = [BrowserScriptTemplates.chromium, BrowserScriptTemplates.safari]
            .compactMap { BrowserActiveTabURLProvider(applicationName: applicationName, scriptTemplate: $0) }

        guard !candidates.isEmpty else {
            return nil
        }

        return FallbackBrowserActiveTabURLProvider(providers: candidates)
    }

    private static func normalizeBundleIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
