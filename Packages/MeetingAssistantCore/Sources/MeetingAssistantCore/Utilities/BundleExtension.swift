import Foundation

public extension Bundle {
    /// Returns a bundle that works both in SPM and Xcode project builds.
    /// Falls back to main bundle if module bundle is not available.
    static var safeModule: Bundle {
        // 1. Determine the base bundle (module or main)
        let baseBundle: Bundle
        #if SWIFT_PACKAGE
        baseBundle = Bundle.module
        #else
        baseBundle = Bundle.main
        #endif

        // 2. Check for user-selected language override in UserDefaults
        //    NOTE: UserDefaults(suiteName: nil) checks standard defaults
        if let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let preferredLang = languages.first,
           let path = baseBundle.path(forResource: preferredLang, ofType: "lproj"),
           let localizedBundle = Bundle(path: path) {
            return localizedBundle
        }

        // 3. Fallback to base bundle if no override or localized resource found
        return baseBundle
    }
}

// MARK: - String Localization Helper

public extension String {
    /// Localized string using the safe module bundle.
    /// Usage: `"settings.general.language".localized`
    var localized: String {
        NSLocalizedString(self, bundle: .safeModule, comment: "")
    }

    /// Localized string with format arguments.
    /// Usage: `"permissions.granted_count".localized(with: count)`
    func localized(with arguments: CVarArg...) -> String {
        String(format: localized, arguments: arguments)
    }
}
