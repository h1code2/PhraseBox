import SwiftUI

struct DetailView: View {
    @ObservedObject var store: PhraseStore
    @State private var draft = Phrase()

    var body: some View {
        Group {
            if store.selectedPhrase != nil {
                Form {
                    Section {
                        TextEditor(text: $draft.text)
                            .font(.title3)
                            .frame(minHeight: 96)
                    } header: {
                        HStack {
                            Text("短语")
                            Spacer()
                            Button {
                                store.toggleFavorite(draft)
                                reloadDraft()
                            } label: {
                                Label(draft.isFavorite ? "常用" : "设为常用", systemImage: draft.isFavorite ? "star.fill" : "star")
                            }
                            Button {
                                store.exportToSystem(draft)
                            } label: {
                                Label("写入系统", systemImage: "keyboard")
                            }
                            Button {
                                store.copy(draft)
                                reloadDraft()
                            } label: {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    Section("索引") {
                        TextField("拼音、英文或缩写", text: $draft.reading)
                        TextField("分类", text: $draft.category)
                    }

                    Section("备注") {
                        TextEditor(text: $draft.note)
                            .frame(minHeight: 110)
                    }

                    Section {
                        LabeledContent("复制次数", value: "\(draft.copyCount)")
                        LabeledContent("创建时间", value: draft.createdAt.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("更新时间", value: draft.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                .formStyle(.grouped)
                .padding(.horizontal, 20)
                .onChange(of: draft) { value in
                    guard value != store.selectedPhrase else { return }
                    store.update(value)
                }
                .onChange(of: store.selectedID) { _ in
                    reloadDraft()
                }
                .onAppear {
                    reloadDraft()
                }
            } else {
                EmptyStateView(
                    title: "选择或新建短语",
                    systemImage: "text.badge.plus",
                    description: "管理姓名、地址、常用句和难输入词汇"
                )
            }
        }
    }

    private func reloadDraft() {
        if let phrase = store.selectedPhrase {
            draft = phrase
        }
    }
}
