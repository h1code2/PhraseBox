# PhraseBox / 词匣

PhraseBox 是一个面向中文输入场景的 macOS 短语管理工具。它可以集中管理姓名、地名、公司名、工作常用句、表单词汇等难输入内容，并与 macOS 系统“文本替换”互相同步。

项目中文名：词匣  
推荐 GitHub 仓库名：`PhraseBox`

## 功能

- 管理自定义中文短语
- 按分类整理短语
- 使用拼音、英文或缩写作为快捷输入码
- 搜索短语、拼音、分类和备注
- 标记常用短语
- 菜单栏快速复制常用短语
- 从 macOS 系统“文本替换”导入已有短语
- 将当前短语、常用短语或全部短语写入 macOS 系统“文本替换”
- JSON 导入和导出
- 本机 JSON 持久化存储

## 使用场景

- 中文姓名很难输入
- 公司、园区、项目、客户名称经常打错
- 第三方输入法词库不方便管理
- 需要把常用词同步到 macOS 原生文本替换
- 需要一个可搜索、可分类、可备份的短语库

## 系统要求

- macOS 13 或更新版本
- Apple Silicon 或 Intel Mac
- Swift 5.9 或更新版本

## 快速开始

```bash
git clone https://github.com/your-name/PhraseBox.git
cd PhraseBox
./script/build_and_run.sh
```

运行后会启动 `PhraseBox.app`。

## 开发运行

```bash
swift build
./script/build_and_run.sh
```

验证应用能正常启动：

```bash
./script/build_and_run.sh --verify
```

查看应用日志：

```bash
./script/build_and_run.sh --logs
```

调试：

```bash
./script/build_and_run.sh --debug
```

## 数据存储

PhraseBox 的本机短语库存储在：

```text
~/Library/Application Support/PhraseBox/phrases.json
```

每条短语包含：

- `text`：短语正文
- `reading`：拼音、英文或缩写
- `category`：分类
- `note`：备注
- `isFavorite`：是否常用
- `copyCount`：复制次数
- `createdAt`：创建时间
- `updatedAt`：更新时间
- `lastCopiedAt`：最近复制时间

## macOS 文本替换同步

macOS 的系统文本替换位于：

```text
System Settings > Keyboard > Text Replacements
```

PhraseBox 会读取和写入系统偏好中的：

```text
NSUserDictionaryReplacementItems
```

同步规则：

- 从系统导入时：
  - 系统 `replace` 会导入为 PhraseBox 的 `reading`
  - 系统 `with` 会导入为 PhraseBox 的 `text`
  - 分类会设置为 `系统文本替换`

- 写入系统时：
  - PhraseBox 的 `reading` 会写入系统 `replace`
  - PhraseBox 的 `text` 会写入系统 `with`
  - 已存在相同 `replace` 的项目会被更新
  - 没有填写 `reading` 或 `text` 的短语会跳过

## 常用短语

标记为常用后：

- 短语会优先显示
- 会出现在菜单栏快速入口中
- 会自动尝试写入 macOS 系统文本替换

## 菜单栏

PhraseBox 提供菜单栏入口：

- 打开主窗口
- 快速复制常用短语
- 新建短语
- 退出应用

菜单栏只展示排序靠前的短语，适合快速复制高频词。

## 导入和导出

PhraseBox 支持 JSON 文件导入和导出，适合备份、迁移或批量维护短语。

导入时会根据短语正文和输入码去重，不会重复写入相同短语。

## 项目结构

```text
Package.swift
Sources/PhraseBox/
  App/
    AppDelegate.swift
    PhraseBoxApp.swift
  Models/
    Phrase.swift
  Services/
    PasteboardService.swift
    SystemTextReplacementService.swift
  Stores/
    PhraseStore.swift
  Support/
    PhraseExportDocument.swift
  Views/
    ContentView.swift
    DetailView.swift
    PhraseListView.swift
    QuickPhraseMenu.swift
    SettingsView.swift
    SidebarView.swift
script/
  build_and_run.sh
```

## 技术栈

- Swift
- SwiftUI
- Swift Package Manager
- AppKit pasteboard
- UserDefaults global domain

## 已实现

- macOS SwiftUI 三栏界面
- 本机短语 CRUD
- 分类和搜索
- 常用短语
- 菜单栏入口
- 剪贴板复制
- macOS 文本替换导入
- macOS 文本替换写入
- JSON 导入导出
- SwiftPM 构建和本地 `.app` 打包脚本

## Roadmap

- 批量编辑分类
- CSV 导入导出
- 冲突预览和手动合并
- 更完整的系统文本替换同步状态
- 快捷键唤起搜索窗口
- iCloud 同步
- 发布正式 `.dmg`

## 贡献

欢迎提交 issue 和 pull request。

提交代码前请先运行：

```bash
swift build
./script/build_and_run.sh --verify
```

## License

MIT
