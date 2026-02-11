import AppKit
import MeetingAssistantCoreInfrastructure
import SwiftUI

@MainActor
public final class MarkdownTargetsViewModel: ObservableObject {
    @Published public private(set) var installedApps: [MarkdownTargetApp] = []

    private let settings: AppSettingsStore
    private let workspace: NSWorkspace

    public init(settings: AppSettingsStore = .shared, workspace: NSWorkspace = .shared) {
        self.settings = settings
        self.workspace = workspace
    }

    public func refreshTargets() {
        let candidates = resolveCandidateBundleIdentifiers()
        let resolved = resolveInstalledApps(from: candidates)
        let resolvedIdentifiers = resolved.map(\.bundleIdentifier)

        if settings.hasConfiguredMarkdownTargets,
           resolvedIdentifiers != settings.markdownTargetBundleIdentifiers
        {
            settings.markdownTargetBundleIdentifiers = resolvedIdentifiers
        }

        installedApps = resolved
    }

    public func addApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["app"]

        if panel.runModal() == .OK, let url = panel.url {
            addApp(from: url)
        }
    }

    public func removeApp(bundleIdentifier: String) {
        let normalized = normalizeBundleIdentifier(bundleIdentifier)
        var identifiers = settings.markdownTargetBundleIdentifiers
        identifiers.removeAll { normalizeBundleIdentifier($0) == normalized }
        settings.markdownTargetBundleIdentifiers = identifiers
        refreshTargets()
    }

    private func resolveCandidateBundleIdentifiers() -> [String] {
        if settings.hasConfiguredMarkdownTargets {
            return settings.markdownTargetBundleIdentifiers
        }
        return AppSettingsStore.defaultMarkdownTargetBundleIdentifiers
    }

    private func addApp(from url: URL) {
        guard let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier
        else {
            return
        }

        let normalized = normalizeBundleIdentifier(bundleIdentifier)
        var identifiers = settings.markdownTargetBundleIdentifiers
        if !identifiers.contains(where: { normalizeBundleIdentifier($0) == normalized }) {
            identifiers.append(bundleIdentifier)
        }
        settings.markdownTargetBundleIdentifiers = identifiers
        refreshTargets()
    }

    private func resolveInstalledApps(from bundleIdentifiers: [String]) -> [MarkdownTargetApp] {
        var seen = Set<String>()
        var resolved: [MarkdownTargetApp] = []

        for bundleIdentifier in bundleIdentifiers {
            let normalized = normalizeBundleIdentifier(bundleIdentifier)
            guard seen.insert(normalized).inserted else { continue }
            let trimmed = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let appURL = workspace.urlForApplication(withBundleIdentifier: trimmed) else { continue }

            let icon = workspace.icon(forFile: appURL.path)
            icon.size = NSSize(width: 20, height: 20)

            let displayName = bundleDisplayName(from: appURL)
            resolved.append(
                MarkdownTargetApp(
                    bundleIdentifier: bundleIdentifier,
                    displayName: displayName,
                    icon: icon
                )
            )
        }

        return resolved
    }

    private func bundleDisplayName(from url: URL) -> String {
        if let bundle = Bundle(url: url) {
            if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                return displayName
            }
            if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                return name
            }
        }
        return url.deletingPathExtension().lastPathComponent
    }

    private func normalizeBundleIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

public struct MarkdownTargetApp: Identifiable {
    public let bundleIdentifier: String
    public let displayName: String
    public let icon: NSImage

    public var id: String {
        bundleIdentifier
    }
}
