import Foundation

@MainActor
final class PhraseStore: ObservableObject {
    @Published private(set) var phrases: [Phrase] = []
    @Published var selectedID: Phrase.ID?
    @Published var searchText = ""
    @Published var filter: PhraseFilter = .all
    @Published var alertTitle = "提示"
    @Published var errorMessage: String?

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileURL: URL

    init(fileURL: URL = PhraseStore.defaultStoreURL()) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
        importSystemTextReplacements(showResult: false)
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
        phrases.sorted(by: sortPhrases).prefix(12).map { $0 }
    }

    func addPhrase() {
        let category = defaultCategoryForNewPhrase()
        let phrase = Phrase(text: "新短语", category: category)
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
        if selectedID == id {
            selectedID = filteredPhrases.first?.id
        }
        save()
    }

    func update(_ phrase: Phrase) {
        guard let index = phrases.firstIndex(where: { $0.id == phrase.id }) else { return }
        var updated = phrase
        updated.category = normalizedCategory(updated.category)
        updated.updatedAt = Date()
        phrases[index] = updated
        save()
    }

    func copy(_ phrase: Phrase) {
        guard !phrase.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        PasteboardService.copy(phrase.text)
        guard let index = phrases.firstIndex(where: { $0.id == phrase.id }) else { return }
        phrases[index].copyCount += 1
        phrases[index].lastCopiedAt = Date()
        phrases[index].updatedAt = Date()
        save()
    }

    func copySelected() {
        guard let selectedPhrase else { return }
        copy(selectedPhrase)
    }

    func toggleFavorite(_ phrase: Phrase) {
        guard var target = phrases.first(where: { $0.id == phrase.id }) else { return }
        target.isFavorite.toggle()
        update(target)
        if target.isFavorite {
            exportToSystem([target], showResult: false)
        }
    }

    func importPhrases(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let imported = try decoder.decode([Phrase].self, from: data)
            merge(imported)
            selectedID = phrases.first?.id
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
        save()
        if showResult {
            showInfo(addedCount > 0 ? "已导入 \(addedCount) 条系统文本替换。" : "没有新的系统文本替换可导入。")
        }
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
        var existingKeys = Set(phrases.map { mergeKey($0) })

        for phrase in imported {
            let key = mergeKey(phrase)
            guard !existingKeys.contains(key) else {
                continue
            }
            phrases.append(phrase)
            existingKeys.insert(key)
            addedCount += 1
        }

        phrases = phrases.sorted(by: sortPhrases)
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
            phrases = try decoder.decode([Phrase].self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            phrases = Self.seedPhrases
            save()
        } catch {
            showError("读取失败：\(error.localizedDescription)")
            phrases = Self.seedPhrases
        }
        selectedID = phrases.first?.id
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
        let replacements = source.map {
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
                    showInfo("没有写入：请先填写短语和拼音/缩写。")
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
        [
            phrase.text.trimmingCharacters(in: .whitespacesAndNewlines),
            phrase.reading.trimmingCharacters(in: .whitespacesAndNewlines)
        ].joined(separator: "\u{1f}")
    }

    nonisolated private static func defaultStoreURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent("PhraseBox", isDirectory: true).appendingPathComponent("phrases.json")
    }

    private static let seedPhrases: [Phrase] = [
        Phrase(text: "张三", reading: "zhang san", category: "姓名", note: "示例姓名", isFavorite: true),
        Phrase(text: "中华人民共和国", reading: "zhong hua ren min gong he guo", category: "常用词", isFavorite: true),
        Phrase(text: "身份证号码", reading: "shen fen zheng hao ma", category: "表单"),
        Phrase(text: "感谢您的支持与配合。", reading: "gan xie nin de zhi chi yu pei he", category: "工作")
    ]
}
