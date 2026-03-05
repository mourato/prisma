import Foundation

public struct SettingsSectionNavigationHistory: Equatable {
    private(set) var sections: [SettingsSection]
    private(set) var index: Int

    public init(initialSection: SettingsSection = .metrics) {
        sections = [initialSection]
        index = 0
    }

    public var currentSection: SettingsSection {
        guard sections.indices.contains(index) else {
            return .metrics
        }
        return sections[index]
    }

    public var canGoBack: Bool {
        index > 0
    }

    public var canGoForward: Bool {
        index < sections.count - 1
    }

    public mutating func push(_ section: SettingsSection) {
        guard section != currentSection else { return }

        if canGoForward {
            sections.removeSubrange((index + 1)..<sections.count)
        }

        sections.append(section)
        index = sections.count - 1
    }

    @discardableResult
    public mutating func goBack() -> SettingsSection? {
        guard canGoBack else { return nil }
        index -= 1
        return currentSection
    }

    @discardableResult
    public mutating func goForward() -> SettingsSection? {
        guard canGoForward else { return nil }
        index += 1
        return currentSection
    }
}
