import SwiftUI

struct ContentView: View {
    @ObservedObject var store: PhraseStore
    @State private var isImporting = false
    @State private var isExporting = false

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } content: {
            PhraseListView(store: store)
        } detail: {
            DetailView(store: store)
        }
        .searchable(text: $store.searchText, placement: .sidebar, prompt: "搜索短语、拼音、分类")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.addPhrase()
                } label: {
                    Label("新建短语", systemImage: "plus")
                }
                Button {
                    store.copySelected()
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
                .disabled(store.selectedPhrase == nil)
                Menu {
                    Button("从系统导入") {
                        store.importSystemTextReplacements()
                    }
                    Button("当前短语写入系统") {
                        store.exportSelectedToSystem()
                    }
                    .disabled(store.selectedPhrase == nil)
                    Button("常用短语写入系统") {
                        store.exportFavoritesToSystem()
                    }
                    Button("全部短语写入系统") {
                        store.exportAllToSystem()
                    }
                    Divider()
                    Button("导入 JSON") { isImporting = true }
                    Button("导出 JSON") { isExporting = true }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                store.importPhrases(from: url)
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: PhraseExportDocument(data: store.exportData() ?? Data("[]".utf8)),
            contentType: .json,
            defaultFilename: "phrases.json"
        ) { result in
            if case .failure(let error) = result {
                store.showError("导出失败：\(error.localizedDescription)")
            }
        }
        .alert(store.alertTitle, isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("好") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}
