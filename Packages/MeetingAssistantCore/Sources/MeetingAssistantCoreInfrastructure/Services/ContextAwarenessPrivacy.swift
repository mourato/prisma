import Foundation

public enum ContextAwarenessPrivacy {
    private enum RedactionPattern: String, CaseIterable {
        case email = #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#
        case url = #"\b(?:https?://|www\.)\S+\b"#
        case secretToken = #"\b(?:sk|rk|pk|ghp|xoxb|xoxp|AIza)[-_A-Za-z0-9]{12,}\b"#
        case longNumericSequence = #"\b(?:\d[ -]?){13,19}\b"#
    }

    nonisolated private static let maxExcludedBundleIDs = 100

    nonisolated private static let defaultSensitiveBundleIDs: Set<String> = [
        "com.apple.keychainaccess",
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.dashlane.dashlanephonefinal",
        "com.lastpass.LastPass",
        "proton.pass.mac",
    ]

    nonisolated private static let replacementByPattern: [RedactionPattern: String] = [
        .email: "[REDACTED_EMAIL]",
        .url: "[REDACTED_URL]",
        .secretToken: "[REDACTED_SECRET]",
        .longNumericSequence: "[REDACTED_NUMBER]",
    ]

    nonisolated private static let redactionOrder: [RedactionPattern] = [.secretToken, .email, .url, .longNumericSequence]
    nonisolated private static let compiledRedactionRegexes: [RedactionPattern: NSRegularExpression] = {
        var compiled: [RedactionPattern: NSRegularExpression] = [:]
        for pattern in RedactionPattern.allCases {
            if let regex = try? NSRegularExpression(pattern: pattern.rawValue, options: [.caseInsensitive]) {
                compiled[pattern] = regex
            }
        }
        return compiled
    }()

    nonisolated public static func redactSensitiveText(_ value: String?) -> String? {
        guard let value else { return nil }
        var output = value

        for pattern in redactionOrder {
            guard let regex = compiledRedactionRegexes[pattern],
                  let replacement = replacementByPattern[pattern]
            else {
                continue
            }

            let fullRange = NSRange(output.startIndex..<output.endIndex, in: output)

            output = regex.stringByReplacingMatches(
                in: output,
                options: [],
                range: fullRange,
                withTemplate: replacement
            )
        }

        return output
    }

    nonisolated public static func isCaptureBlocked(bundleIdentifier: String?, excludedBundleIDs: [String]) -> Bool {
        guard let bundleIdentifier else { return false }
        let normalizedBundleID = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedBundleID.isEmpty else { return false }

        let normalizedExcludedBundleIDs = Set(
            excludedBundleIDs
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
                .prefix(maxExcludedBundleIDs)
        )

        return defaultSensitiveBundleIDs.contains(normalizedBundleID) || normalizedExcludedBundleIDs.contains(normalizedBundleID)
    }
}
