import FreedomFromKit
import Foundation
import Security

/// The one place freedomfrom's state lives.
///
/// A single `kSecClassGenericPassword` item, shared between the app and both
/// extensions by a keychain access group, `kSecAttrAccessibleAfterFirstUnlock`
/// and explicitly non-synchronizable. There is no App Group and no mirror
/// (ADR 0002).
///
/// **No access group is named in code, deliberately.** An unspecified group
/// resolves to the first entry in the caller's `keychain-access-groups`
/// entitlement, and all three targets declare exactly one, the same one — so
/// the entitlement file is the single source of that string and no build
/// setting has to be re-expressed as a literal here.
///
/// Whether an extension can read this at all is hardware smoke check S1, and it
/// is one of the two checks that can change the architecture.
public struct KeychainRecordStore: Sendable {
    public enum Failure: Error, Equatable {
        case keychain(OSStatus)
        case corrupt
    }

    private let service: String
    private let account: String

    public init(
        service: String = "com.samuelcolacchia.freedomfrom",
        account: String = "record"
    ) {
        self.service = service
        self.account = account
    }

    /// The stored record, or `nil` when nothing has ever been written.
    ///
    /// A decode failure is `corrupt` rather than `nil`: "no record" and "a
    /// record we cannot read" lead to opposite behaviour, since the first means
    /// nothing is running and the second means we must not assume that.
    public func read() throws -> Record? {
        var query = searchQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw Failure.corrupt }
            do {
                return try RecordCodec.decode(data)
            } catch {
                throw Failure.corrupt
            }
        case errSecItemNotFound:
            return nil
        default:
            throw Failure.keychain(status)
        }
    }

    public func write(_ record: Record) throws {
        let data = try RecordCodec.encode(record)
        let query = searchQuery()

        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var insert = query
            insert[kSecValueData as String] = data
            // Only an insert may carry it: kSecAttrAccessible is an attribute
            // of a stored item, not a search term, and a process with a
            // tighter sandbox than the app's rejects the query outright
            // rather than ignoring it.
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw Failure.keychain(addStatus) }
        default:
            throw Failure.keychain(updateStatus)
        }
    }

    /// Removes the item outright. Not the same thing as a clean slate: that
    /// erases what you authored and leaves the first-run flag alone
    /// (ADR 0008), and goes through `Record.cleanSlate()` instead.
    public func deleteEverything() throws {
        let status = SecItemDelete(searchQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Failure.keychain(status)
        }
    }

    /// What identifies the one item. Search terms only: an attribute that
    /// describes how an item is *stored* belongs on the insert, not here.
    private func searchQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            // The two devices are islands by design (ADR 0002).
            kSecAttrSynchronizable as String: false,
        ]
    }
}
