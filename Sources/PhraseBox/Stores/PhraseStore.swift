import Foundation

@MainActor
final class PhraseStore: ObservableObject {
    @Published private(set) var phrases: [Phrase] = []
    @Published var selectedID: Phrase.ID?
    @Published var searchText = "" {
        didSet {
            guard oldValue != searchText else { return }
            ensureSelectionIsVisible()
        }
    }
    @Published var filter: PhraseFilter = .all {
        didSet {
            guard oldValue != filter else { return }
            ensureSelectionIsVisible()
        }
    }
    @Published var alertTitle = "提示"
    @Published var errorMessage: String?

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileURL: URL

    init(fileURL: URL = PhraseStore.defaultStoreURL(), importsSystemTextReplacements: Bool = true) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
        if importsSystemTextReplacements {
            importSystemTextReplacements(showResult: false)
        }
    }

    var categories: [String] {
        Array(Set(phrases.map { normalizedCategory($0.category) }.filter { !$0.isEmpty })).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    var filteredPhrases: [Phrase] {
        phrases
            .filter(matchesFilter)
            .filter(matchesSearch)
            .sorted(by: sortPhrases)
    }

    var selectedPhrase: Phrase? {
        guard let selectedID else { return nil }
        return phrases.first { $0.id == selectedID }
    }

    var quickPhrases: [Phrase] {
        phrases
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted(by: sortPhrases)
            .prefix(12)
            .map { $0 }
    }

    func addPhrase() {
        if !searchText.isEmpty {
            searchText = ""
        }
        let category = defaultCategoryForNewPhrase()
        let phrase = Phrase(category: category, isFavorite: filter == .favorites)
        phrases.insert(phrase, at: 0)
        selectedID = phrase.id
        save()
    }

    func deleteSelected() {
        guard let selectedID else { return }
        delete(id: selectedID)
    }

    func delete(id: Phrase.ID) {
        phrases.removeAll { $0.id == id }
        ensureSelectionIsVisible()
        save()
    }

    func update(_ phrase: Phrase) {
        guard let index = phrases.firstIndex(where: { $0.id == phrase.id }) else { return }
        let existing = phrases[index]
        var updated = normalizedForStorage(phrase)
        updated.createdAt = existing.createdAt
        updated.copyCount = existing.copyCount
        updated.lastCopiedAt = existing.lastCopiedAt
        guard hasEditableChanges(from: existing, to: updated) else { return }
        updated.updatedAt = Date()
        phrases[index] = updated
        ensureSelectionIsVisible()
        save()
    }

    func copy(_ phrase: Phrase) {
        guard !phrase.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let index = phrases.firstIndex(where: { $0.id == phrase.id }) else { return }
        let existing = phrases[index]
        var updated = normalizedForStorage(phrase)
        updated.createdAt = existing.createdAt
        updated.isFavorite = existing.isFavorite
        updated.copyCount = existing.copyCount + 1
        updated.lastCopiedAt = Date()
        updated.updatedAt = Date()
        phrases[index] = updated
        PasteboardService.copy(phrase.text)
        save()
    }

    func copySelected() {
        guard let selectedPhrase else { return }
        copy(selectedPhrase)
    }

    func toggleFavorite(_ phrase: Phrase) {
        guard let index = phrases.firstIndex(where: { $0.id == phrase.id }) else { return }
        let existing = phrases[index]
        var updated = normalizedForStorage(phrase)
        updated.createdAt = existing.createdAt
        updated.copyCount = existing.copyCount
        updated.lastCopiedAt = existing.lastCopiedAt
        updated.isFavorite = !existing.isFavorite
        updated.updatedAt = Date()
        phrases[index] = updated
        ensureSelectionIsVisible()
        save()
        if updated.isFavorite {
            exportToSystem([updated], showResult: false)
        }
    }

    func importPhrases(from url: URL) {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let imported = try decoder.decode([Phrase].self, from: data)
            merge(imported)
            ensureSelectionIsVisible()
            save()
        } catch {
            showError("导入失败：\(error.localizedDescription)")
        }
    }

    func importSystemTextReplacements(showResult: Bool = true) {
        let imported = SystemTextReplacementService.load().map {
            Phrase(
                text: $0.phrase,
                reading: $0.shortcut,
                category: "系统文本替换",
                note: "从 macOS 文本替换导入"
            )
        }
        let addedCount = merge(imported)
        if addedCount > 0 {
            save()
        }
        if showResult {
            showInfo(addedCount > 0 ? "已导入 \(addedCount) 条系统文本替换。" : "没有新的系统文本替换可导入。")
        }
    }

    func exportToSystem(_ phrase: Phrase) {
        update(phrase)
        exportToSystem([phrase], showResult: true)
    }

    func exportSelectedToSystem() {
        guard let selectedPhrase else { return }
        exportToSystem([selectedPhrase], showResult: true)
    }

    func exportFavoritesToSystem() {
        exportToSystem(phrases.filter(\.isFavorite), showResult: true)
    }

    func exportAllToSystem() {
        exportToSystem(phrases, showResult: true)
    }

    @discardableResult
    private func merge(_ imported: [Phrase]) -> Int {
        var addedCount = 0
        phrases = normalizedUniquePhrases(phrases)
        var existingKeys = Set(phrases.map { mergeKey($0) }.filter { !$0.isEmpty })
        var existingIDs = Set(phrases.map(\.id))

        for item in imported {
            var phrase = normalizedForStorage(item)
            guard hasContent(phrase) else { continue }

            if let index = phrases.firstIndex(where: { $0.id == phrase.id }) {
                let existing = phrases[index]
                existingKeys.remove(mergeKey(existing))
                phrase.createdAt = existing.createdAt
                phrase.copyCount = max(existing.copyCount, phrase.copyCount)
                phrase.lastCopiedAt = latest(existing.lastCopiedAt, phrase.lastCopiedAt)
                phrase.updatedAt = max(existing.updatedAt, phrase.updatedAt)
                phrases[index] = phrase
                existingKeys.insert(mergeKey(phrase))
                continue
            }

            if existingIDs.contains(phrase.id) {
                phrase.id = UUID()
            }

            let key = mergeKey(phrase)
            guard key.isEmpty || !existingKeys.contains(key) else {
                continue
            }
            phrases.append(phrase)
            existingIDs.insert(phrase.id)
            existingKeys.insert(key)
            addedCount += 1
        }

        phrases = phrases.sorted(by: sortPhrases)
        ensureSelectionIsVisible()
        return addedCount
    }

    func exportData() -> Data? {
        do {
            return try encoder.encode(phrases)
        } catch {
            showError("导出失败：\(error.localizedDescription)")
            return nil
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            phrases = normalizedUniquePhrases(try decoder.decode([Phrase].self, from: data))
        } catch CocoaError.fileReadNoSuchFile {
            phrases = []
        } catch {
            showError("读取失败：\(error.localizedDescription)")
            phrases = []
        }
        ensureSelectionIsVisible()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(phrases)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            showError("保存失败：\(error.localizedDescription)")
        }
    }

    private func exportToSystem(_ source: [Phrase], showResult: Bool) {
        guard !source.isEmpty else {
            if showResult {
                showInfo("没有可写入的短语。")
            }
            return
        }

        let replacements = source.sorted(by: sortPhrases).map {
            SystemTextReplacement(
                shortcut: $0.reading.trimmingCharacters(in: .whitespacesAndNewlines),
                phrase: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        do {
            let result = try SystemTextReplacementService.save(replacements)
            if showResult {
                if result.changed > 0 {
                    showInfo("已写入系统：新增 \(result.added) 条，更新 \(result.updated) 条。")
                } else if result.skipped > 0 {
                    showInfo(
                        result.skipped == replacements.count
                            ? "没有写入：请先填写短语和拼音/缩写。"
                            : "系统文本替换已是最新，跳过 \(result.skipped) 条无效或重复短语。"
                    )
                } else {
                    showInfo("系统文本替换已是最新。")
                }
            }
        } catch {
            if showResult {
                showError("写入系统失败：\(error.localizedDescription)")
            }
        }
    }

    func showInfo(_ message: String) {
        alertTitle = "完成"
        errorMessage = message
    }

    private func ensureSelectionIsVisible() {
        let visiblePhrases = filteredPhrases
        if let selectedID, visiblePhrases.contains(where: { $0.id == selectedID }) {
            return
        }
        selectedID = visiblePhrases.first?.id
    }

    private func normalizedUniquePhrases(_ source: [Phrase]) -> [Phrase] {
        var ids = Set<Phrase.ID>()
        var keys = Set<String>()
        var result: [Phrase] = []

        for item in source {
            var phrase = normalizedForStorage(item)
            guard hasContent(phrase) else { continue }
            if !ids.insert(phrase.id).inserted {
                phrase.id = UUID()
                ids.insert(phrase.id)
            }
            let key = mergeKey(phrase)
            if !key.isEmpty {
                guard keys.insert(key).inserted else { continue }
            }
            result.append(phrase)
        }

        return result.sorted(by: sortPhrases)
    }

    private func normalizedForStorage(_ phrase: Phrase) -> Phrase {
        var result = phrase
        result.category = normalizedCategory(result.category)
        return result
    }

    private func latest(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case (.some(let lhs), .some(let rhs)):
            return max(lhs, rhs)
        case (.some(let lhs), .none):
            return lhs
        case (.none, .some(let rhs)):
            return rhs
        case (.none, .none):
            return nil
        }
    }

    private func hasContent(_ phrase: Phrase) -> Bool {
        !phrase.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !phrase.reading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !phrase.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func hasEditableChanges(from lhs: Phrase, to rhs: Phrase) -> Bool {
        lhs.text != rhs.text
            || lhs.reading != rhs.reading
            || normalizedCategory(lhs.category) != normalizedCategory(rhs.category)
            || lhs.note != rhs.note
            || lhs.isFavorite != rhs.isFavorite
    }

    func showError(_ message: String) {
        alertTitle = "出错了"
        errorMessage = message
    }

    private func matchesFilter(_ phrase: Phrase) -> Bool {
        switch filter {
        case .all:
            true
        case .favorites:
            phrase.isFavorite
        case .uncategorized:
            normalizedCategory(phrase.category).isEmpty
        case .category(let category):
            normalizedCategory(phrase.category) == category
        }
    }

    private func matchesSearch(_ phrase: Phrase) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return phrase.text.localizedCaseInsensitiveContains(query)
            || phrase.reading.localizedCaseInsensitiveContains(query)
            || phrase.category.localizedCaseInsensitiveContains(query)
            || phrase.note.localizedCaseInsensitiveContains(query)
    }

    private func sortPhrases(_ lhs: Phrase, _ rhs: Phrase) -> Bool {
        if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
        if lhs.copyCount != rhs.copyCount { return lhs.copyCount > rhs.copyCount }
        return lhs.updatedAt > rhs.updatedAt
    }

    private func defaultCategoryForNewPhrase() -> String {
        switch filter {
        case .category(let name): name
        default: ""
        }
    }

    private func normalizedCategory(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func mergeKey(_ phrase: Phrase) -> String {
        let text = phrase.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let reading = phrase.reading.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !reading.isEmpty else { return "" }
        return [text, reading].joined(separator: "\u{1f}")
    }

    nonisolated private static func defaultStoreURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent("PhraseBox", isDirectory: true).appendingPathComponent("phrases.json")
    }

}
