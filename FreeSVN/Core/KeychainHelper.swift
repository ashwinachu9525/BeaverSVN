import Foundation
import Security
import LocalAuthentication

final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    /// Cache password in memory for this session
    private var passwordCache: [String: String] = [:]

    // MARK: - SAVE STRING
    func save(service: String, account: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        passwordCache["\(service)_\(account)"] = value
        return status == errSecSuccess
    }

    // MARK: - GET STRING
    func get(service: String, account: String, useTouchID: Bool = true) -> String? {

        let cacheKey = "\(service)_\(account)"
        if let cached = passwordCache[cacheKey] {
            return cached
        }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if useTouchID {
            let context = LAContext()
            context.localizedReason = "Authenticate to access SVN credentials"
            query[kSecUseAuthenticationContext as String] = context
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess,
           let data = item as? Data,
           let value = String(data: data, encoding: .utf8) {

            passwordCache[cacheKey] = value
            return value
        }

        return nil
    }

    // MARK: - DELETE STRING
    func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
        passwordCache["\(service)_\(account)"] = nil
    }

    // MARK: - SESSION CACHE
    func clearSessionCache() {
        passwordCache.removeAll()
    }

    // =====================================================
    // MARK: - SAVE DATA ARRAY (Bookmarks)
    // =====================================================
    func saveDataArray(service: String, dataArray: [Data]) {

        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: dataArray,
                requiringSecureCoding: false
            )

            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service
            ]

            SecItemDelete(query as CFDictionary)

            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]

            let status = SecItemAdd(addQuery as CFDictionary, nil)

            if status == errSecSuccess {
                NSLog("🔐 Saved DataArray to Keychain (\(service)) count=\(dataArray.count)")
            } else {
                NSLog("❌ Failed saving DataArray to Keychain: \(status)")
            }

        } catch {
            NSLog("❌ Failed to archive DataArray: \(error)")
        }
    }

    // =====================================================
    // MARK: - GET DATA ARRAY (Bookmarks)
    // =====================================================
    func getDataArray(service: String) -> [Data]? {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        do {
            let array = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [Data]
            return array
        } catch {
            NSLog("❌ Failed to unarchive DataArray: \(error)")
            return nil
        }
    }
}

