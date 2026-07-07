import SwiftUI

struct PhraseListView: View {
    @ObservedObject var store: PhraseStore

    var body: some View {
        List(selection: $store.selectedID) {
            ForEach(store.filteredPhrases) { phrase in
                PhraseRowView(phrase: phrase)
                    .tag(phrase.id)
                    .contextMenu {
                        Button("复制") { store.copy(phrase) }
                        Button(phrase.isFavorite ? "取消常用" : "设为常用") { store.toggleFavorite(phrase) }
                        Divider()
                        Button("删除", role: .destructive) { store.delete(id: phrase.id) }
                    }
            }
        }
        .overlay {
            if store.filteredPhrases.isEmpty {
                EmptyStateView(
                    title: "没有匹配短语",
                    systemImage: "text.magnifyingglass",
                    description: "新建一个短语或调整搜索条件"
                )
            }
        }
        .navigationTitle(store.filter.title)
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Text(description)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(32)
    }
}

private struct PhraseRowView: View {
    let phrase: Phrase

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: phrase.isFavorite ? "star.fill" : "text.quote")
                .foregroundStyle(phrase.isFavorite ? .yellow : .secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(phrase.text.isEmpty ? "未命名短语" : phrase.text)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if !phrase.reading.isEmpty {
                        Text(phrase.reading)
                    }
                    if !phrase.category.isEmpty {
                        Text(phrase.category)
                    }
                    if phrase.copyCount > 0 {
                        Text("复制 \(phrase.copyCount)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
