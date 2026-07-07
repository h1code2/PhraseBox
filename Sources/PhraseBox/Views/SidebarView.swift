import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: PhraseStore

    var body: some View {
        List(selection: $store.filter) {
            Section {
                Label(PhraseFilter.all.title, systemImage: "tray.full")
                    .tag(PhraseFilter.all)
                Label(PhraseFilter.favorites.title, systemImage: "star")
                    .tag(PhraseFilter.favorites)
                Label(PhraseFilter.uncategorized.title, systemImage: "tag.slash")
                    .tag(PhraseFilter.uncategorized)
            }

            Section("分类") {
                ForEach(store.categories, id: \.self) { category in
                    Label(category, systemImage: "tag")
                        .tag(PhraseFilter.category(category))
                }
            }
        }
        .navigationTitle("词匣")
        .listStyle(.sidebar)
    }
}
