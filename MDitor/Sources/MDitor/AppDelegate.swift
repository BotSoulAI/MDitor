import AppKit

/// 应用生命周期：激活窗口、处理退出前未保存提示
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    // 处理系统“打开文件”事件：双击 .md 文件、Finder 打开方式、open 命令等。
    // 同步处理文件；SwiftUI 收到打开文档事件时还会额外创建一个文档窗口，
    // 在下一个 runloop 里把它关闭，保证始终只有一个窗口。
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        let existingWindows = Set(NSApp.windows.map(\.windowNumber))
        EditorState.shared.handleOpen(url: url)
        DispatchQueue.main.async {
            for window in NSApp.windows where !existingWindows.contains(window.windowNumber) {
                window.close()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let editor = EditorState.shared
        guard editor.isDirty else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "当前文档有未保存的修改"
        alert.informativeText = "退出前要保存更改吗？"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "不保存")
        alert.addButton(withTitle: "取消")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            editor.saveDocument()
            return editor.isDirty ? .terminateCancel : .terminateNow
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }
}
