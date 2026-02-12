import Foundation

public struct WebContextTarget: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let displayName: String
    public let urlPatterns: [String]
    public let browserBundleIdentifiers: [String]

    public init(
        id: UUID = UUID(),
        displayName: String,
        urlPatterns: [String],
        browserBundleIdentifiers: [String]
    ) {
        self.id = id
        self.displayName = displayName
        self.urlPatterns = urlPatterns
        self.browserBundleIdentifiers = browserBundleIdentifiers
    }
}
