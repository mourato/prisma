import Foundation

/// Configuration for different application environments.
public enum AppEnvironment {
    case debug
    case release

    /// The current application environment based on build configuration.
    public static var current: AppEnvironment {
        #if DEBUG
        return .debug
        #else
        return .release
        #endif
    }

    /// Convenience property to check if the app is running in debug mode.
    public static var isDebug: Bool {
        self.current == .debug
    }

    /// Convenience property to check if the app is running in release mode.
    public static var isRelease: Bool {
        self.current == .release
    }
}

/// Centralized configuration for the application.
public enum EnvironmentConfig {
    /// Logging configuration based on environment.
    public enum Logging {
        /// Whether detailed logging is enabled.
        public static var isDetailedLoggingEnabled: Bool {
            AppEnvironment.isDebug
        }

        /// The privacy level for logging.
        public static var privacyLevel: String {
            AppEnvironment.isDebug ? "public" : "private"
        }
    }

    /// Feature flags based on environment.
    public enum Features {
        /// Whether experimental features are enabled.
        public static var enableExperimentalFeatures: Bool {
            AppEnvironment.isDebug
        }
    }

    /// API configuration based on environment.
    public enum API {
        /// The base URL for the API.
        public static var baseURL: URL {
            // Placeholder for future API configuration
            #if DEBUG
            return URL(string: "https://api-dev.meetingassistant.com")!
            #else
            return URL(string: "https://api.meetingassistant.com")!
            #endif
        }
    }
}
