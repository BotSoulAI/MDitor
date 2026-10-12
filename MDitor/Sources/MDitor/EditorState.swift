import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 全局编辑状态：文档文本、文件路径、脏标记、格式化操作
@MainActor
final class EditorState: ObservableObject {
    static let shared = EditorState()

    @Published var text: String = "" {
        didSet { if !loading { isDirty = true } }
    }
    @Published var fileURL: URL?
    @Published var isDirty = false

    /// 是否显示编辑区（默认关闭：打开即纯预览，点击按钮进入编辑）
    @Published var showEditor: Bool {
        didSet { UserDefaults.standard.set(showEditor, forKey: "MDitor.showEditor") }
    }
    /// 是否显示预览区
    @Published var showPreview = true {
        didSet { UserDefaults.standard.set(showPreview, forKey: "MDitor.showPreview") }
    }

    /// 指向当前活动的 NSTextView（由 MarkdownTextView 维护）
    weak var textView: NSTextView?
    private var loading = false

    var windowTitle: String {
        let name = fileURL?.lastPathComponent ?? "未命名"
        return isDirty ? name + " •" : name
    }

    var wordCount: Int { text.split(whereSeparator: \.isWhitespace).count }
    var charCount: Int { text.count }
    var lineCount: Int { text.isEmpty ? 0 : text.components(separatedBy: "\n").count }

    private init() {
        showEditor = UserDefaults.standard.bool(forKey: "MDitor.showEditor")
        showPreview = UserDefaults.standard.object(forKey: "MDitor.showPreview") as? Bool ?? true
        if let path = UserDefaults.standard.string(forKey: "MDitor.lastFile"),
           FileManager.default.fileExists(atPath: path) {
            openFile(url: URL(fileURLWithPath: path))
        } else {
            loading = true
            text = Self.sampleDocument
            loading = false
            isDirty = false
        }
    }

    // MARK: - 文档操作

    func newDocument() {
        guard confirmDiscard() else { return }
        loading = true
        text = ""
        loading = false
        fileURL = nil
        isDirty = false
        textView?.string = ""
    }

    func openDocument() {
        guard confirmDiscard() else { return }
        let panel = NSOpenPanel()
        panel.title = "打开 Markdown 文件"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        let md = UTType(filenameExtension: "md") ?? .plainText
        let markdown = UTType(filenameExtension: "markdown") ?? .plainText
        panel.allowedContentTypes = [md, markdown, .plainText, .text]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openFile(url: url)
    }

    /// 处理系统“打开文件”事件（双击 .md 文件、open -a 等）。
    /// 当前文档无未保存修改时直接切换；有修改时先询问用户。
    func handleOpen(url: URL) {
        if isDirty {
            guard confirmDiscard() else { return }
        }
        openFile(url: url)
    }

