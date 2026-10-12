import SwiftUI
import UniformTypeIdentifiers

@main
struct MDitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 单窗口场景：配合 CFBundleDocumentTypes 让系统认可本应用支持 md，
        // 同时避免 WindowGroup 在收到“打开文件”事件时额外新建文档窗口
        Window("MDitor", id: "main") {
            ContentView()
                .frame(minWidth: 820, minHeight: 560)
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建文档") { EditorState.shared.newDocument() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("打开…") { EditorState.shared.openDocument() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button("保存") { EditorState.shared.saveDocument() }
                    .keyboardShortcut("s", modifiers: .command)
                Button("另存为…") { EditorState.shared.saveDocumentAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Divider()
                Button("导出为 HTML…") { EditorState.shared.exportHTML() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            CommandMenu("格式") {
                Button("粗体") { EditorState.shared.toggleBold() }
                    .keyboardShortcut("b", modifiers: .command)
                Button("斜体") { EditorState.shared.toggleItalic() }
                    .keyboardShortcut("i", modifiers: .command)
                Button("行内代码") { EditorState.shared.toggleCode() }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                Divider()
                Button("标题") { EditorState.shared.insertHeading() }
                    .keyboardShortcut("h", modifiers: .command)
                Button("引用") { EditorState.shared.insertQuote() }
                    .keyboardShortcut("q", modifiers: [.command, .shift])
                Button("列表项") { EditorState.shared.insertList() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("链接") { EditorState.shared.insertLink() }
                    .keyboardShortcut("u", modifiers: [.command, .shift])
                Button("图片") { EditorState.shared.insertImage() }
            }
            CommandMenu("显示") {
                Toggle("编辑区", isOn: Binding(
                    get: { EditorState.shared.showEditor },
                    set: { EditorState.shared.showEditor = $0 }
                ))
                .keyboardShortcut("d", modifiers: [.command, .shift])
                Toggle("预览", isOn: Binding(
                    get: { EditorState.shared.showPreview },
                    set: { EditorState.shared.showPreview = $0 }
                ))
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject private var editor = EditorState.shared

    var body: some View {
        VStack(spacing: 0) {
            // 编辑与预览同时显示时各占一半窗口；只显示其一时占满
            GeometryReader { geo in
                HStack(spacing: 0) {
                    if editor.showEditor {
                        MarkdownTextView(editor: editor)
                            .frame(width: editor.showPreview ? geo.size.width / 2 : geo.size.width)
                    }
                    if editor.showPreview {
                        MarkdownPreview(markdown: editor.text)
                            .frame(width: editor.showEditor ? geo.size.width / 2 : geo.size.width)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            statusBar
        }
        .onChange(of: editor.fileURL) { _ in
            // 切换文档后编辑区与预览区回到顶部
            ScrollSync.shared.reset()
        }
        .toolbar {
            ToolbarItemGroup {
                Button { editor.newDocument() } label: { Label("新建", systemImage: "doc.badge.plus") }
                    .help("新建文档 (⌘N)")
                Button { editor.openDocument() } label: { Label("打开", systemImage: "folder") }
                    .help("打开文件 (⌘O)")
                Button { editor.saveDocument() } label: { Label("保存", systemImage: "square.and.arrow.down") }
                    .help("保存 (⌘S)")
                if editor.showEditor {
                    Button { editor.toggleBold() } label: { Label("粗体", systemImage: "bold") }
                        .help("粗体 (⌘B)")
                    Button { editor.toggleItalic() } label: { Label("斜体", systemImage: "italic") }
                        .help("斜体 (⌘I)")
                    Button { editor.toggleCode() } label: { Label("代码", systemImage: "chevron.left.forwardslash.chevron.right") }
                        .help("行内代码 (⌘⇧K)")
                    Button { editor.insertHeading() } label: { Label("标题", systemImage: "textformat.size") }
                        .help("标题 (⌘H)")
                    Button { editor.insertQuote() } label: { Label("引用", systemImage: "quote.opening") }
                        .help("引用 (⌘⇧Q)")
                    Button { editor.insertList() } label: { Label("列表", systemImage: "list.bullet") }
                        .help("列表 (⌘⇧L)")
                    Button { editor.insertLink() } label: { Label("链接", systemImage: "link") }
                        .help("链接 (⌘U)")
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        editor.showEditor.toggle()
                    }
                } label: {
                    Label(
                        editor.showEditor ? "隐藏编辑区" : "显示编辑区",
                        systemImage: editor.showEditor ? "sidebar.left" : "pencil"
                    )
                }
                .help("显示/隐藏编辑区 (⌘⇧D)")
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        editor.showPreview.toggle()
                    }
                } label: {
                    Label(
                        editor.showPreview ? "隐藏预览" : "显示预览",
                        systemImage: editor.showPreview ? "sidebar.trailing" : "sidebar.right"
                    )
                }
                .help("显示/隐藏预览 (⌘⇧P)")
            }
        }
        .navigationTitle(editor.windowTitle)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Label(editor.fileURL?.lastPathComponent ?? "未命名", systemImage: "doc")
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text("\(editor.wordCount) 词")
            Text("\(editor.charCount) 字符")
            Text("\(editor.lineCount) 行")
            if editor.isDirty {
                Text("未保存").foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.bar)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url = url,
                  ["md", "markdown", "txt"].contains(url.pathExtension.lowercased()) else { return }
            DispatchQueue.main.async {
                let editor = EditorState.shared
                if editor.confirmDiscard() {
                    editor.openFile(url: url)
                }
            }
        }
        return true
    }
}
