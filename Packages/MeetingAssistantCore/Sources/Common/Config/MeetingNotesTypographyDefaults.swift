import Foundation

public enum MeetingNotesTypographyDefaults {
    public static let systemFontFamilyKey = "__system__"
    public static let defaultFontSize: Double = 16
    public static let supportedFontSizes: [Double] = [10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 32]

    public static func normalizedFontFamilyKey(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? systemFontFamilyKey : trimmed
    }

    public static func normalizedFontSize(_ value: Double) -> Double {
        let fallback = defaultFontSize
        let candidate = (value.isFinite && value > 0) ? value : fallback
        return supportedFontSizes.min(by: { abs($0 - candidate) < abs($1 - candidate) }) ?? fallback
    }
}
