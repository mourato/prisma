import AppKit
import Combine
import Foundation
import MeetingAssistantCoreInfrastructure

public struct InstalledApplicationRecord: Identifiable, Hashable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String

    public init(bundleIdentifier: String, displayName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }

    public var id: String {
        bundleIdentifier
    }
}

public struct ResolvedDictationAppRule: Identifiable, Hashable, Sendable {
    public let rule: DictationAppRule
    public let displayName: String

    public init(rule: DictationAppRule, displayName: String) {
        self.rule = rule
        self.displayName = displayName
    }

    public var id: String {
        rule.bundleIdentifier
    }
}

@MainActor
public final class RulesPerAppSettingsViewModel: ObservableObject {
    @Published public var showAddAppSheet = false
    @Published public var showRuleEditor = false
    @Published public var editingRuleBundleIdentifier: String?
    @Published public var searchText = ""
    @Published public private(set) var appCatalog: [InstalledApplicationRecord] = []
    @Published public private(set) var isLoadingAppCatalog = false

    private let settings: AppSettingsStore
    private var cancellables = Set<AnyCancellable>()

    public init(settings: AppSettingsStore = .shared) {
        self.settings = settings

        settings.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public var resolvedRules: [ResolvedDictationAppRule] {
        let knownDisplayNames = Dictionary(
            uniqueKeysWithValues: appCatalog.map { (normalizeBundleIdentifier($0.bundleIdentifier), $0.displayName) }
        )

        return settings.dictationAppRules
            .map { rule in
                let normalized = normalizeBundleIdentifier(rule.bundleIdentifier)
                let fallbackName = displayName(for: rule.bundleIdentifier)
                let resolvedName = knownDisplayNames[normalized] ?? fallbackName
                return ResolvedDictationAppRule(rule: rule, displayName: resolvedName)
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    public var filteredAppCatalog: [InstalledApplicationRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appCatalog }

        return appCatalog.filter { app in
            app.displayName.localizedCaseInsensitiveContains(query) ||
                app.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    public var effectiveWebTargetBrowserBundleIdentifiers: [String] {
        settings.effectiveWebTargetBrowserBundleIdentifiers
    }

    public func openAddAppSheet() {
        showAddAppSheet = true
        ensureAppCatalogLoaded()
    }

    public func dismissAddAppSheet() {
        showAddAppSheet = false
        searchText = ""
    }

    public func ensureAppCatalogLoaded() {
        guard appCatalog.isEmpty, !isLoadingAppCatalog else { return }
        isLoadingAppCatalog = true

        Task {
            let discoveredApps = await Task.detached(priority: .userInitiated) {
                Self.discoverInstalledApplications()
            }.value
            appCatalog = discoveredApps
            isLoadingAppCatalog = false
        }
    }

    public func addAppRule(for app: InstalledApplicationRecord) {
        let normalized = normalizeBundleIdentifier(app.bundleIdentifier)
        guard !settings.dictationAppRules.contains(where: { normalizeBundleIdentifier($0.bundleIdentifier) == normalized }) else {
            dismissAddAppSheet()
            return
        }

        let isBrowser = BrowserProviderRegistry.isLikelyBrowserBundleIdentifier(normalized)
        var updated = settings.dictationAppRules
        updated.append(
            DictationAppRule(
                bundleIdentifier: app.bundleIdentifier,
                forceMarkdownOutput: !isBrowser,
                outputLanguage: .original
            )
        )
        settings.dictationAppRules = updated
        dismissAddAppSheet()
    }

    public func removeRule(bundleIdentifier: String) {
        let normalized = normalizeBundleIdentifier(bundleIdentifier)
        settings.dictationAppRules.removeAll { normalizeBundleIdentifier($0.bundleIdentifier) == normalized }

        if normalizeBundleIdentifier(editingRuleBundleIdentifier ?? "") == normalized {
            editingRuleBundleIdentifier = nil
            showRuleEditor = false
        }
    }

    public func editRule(bundleIdentifier: String) {
        editingRuleBundleIdentifier = bundleIdentifier
        showRuleEditor = true
    }

    public func dismissRuleEditor() {
        editingRuleBundleIdentifier = nil
        showRuleEditor = false
    }

    public func saveRule(
        bundleIdentifier: String,
        forceMarkdownOutput: Bool,
        outputLanguage: DictationOutputLanguage,
        customPromptInstructions: String?
    ) {
        updateRule(bundleIdentifier: bundleIdentifier) { rule in
            rule.forceMarkdownOutput = forceMarkdownOutput
            rule.outputLanguage = outputLanguage
            let normalized = customPromptInstructions?.trimmingCharacters(in: .whitespacesAndNewlines)
            rule.customPromptInstructions = (normalized?.isEmpty == false) ? normalized : nil
        }
        dismissRuleEditor()
    }

    public func setForceMarkdown(_ isEnabled: Bool, for bundleIdentifier: String) {
        updateRule(bundleIdentifier: bundleIdentifier) { $0.forceMarkdownOutput = isEnabled }
    }

    public func setOutputLanguage(_ language: DictationOutputLanguage, for bundleIdentifier: String) {
        updateRule(bundleIdentifier: bundleIdentifier) { $0.outputLanguage = language }
    }

    public func isAppAlreadyConfigured(_ app: InstalledApplicationRecord) -> Bool {
        let normalized = normalizeBundleIdentifier(app.bundleIdentifier)
        return settings.dictationAppRules.contains {
            normalizeBundleIdentifier($0.bundleIdentifier) == normalized
        }
    }

    private func updateRule(bundleIdentifier: String, mutate: (inout DictationAppRule) -> Void) {
        let normalized = normalizeBundleIdentifier(bundleIdentifier)
        var updated = settings.dictationAppRules

        guard let index = updated.firstIndex(where: {
            normalizeBundleIdentifier($0.bundleIdentifier) == normalized
        }) else {
            return
        }

        mutate(&updated[index])
        settings.dictationAppRules = updated
    }

    private func displayName(for bundleIdentifier: String) -> String {
        guard
            let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
            let bundle = Bundle(url: appURL)
        else {
            return bundleIdentifier
        }

        if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return displayName
        }

        if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return name
        }

        return appURL.deletingPathExtension().lastPathComponent
    }

    private func normalizeBundleIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension RulesPerAppSettingsViewModel {
    nonisolated private static var applicationSearchDirectories: [URL] {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser

        return [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            homeDirectory.appendingPathComponent("Applications", isDirectory: true),
        ]
    }

    nonisolated private static func discoverInstalledApplications() -> [InstalledApplicationRecord] {
        let fileManager = FileManager.default
        var seenBundleIdentifiers = Set<String>()
        var discovered: [InstalledApplicationRecord] = []

        for rootDirectory in applicationSearchDirectories {
            guard let enumerator = fileManager.enumerator(
                at: rootDirectory,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            while let item = enumerator.nextObject() as? URL {
                let candidateURL = item
                guard candidateURL.pathExtension.lowercased() == "app" else { continue }
                guard let bundle = Bundle(url: candidateURL),
                      let bundleIdentifier = bundle.bundleIdentifier
                else {
                    continue
                }

                let normalizedBundleIdentifier = bundleIdentifier
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()

                guard !normalizedBundleIdentifier.isEmpty else { continue }
                guard seenBundleIdentifiers.insert(normalizedBundleIdentifier).inserted else { continue }

                let displayName = appDisplayName(from: bundle, fallbackURL: candidateURL)
                discovered.append(
                    InstalledApplicationRecord(
                        bundleIdentifier: bundleIdentifier,
                        displayName: displayName
                    )
                )
            }
        }

        return discovered.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    nonisolated private static func appDisplayName(from bundle: Bundle, fallbackURL: URL) -> String {
        if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return fallbackURL.deletingPathExtension().lastPathComponent
    }
}
