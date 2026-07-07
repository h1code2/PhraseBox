import Foundation

struct SystemTextReplacement {
    let shortcut: String
    let phrase: String
}

struct SystemTextReplacementWriteResult {
    let added: Int
    let updated: Int
    let skipped: Int

    var changed: Int { added + updated }
}

enum SystemTextReplacementService {
    private static let key = "NSUserDictionaryReplacementItems"
    private static let changeNotification = Notification.Name("NSUserDictionaryReplacementItemsDidChange")

    static func load() -> [SystemTextReplacement] {
        rawItems().compactMap { item in
            guard isEnabled(item["on"]),
                  let shortcut = item["replace"] as? String,
                  let phrase = item["with"] as? String else {
                return nil
            }

            let cleanShortcut = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanShortcut.isEmpty, !cleanPhrase.isEmpty else { return nil }

            return SystemTextReplacement(shortcut: cleanShortcut, phrase: cleanPhrase)
        }
    }

    static func save(_ replacements: [SystemTextReplacement]) throws -> SystemTextReplacementWriteResult {
        var domain = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain) ?? [:]
        var items = rawItems(from: domain)

        var added = 0
        var updated = 0
        var skipped = 0
        var seenShortcuts = Set<String>()

        for replacement in replacements {
            let shortcut = replacement.shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
            let phrase = replacement.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !shortcut.isEmpty, !phrase.isEmpty else {
                skipped += 1
                continue
            }
            guard seenShortcuts.insert(shortcut).inserted else {
                skipped += 1
                continue
            }

            if let index = items.firstIndex(where: { normalized($0["replace"] as? String) == shortcut }) {
                if (items[index]["with"] as? String) != phrase || !isEnabled(items[index]["on"]) {
                    items[index]["replace"] = shortcut
                    items[index]["with"] = phrase
                    items[index]["on"] = 1
                    updated += 1
                }
            } else {
                items.append([
                    "replace": shortcut,
                    "with": phrase,
                    "on": 1
                ])
                added += 1
            }
        }

        domain[key] = items
        UserDefaults.standard.setPersistentDomain(domain, forName: UserDefaults.globalDomain)
        guard UserDefaults.standard.synchronize() else {
            throw CocoaError(.fileWriteUnknown)
        }

        if added + updated > 0 {
            DistributedNotificationCenter.default().post(name: changeNotification, object: nil)
        }

        return SystemTextReplacementWriteResult(added: added, updated: updated, skipped: skipped)
    }

    private static func rawItems(from domain: [String: Any]? = nil) -> [[String: Any]] {
        if let items = domain?[key] as? [[String: Any]] {
            return items
        }
        if let globalItems = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?[key] as? [[String: Any]] {
            return globalItems
        }
        return (UserDefaults.standard.object(forKey: key) as? [[String: Any]]) ?? []
    }

    private static func normalized(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isEnabled(_ value: Any?) -> Bool {
        switch value {
        case let value as Bool:
            return value
        case let value as Int:
            return value != 0
        case let value as NSNumber:
            return value.boolValue
        case nil:
            return true
        default:
            return false
        }
    }
}
