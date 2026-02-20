import Foundation
import Security

/// Manages API keys with support for environment variables and Keychain storage.
public final class APIKeyManager: Sendable {
    public static let shared = APIKeyManager()

    private static let serviceName = "io.schwa.PiApp"

    private init() {}

    /// Gets the API key for a provider, checking environment variables first, then Keychain.
    public func getAPIKey(for provider: String) -> String? {
        // Check environment variable first (e.g., ANTHROPIC_API_KEY, OPENAI_API_KEY)
        let envKey = "\(provider.uppercased())_API_KEY"
        if let envValue = ProcessInfo.processInfo.environment[envKey]?.trimmingCharacters(in: .whitespacesAndNewlines), !envValue.isEmpty {
            return envValue
        }

        // Fall back to Keychain
        return getKeychainKey(for: provider)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Saves an API key to the Keychain.
    public func setAPIKey(_ key: String, for provider: String) throws {
        let account = "api_key_\(provider)"
        guard let data = key.data(using: .utf8) else {
            throw APIKeyError.invalidKey
        }

        // Delete existing key if present
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw APIKeyError.keychainError(status)
        }
    }

    /// Deletes an API key from the Keychain.
    public func deleteAPIKey(for provider: String) throws {
        let account = "api_key_\(provider)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIKeyError.keychainError(status)
        }
    }

    /// Checks if an API key exists for a provider.
    public func hasAPIKey(for provider: String) -> Bool {
        getAPIKey(for: provider) != nil
    }

    private func getKeychainKey(for provider: String) -> String? {
        let account = "api_key_\(provider)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }
}

public enum APIKeyError: LocalizedError {
    case invalidKey
    case keychainError(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Invalid API key format"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        }
    }
}
