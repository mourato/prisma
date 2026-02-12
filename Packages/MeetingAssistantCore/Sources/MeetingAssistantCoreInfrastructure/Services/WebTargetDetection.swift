import AppKit
import Foundation

public protocol WebTargetPattern {
    var urlPatterns: [String] { get }
    var browserBundleIdentifiers: [String] { get }
}

extension WebMeetingTarget: WebTargetPattern {}
extension WebContextTarget: WebTargetPattern {}

public enum WebTargetDetection {
    public static func matchTarget<T: WebTargetPattern>(
        for url: URL,
        bundleIdentifier: String,
        targets: [T]
    ) -> T? {
        let urlString = url.absoluteString.lowercased()
        let normalizedBundleId = normalizeBundleIdentifier(bundleIdentifier)

        return targets.first { target in
            let normalizedTargetBrowsers = target.browserBundleIdentifiers.map(normalizeBundleIdentifier)
            guard normalizedTargetBrowsers.contains(normalizedBundleId) else { return false }
            return target.urlPatterns.contains { pattern in
                urlString.contains(pattern.lowercased())
            }
        }
    }

    public static func matchTargetByWindowTitle<T: WebTargetPattern>(
        bundleIdentifier: String,
        targets: [T],
        patternProvider: (T) -> [String] = { $0.urlPatterns }
    ) -> T? {
        let normalizedBundleId = normalizeBundleIdentifier(bundleIdentifier)

        for target in targets {
            let normalizedTargetBrowsers = target.browserBundleIdentifiers.map(normalizeBundleIdentifier)
            guard normalizedTargetBrowsers.contains(normalizedBundleId) else { continue }

            let patterns = patternProvider(target)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if !patterns.isEmpty, checkBrowserWindowTitles(for: patterns) {
                return target
            }
        }

        return nil
    }

    public static func checkBrowserWindowTitles(for patterns: [String]) -> Bool {
        let windowInfoOptions: CGWindowListOption = [.optionOnScreenOnly]
        guard
            let windowList = CGWindowListCopyWindowInfo(
                windowInfoOptions,
                kCGNullWindowID
            ) as? [[CFString: Any]]
        else {
            return false
        }

        for window in windowList {
            guard let windowName = window[kCGWindowName] as? String else { continue }

            for pattern in patterns where windowName.localizedCaseInsensitiveContains(pattern) {
                return true
            }
        }

        return false
    }

    public static func normalizeBundleIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
