import Foundation
import Security

/// Secure storage for sensitive data using macOS Keychain.
/// Provides type-safe API for storing and retrieving secrets.
enum KeychainManager {
    
    // MARK: - Constants
    
    private static let serviceIdentifier = "com.meeting-assistant"
    
    // MARK: - Keys
    
    /// Known keys for Keychain storage.
    enum Key: String {
        case aiAPIKey = "ai_api_key"
    }
    
    // MARK: - Errors
    
    /// Errors that can occur during Keychain operations.
    enum KeychainError: LocalizedError {
        case unableToConvertToData
        case unableToConvertFromData
        case itemNotFound
        case unexpectedStatus(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .unableToConvertToData:
                return "Unable to convert string to data"
            case .unableToConvertFromData:
                return "Unable to convert data to string"
            case .itemNotFound:
                return "Item not found in Keychain"
            case .unexpectedStatus(let status):
                return "Keychain error: \(status)"
            }
        }
    }
    
    // MARK: - Public API
    
    /// Store a string securely in the Keychain.
    /// - Parameters:
    ///   - value: The string value to store.
    ///   - key: The key to store the value under.
    /// - Throws: `KeychainError` if storage fails.
    static func store(_ value: String, for key: Key) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.unableToConvertToData
        }
        
        // Build query for existing item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key.rawValue
        ]
        
        // Delete existing item if present
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Retrieve a string from the Keychain.
    /// - Parameter key: The key to retrieve the value for.
    /// - Returns: The stored string value, or `nil` if not found.
    /// - Throws: `KeychainError` if retrieval fails for reasons other than item not found.
    static func retrieve(for key: Key) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.unableToConvertFromData
            }
            return string
            
        case errSecItemNotFound:
            return nil
            
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Delete a value from the Keychain.
    /// - Parameter key: The key to delete.
    /// - Throws: `KeychainError` if deletion fails.
    static func delete(for key: Key) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // Treat "not found" as success (nothing to delete)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Check if a value exists in the Keychain.
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the key exists, `false` otherwise.
    static func exists(for key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}
