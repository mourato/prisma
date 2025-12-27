import Foundation

public extension Bundle {
    /// Returns a bundle that works both in SPM and Xcode project builds.
    /// Falls back to main bundle if module bundle is not available.
    static var safeModule: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        // When built as Xcode project, resources are in main bundle
        return Bundle.main
        #endif
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
        String(format: self.localized, arguments: arguments)
    }
}
