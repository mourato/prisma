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
