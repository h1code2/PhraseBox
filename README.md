# PhraseBox / 词匣

PhraseBox 是一个 macOS 中文短语管理工具，用来管理难输入、易打错、经常重复输入的中文词汇，并同步到 macOS 系统“文本替换”。

适合管理姓名、公司名、地名、项目名、表单词汇和工作常用句。

## 功能

- 短语新增、编辑、删除
- 分类管理
- 拼音、英文或缩写检索
- 常用短语标记
- 菜单栏快速复制
- 从 macOS 系统“文本替换”导入已有短语
- 将当前短语、常用短语或全部短语写入系统“文本替换”
- JSON 导入和导出
- 本机数据存储

## 为什么需要 PhraseBox

macOS 自带“文本替换”，但批量维护、搜索、分类和备份都不够方便。PhraseBox 在系统文本替换之上提供一个更适合中文词汇管理的界面：

- 难输入的中文名可以用拼音缩写管理
- 常用业务词汇可以按分类整理
- 高频词可以放到菜单栏快速复制
- 本机短语库可以导出备份
- 需要时可以同步回系统文本替换，在其他输入场景继续使用

## 系统要求

- macOS 13 或更新版本
- Swift 5.9 或更新版本

## 从源码运行

```bash
git clone https://github.com/h1code2/PhraseBox.git
cd PhraseBox
./script/build_and_run.sh
```

验证启动：

```bash
./script/build_and_run.sh --verify
```

## 使用方式

1. 新建短语。
2. 在“短语”中填写中文内容。
3. 在“拼音、英文或缩写”中填写输入码，例如 `zhangsan`、`zs`、`msd`。
4. 按需填写分类和备注。
5. 点击“写入系统”，或标记为常用后自动写入系统文本替换。

写入系统后，可以在支持 macOS 文本替换的输入框中输入对应缩写并展开为短语。

## 系统文本替换同步

PhraseBox 与 macOS 系统文本替换的字段对应关系：

| PhraseBox | macOS 文本替换 |
| --- | --- |
| 短语 | 替换为 |
| 拼音、英文或缩写 | 输入码 |

导入规则：

- 系统输入码会导入为 PhraseBox 的“拼音、英文或缩写”
- 系统替换内容会导入为 PhraseBox 的“短语”
- 导入的内容默认归类为“系统文本替换”

写入规则：

- 已存在相同输入码时会更新系统条目
- 不存在相同输入码时会新增系统条目
- 没有填写短语或输入码的条目会跳过

## 数据位置

PhraseBox 的本机短语库存储在：

```text
~/Library/Application Support/PhraseBox/phrases.json
```

系统文本替换数据由 macOS 管理，可在：

```text
System Settings > Keyboard > Text Replacements
```

中查看。

## 开发

构建：

```bash
swift build
```

运行：

```bash
./script/build_and_run.sh
```

查看日志：

```bash
./script/build_and_run.sh --logs
```

调试：

```bash
./script/build_and_run.sh --debug
```

## 项目结构

```text
Sources/PhraseBox/
  App/
  Models/
  Services/
  Stores/
  Support/
  Views/
script/
  build_and_run.sh
```

## Roadmap

- 批量编辑分类
- CSV 导入和导出
- 冲突预览与手动合并
- 快捷键唤起搜索窗口
- iCloud 同步
- 正式安装包发布

## License

MIT
