import Foundation

extension AppSettingsStore {
    static func isValidHTTPURLString(_ value: String) -> Bool {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme)
        else {
            return false
        }

        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func save(_ value: some Encodable, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func applyLanguage(_ language: AppLanguage) {
        switch language {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        case .portuguese:
            UserDefaults.standard.set(["pt"], forKey: "AppleLanguages")
        }
    }
}