    func openFile(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoded: String
            if data.count >= 3, data[0] == 0xEF, data[1] == 0xBB, data[2] == 0xBF {
                decoded = String(data: data.dropFirst(3), encoding: .utf8) ?? ""
            } else if let s = String(data: data, encoding: .utf8) {
                decoded = s
            } else if let s = String(data: data, encoding: .utf16) {
                decoded = s
            } else {
                decoded = String(data: data, encoding: .isoLatin1) ?? ""
            }
            loading = true
            text = decoded.replacingOccurrences(of: "\r\n", with: "\n")
            loading = false
            textView?.string = text
            fileURL = url
            isDirty = false
            UserDefaults.standard.set(url.path, forKey: "MDitor.lastFile")
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "无法打开文件"
            alert.runModal()
        }
    }

    func saveDocument() {
        if let url = fileURL {
            write(text, to: url)
        } else {
            saveDocumentAs()
        }
    }

    func saveDocumentAs() {
        let panel = NSSavePanel()
        panel.title = "保存 Markdown 文件"
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "未命名.md"
        let md = UTType(filenameExtension: "md") ?? .plainText
        panel.allowedContentTypes = [md, .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(text, to: url)
    }

    private func write(_ content: String, to url: URL) {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            fileURL = url
            isDirty = false
            UserDefaults.standard.set(url.path, forKey: "MDitor.lastFile")
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "保存失败"
            alert.runModal()
        }
    }

    func exportHTML() {
        let panel = NSSavePanel()
        panel.title = "导出 HTML"
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = (fileURL?.deletingPathExtension().lastPathComponent ?? "未命名") + ".html"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let html = MarkdownToHTML.render(text, title: fileURL?.lastPathComponent ?? "未命名")
        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "导出失败"
            alert.runModal()
        }
    }

    func confirmDiscard() -> Bool {
        guard isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "当前文档有未保存的修改"
        alert.informativeText = "是否先保存更改？"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "不保存")
        alert.addButton(withTitle: "取消")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            saveDocument()
            return !isDirty
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    // MARK: - 格式化（作用于活动的 NSTextView）

    private func perform(_ transform: (NSTextView) -> Void) {
        guard let tv = textView else { return }
        tv.window?.makeFirstResponder(tv)
        transform(tv)
        text = tv.string
    }

    private func replace(_ range: NSRange, in tv: NSTextView, with newText: String, select newRange: NSRange) {
        tv.insertText(newText, replacementRange: range)
        tv.setSelectedRange(newRange)
    }

    func toggleBold() {
        perform { tv in
            let s = tv.string as NSString
            let r = tv.selectedRange()
            let selected = r.length > 0 ? s.substring(with: r) : "粗体文本"
            replace(r, in: tv, with: "**\(selected)**", select: NSRange(location: r.location + 2, length: selected.count))
        }
    }

    func toggleItalic() {
        perform { tv in
            let s = tv.string as NSString
            let r = tv.selectedRange()
            let selected = r.length > 0 ? s.substring(with: r) : "斜体文本"
            replace(r, in: tv, with: "*\(selected)*", select: NSRange(location: r.location + 1, length: selected.count))
        }
    }

    func toggleCode() {
        perform { tv in
            let s = tv.string as NSString
            let r = tv.selectedRange()
            let selected = r.length > 0 ? s.substring(with: r) : "代码"
            replace(r, in: tv, with: "`\(selected)`", select: NSRange(location: r.location + 1, length: selected.count))
        }
    }

    func insertHeading() { prefixLines(with: "# ") }
    func insertQuote() { prefixLines(with: "> ") }
    func insertList() { prefixLines(with: "- ") }

    private func prefixLines(with prefix: String) {
        perform { tv in
            let s = tv.string as NSString
            let r = tv.selectedRange()
            let range = r.length > 0 ? r : NSRange(location: r.location, length: 0)
            let lineRange = s.lineRange(for: range)
            let lines = s.substring(with: lineRange)
            let prefixed = lines.split(separator: "\n", omittingEmptySubsequences: false)
                .map { prefix + String($0) }
                .joined(separator: "\n")
            replace(lineRange, in: tv, with: prefixed, select: NSRange(location: lineRange.location + prefix.count, length: 0))
        }
    }

    func insertLink() {
        perform { tv in
            let s = tv.string as NSString
            let r = tv.selectedRange()
            let selected = r.length > 0 ? s.substring(with: r) : "链接文字"
            replace(r, in: tv, with: "[\(selected)](https://)", select: NSRange(location: r.location + selected.count + 3, length: 8))
        }
    }

    func insertImage() {
        perform { tv in
            let s = tv.string as NSString
            let r = tv.selectedRange()
            let selected = r.length > 0 ? s.substring(with: r) : "图片描述"
            replace(r, in: tv, with: "![\(selected)](https://)", select: NSRange(location: r.location + selected.count + 4, length: 8))
        }
    }

    // MARK: - 首次启动示例

    static let sampleDocument = """
    # 欢迎使用 MDitor

    这是一个 **小巧、原生** 的 Markdown 编辑器，支持编辑与实时预览。

    ## 快速上手

    - 左侧编辑，右侧实时预览
    - 按 `⌘O` 打开文件，`⌘S` 保存
    - 把 `.md` 文件拖进窗口即可打开

    > 提示：工具栏的按钮可以快速插入 Markdown 语法。

    ### 支持的特性

    1. 标题、列表、引用、任务清单
    2. 粗体、斜体、行内代码、删除线、[链接](https://www.apple.com)
    3. 代码块与表格

    ```swift
    let app = "MDitor"
    print("Hello, \\(app)")
    ```

    | 功能 | 快捷键 |
    | --- | --- |
    | 打开 | ⌘O |
    | 保存 | ⌘S |
    | 粗体 | ⌘B |

    ---

    试试删除这里的示例文字，开始写你自己的文档吧！
    """
}
