import SwiftUI

struct QuickPhraseMenu: View {
    @ObservedObject var store: PhraseStore
    let openMainWindow: () -> Void

    var body: some View {
        Button("打开词匣") {
            openMainWindow()
        }
        Divider()
        if store.quickPhrases.isEmpty {
            Text("暂无短语")
        } else {
            ForEach(store.quickPhrases) { phrase in
                Button(menuTitle(for: phrase)) {
                    store.copy(phrase)
                }
            }
        }
        Divider()
        Button("新建短语") {
            openMainWindow()
            store.addPhrase()
        }
        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func menuTitle(for phrase: Phrase) -> String {
        let text = phrase.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 18 else { return text.isEmpty ? "未命名短语" : text }
        return String(text.prefix(18)) + "..."
    }
}
