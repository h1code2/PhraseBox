import Foundation
import SQLite3

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
    private static let databaseURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/KeyboardServices/TextReplacements.db")
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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
        let cleanReplacements = normalizedReplacements(replacements)
        guard !cleanReplacements.isEmpty else {
            return SystemTextReplacementWriteResult(added: 0, updated: 0, skipped: replacements.count)
        }

        let defaultResult = try saveToGlobalDefaults(cleanReplacements)
        let databaseResult = try saveToKeyboardServicesDatabase(cleanReplacements)
        refreshKeyboardServicesIfNeeded(defaultResult.changed + databaseResult.changed > 0)

        return SystemTextReplacementWriteResult(
            added: max(defaultResult.added, databaseResult.added),
            updated: max(defaultResult.updated, databaseResult.updated),
            skipped: replacements.count - cleanReplacements.count
        )
    }

    private static func normalizedReplacements(_ replacements: [SystemTextReplacement]) -> [SystemTextReplacement] {
        var seenShortcuts = Set<String>()
        var result: [SystemTextReplacement] = []

        for replacement in replacements {
            let shortcut = replacement.shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
            let phrase = replacement.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !shortcut.isEmpty, !phrase.isEmpty, seenShortcuts.insert(shortcut).inserted else {
                continue
            }
            result.append(SystemTextReplacement(shortcut: shortcut, phrase: phrase))
        }

        return result
    }

    private static func saveToGlobalDefaults(_ replacements: [SystemTextReplacement]) throws -> SystemTextReplacementWriteResult {
        var domain = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain) ?? [:]
        var items = rawItems(from: domain)

        var added = 0
        var updated = 0

        for replacement in replacements {
            if let index = items.firstIndex(where: { normalized($0["replace"] as? String) == replacement.shortcut }) {
                if (items[index]["with"] as? String) != replacement.phrase || !isEnabled(items[index]["on"]) {
                    items[index]["replace"] = replacement.shortcut
                    items[index]["with"] = replacement.phrase
                    items[index]["on"] = 1
                    updated += 1
                }
            } else {
                items.append([
                    "replace": replacement.shortcut,
                    "with": replacement.phrase,
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

        return SystemTextReplacementWriteResult(added: added, updated: updated, skipped: 0)
    }

    private static func saveToKeyboardServicesDatabase(_ replacements: [SystemTextReplacement]) throws -> SystemTextReplacementWriteResult {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return SystemTextReplacementWriteResult(added: 0, updated: 0, skipped: replacements.count)
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let db else {
            throw SQLiteError.open(message: sqliteMessage(db))
        }
        defer { sqlite3_close(db) }

        sqlite3_busy_timeout(db, 2_000)
        try execute("BEGIN IMMEDIATE TRANSACTION", db: db)

        do {
            var added = 0
            var updated = 0

            for replacement in replacements {
                if let row = try existingDatabaseRow(shortcut: replacement.shortcut, db: db) {
                    if row.phrase != replacement.phrase || row.wasDeleted {
                        try updateDatabaseRow(rowID: row.id, replacement: replacement, db: db)
                        updated += 1
                    }
                } else {
                    try insertDatabaseRow(replacement, db: db)
                    added += 1
                }
            }

            try execute("COMMIT TRANSACTION", db: db)
            return SystemTextReplacementWriteResult(added: added, updated: updated, skipped: 0)
        } catch {
            try? execute("ROLLBACK TRANSACTION", db: db)
            throw error
        }
    }

    private static func existingDatabaseRow(shortcut: String, db: OpaquePointer) throws -> DatabaseRow? {
        let sql = """
        SELECT Z_PK, ZPHRASE, COALESCE(ZWASDELETED, 0)
        FROM ZTEXTREPLACEMENTENTRY
        WHERE ZSHORTCUT = ?
        ORDER BY ZWASDELETED ASC, Z_PK DESC
        LIMIT 1
        """
        var statement: OpaquePointer?
        try prepare(sql, db: db, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, shortcut, -1, transient)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }

        return DatabaseRow(
            id: Int(sqlite3_column_int64(statement, 0)),
            phrase: String(cString: sqlite3_column_text(statement, 1)),
            wasDeleted: sqlite3_column_int(statement, 2) != 0
        )
    }

    private static func updateDatabaseRow(rowID: Int, replacement: SystemTextReplacement, db: OpaquePointer) throws {
        let sql = """
        UPDATE ZTEXTREPLACEMENTENTRY
        SET ZPHRASE = ?, ZSHORTCUT = ?, ZWASDELETED = 0, ZNEEDSSAVETOCLOUD = 1, ZTIMESTAMP = ?, Z_OPT = COALESCE(Z_OPT, 1) + 1
        WHERE Z_PK = ?
        """
        var statement: OpaquePointer?
        try prepare(sql, db: db, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, replacement.phrase, -1, transient)
        sqlite3_bind_text(statement, 2, replacement.shortcut, -1, transient)
        sqlite3_bind_double(statement, 3, Date().timeIntervalSinceReferenceDate)
        sqlite3_bind_int64(statement, 4, sqlite3_int64(rowID))
        try stepDone(statement, db: db)
    }

    private static func insertDatabaseRow(_ replacement: SystemTextReplacement, db: OpaquePointer) throws {
        let rowID = try nextDatabaseRowID(db: db)
        let sql = """
        INSERT INTO ZTEXTREPLACEMENTENTRY
        (Z_PK, Z_ENT, Z_OPT, ZNEEDSSAVETOCLOUD, ZWASDELETED, ZTIMESTAMP, ZPHRASE, ZSHORTCUT, ZUNIQUENAME, ZREMOTERECORDINFO)
        VALUES (?, 1, 1, 1, 0, ?, ?, ?, ?, NULL)
        """
        var statement: OpaquePointer?
        try prepare(sql, db: db, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, sqlite3_int64(rowID))
        sqlite3_bind_double(statement, 2, Date().timeIntervalSinceReferenceDate)
        sqlite3_bind_text(statement, 3, replacement.phrase, -1, transient)
        sqlite3_bind_text(statement, 4, replacement.shortcut, -1, transient)
        sqlite3_bind_text(statement, 5, UUID().uuidString.uppercased(), -1, transient)
        try stepDone(statement, db: db)
        try setPrimaryKeyMax(rowID, db: db)
    }

    private static func nextDatabaseRowID(db: OpaquePointer) throws -> Int {
        let maxPrimaryKey = try scalarInt("SELECT COALESCE(MAX(Z_MAX), 0) FROM Z_PRIMARYKEY WHERE Z_NAME = 'TextReplacementEntry'", db: db)
        let maxRowID = try scalarInt("SELECT COALESCE(MAX(Z_PK), 0) FROM ZTEXTREPLACEMENTENTRY", db: db)
        return max(maxPrimaryKey, maxRowID) + 1
    }

    private static func setPrimaryKeyMax(_ value: Int, db: OpaquePointer) throws {
        let sql = "UPDATE Z_PRIMARYKEY SET Z_MAX = ? WHERE Z_NAME = 'TextReplacementEntry'"
        var statement: OpaquePointer?
        try prepare(sql, db: db, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, sqlite3_int64(value))
        try stepDone(statement, db: db)
    }

    private static func scalarInt(_ sql: String, db: OpaquePointer) throws -> Int {
        var statement: OpaquePointer?
        try prepare(sql, db: db, statement: &statement)
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SQLiteError.query(message: sqliteMessage(db))
        }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private static func execute(_ sql: String, db: OpaquePointer) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteError.query(message: sqliteMessage(db))
        }
    }

    private static func prepare(_ sql: String, db: OpaquePointer, statement: inout OpaquePointer?) throws {
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.query(message: sqliteMessage(db))
        }
    }

    private static func stepDone(_ statement: OpaquePointer?, db: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.query(message: sqliteMessage(db))
        }
    }

    private static func refreshKeyboardServicesIfNeeded(_ didChange: Bool) {
        guard didChange else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["keyboardservicesd"]
        try? process.run()
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

    private static func sqliteMessage(_ db: OpaquePointer?) -> String {
        guard let db, let message = sqlite3_errmsg(db) else {
            return "Unknown SQLite error"
        }
        return String(cString: message)
    }
}

private struct DatabaseRow {
    let id: Int
    let phrase: String
    let wasDeleted: Bool
}

private enum SQLiteError: LocalizedError {
    case open(message: String)
    case query(message: String)

    var errorDescription: String? {
        switch self {
        case .open(let message):
            return "无法打开系统文本替换数据库：\(message)"
        case .query(let message):
            return "无法更新系统文本替换数据库：\(message)"
        }
    }
}
