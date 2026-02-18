import MeetingAssistantCoreCommon
import SwiftUI

enum WebTargetBrowserNamesFormatter {
    static func formattedNames(
        bundleIdentifiers: [String],
        fallbackBundleIdentifiers: [String],
        localizedListKey: String
    ) -> String {
        let effectiveBundleIdentifiers = bundleIdentifiers.isEmpty ? fallbackBundleIdentifiers : bundleIdentifiers

        if effectiveBundleIdentifiers.isEmpty {
            return "settings.web_targets.browsers.empty".localized
        }

        let names = effectiveBundleIdentifiers
            .map { WebTargetEditorSupport.browserDisplayName(for: $0) }
            .sorted()

        return localizedListKey.localized(with: names.joined(separator: ", "))
    }
}
