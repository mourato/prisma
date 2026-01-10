---
name: Keychain Security
description: This skill should be used when working with KeychainManager, KeychainProvider, storeSecret, retrieveSecret, or any secure storage operations. Provides guidance on secure credential storage, error handling, and key management patterns.
---

# Keychain Security

This skill provides guidance on secure credential storage using the macOS Keychain.

## When to Use This Skill

- Storing or retrieving API keys, tokens, or passwords
- Using KeychainManager or KeychainProvider
- Handling Keychain errors (errSecItemNotFound, errSecAuthFailed)
- Implementing secure credential rotation
- Working with biometric authentication

## Project Keychain Structure

### KeychainManager

The project uses `KeychainManager` for secure storage:

```swift
import Foundation

final class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.meeting.assistant"
    
    enum KeychainKey: String {
        case aiAPIKey = "com.meeting.assistant.ai.apikey"
        case legacyAPIKey = "com.meeting.assistant.legacy.apikey"
        case accessToken = "com.meeting.assistant.access.token"
        case refreshToken = "com.meeting.assistant.refresh.token"
    }
    
    func store(_ value: String, for key: KeychainKey) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }
    
    func retrieve(for key: KeychainKey) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.notFound
        }
        
        return value
    }
    
    func delete(for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

enum KeychainError: Error, LocalizedError {
    case encodingFailed
    case storeFound(OSStatus)
    case storeFailed(OSStatus)
    case notFound
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode value for Keychain storage"
        case .storeFound(let status):
            return "Item already exists in Keychain: \(status)"
        case .storeFailed(let status):
            return "Failed to store in Keychain: \(status)"
        case .notFound:
            return "Item not found in Keychain"
        case .retrieveFailed(let status):
            return "Failed to retrieve from Keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain: \(status)"
        }
    }
}
```

### DefaultKeychainProvider

For convenience, use the provider pattern:

```swift
protocol KeychainProvider {
    func store(_ value: String, for key: String) throws
    func retrieve(for key: String) throws -> String
    func delete(for key: String) throws
}

final class DefaultKeychainProvider: KeychainProvider {
    private let manager = KeychainManager.shared
    
    func store(_ value: String, for key: String) throws {
        try manager.store(value, for: .aiAPIKey)
    }
    
    func retrieve(for key: String) throws -> String {
        try manager.retrieve(for: .aiAPIKey)
    }
    
    func delete(for key: String) throws {
        try manager.delete(for: .aiAPIKey)
    }
}
```

## Common Patterns

### Store API Key

```swift
// Correct - Use KeychainManager
do {
    try KeychainManager.shared.store(apiKey, for: .aiAPIKey)
} catch {
    logger.error("Failed to store API key: \(error.localizedDescription)")
}

// Incorrect - Never use UserDefaults!
UserDefaults.standard.set(apiKey, forKey: "apiKey")  // NEVER!
```

### Retrieve API Key

```swift
// Correct - Handle errors properly
do {
    let apiKey = try KeychainManager.shared.retrieve(for: .aiAPIKey)
    useAPIKey(apiKey)
} catch KeychainError.notFound {
    // Prompt user to enter API key
    showAPIKeyInput()
} catch {
    // Handle other errors
    logger.error("Failed to retrieve API key: \(error.localizedDescription)")
}
```

### Update Existing Key

```swift
// Correct - Delete before updating
func updateAPIKey(_ newKey: String) throws {
    try? KeychainManager.shared.delete(for: .aiAPIKey)
    try KeychainManager.shared.store(newKey, for: .aiAPIKey)
}
```

## Error Handling

### Common Keychain Error Codes

| Error Code | Meaning | Handling |
|------------|---------|----------|
| errSecItemNotFound | Key doesn't exist | Store new value |
| errSecDuplicateItem | Key already exists | Delete then store |
| errSecAuthFailed | Authentication failed | Check keychain access |
| errSecParam | Invalid parameters | Verify query dict |

### Safe Retrieval Pattern

```swift
func safeRetrieve(for key: KeychainManager.KeychainKey) -> String? {
    do {
        return try KeychainManager.shared.retrieve(for: key)
    } catch KeychainError.notFound {
        return nil
    } catch {
        logger.error("Keychain error: \(error)")
        return nil
    }
}
```

## Security Best Practices

1. **Never store secrets in UserDefaults** - Always use Keychain
2. **Use appropriate access groups** - For sandboxed apps
3. **Handle errors gracefully** - Don't expose internal errors
4. **Use specific key names** - Avoid generic names like "password"
5. **Delete unused secrets** - Remove deprecated keys on migration

## Biometric Authentication

For sensitive operations, combine with biometric auth:

```swift
import LocalAuthentication

func authenticateWithBiometrics() async throws -> Bool {
    let context = LAContext()
    var error: NSError?
    
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        throw BiometricError.notAvailable
    }
    
    return await withCheckedContinuation { continuation in
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Access your API keys"
        ) { success, _ in
            continuation.resume(returning: success)
        }
    }
}

enum BiometricError: Error {
    case notAvailable
    case notEnrolled
    case authenticationFailed
}
```

## References

- [KeychainManager.swift](Packages/MeetingAssistantCore/Sources/MeetingAssistantCore/Services/KeychainManager.swift)
- [Security Rule](../.agent/rules/security.md)
- [Apple Keychain Services Reference](https://developer.apple.com/documentation/security/keychain_services)
