import Foundation

struct Phrase: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var reading: String
    var category: String
    var note: String
    var isFavorite: Bool
    var copyCount: Int
    var createdAt: Date
    var updatedAt: Date
    var lastCopiedAt: Date?

    init(
        id: UUID = UUID(),
        text: String = "",
        reading: String = "",
        category: String = "",
        note: String = "",
        isFavorite: Bool = false,
        copyCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastCopiedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.reading = reading
        self.category = category
        self.note = note
        self.isFavorite = isFavorite
        self.copyCount = copyCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastCopiedAt = lastCopiedAt
    }
}

enum PhraseFilter: Hashable, Identifiable {
    case all
    case favorites
    case uncategorized
    case category(String)

    var id: String {
        switch self {
        case .all: "all"
        case .favorites: "favorites"
        case .uncategorized: "uncategorized"
        case .category(let name): "category:\(name)"
        }
    }

    var title: String {
        switch self {
        case .all: "全部"
        case .favorites: "常用"
        case .uncategorized: "未分类"
        case .category(let name): name
        }
    }
}
