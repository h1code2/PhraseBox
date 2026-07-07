import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            LabeledContent("数据位置", value: "~/Library/Application Support/PhraseBox/phrases.json")
            Text("启动时会读取 macOS 文本替换；写入系统时使用拼音、英文或缩写作为快捷输入码。")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 460)
    }
}
