import AppKit
import SwiftUI

// 预览区滚动回归自检（两个历史 bug 的守护测试）：
//   1) 连续滚轮能否滚到文档底部（曾因文档视图高度虚高/事件被吞而卡住）；
//   2) 鼠标停在代码块上时预览是否仍能滚动 —— 代码块内嵌的横向滚动视图
//      绝不能吞掉纵向滚轮事件。
//
// 说明：为了不受窗口服务器事件路由（合成事件要求窗口在最前台等）影响，
// 这里把滚轮事件直接派发给对应 NSView，只验证应用自身的滚动处理逻辑。
//
// 编译与运行（不需要 Xcode，也不需要辅助功能权限）：
//   swiftc -swift-version 5 Sources/MDitorCore/*.swift \
//       Sources/MDitor/EditorState.swift Sources/MDitor/MarkdownTextView.swift \
//       Sources/MDitor/PreviewView.swift Sources/MDitor/ScrollSync.swift \
//       scripts/preview_scroll_check.swift -o .build/preview_check \
//       -framework AppKit -framework SwiftUI -framework UniformTypeIdentifiers
//   ./.build/preview_check

private let EVENTS_PER_PHASE = 400
private let WHEEL_LINES: Int32 = -3
private let INTERVAL = 0.02

private func say(_ text: String) {
    print(text)
    fflush(stdout)
}

/// 生成一份足够长、且含代码块的测试文档
private func sampleDocument() -> String {
    var lines: [String] = ["# 预览滚动自检文档", ""]
    for i in 1...40 {
        lines.append("## 章节 \(i)")
        lines.append("")
        lines.append("第 \(i) 段测试文本，**加粗**、*斜体*、`行内代码` 与[链接](https://example.com)混排，用来撑开高度。")
        lines.append("")
        lines.append("- 列表项 \(i)-A")
        lines.append("- 列表项 \(i)-B")
        lines.append("")
        lines.append("> 引用块 \(i)")
        lines.append("")
        if i % 5 == 0 {
            lines.append("```swift")
            lines.append("func demo\(i)() -> Int {")
            lines.append("    return \(i)")
            lines.append("}")
            lines.append("```")
            lines.append("")
        }
    }
    return lines.joined(separator: "\n")
}

private struct CheckRoot: View {
    @ObservedObject var editor = EditorState.shared
    var body: some View {
        GeometryReader { geo in
            MarkdownPreview(markdown: editor.text, width: geo.size.width)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

final class ScrollCheckDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var preview: NSScrollView!
    private var inner: NSScrollView?
    private var point = NSPoint.zero
    private var sent = 0
    private var phaseStart: CGFloat = 0
    private var maxStall = 0
    private var lastOrigin: CGFloat = -1
    private var failures: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        EditorState.shared.text = sampleDocument()
        EditorState.shared.showPreview = true

        window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 1000, height: 732),
                          styleMask: [.titled, .closable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "预览滚动自检"
        window.contentView = NSHostingView(rootView: CheckRoot())
        // 置顶显示：被别的窗口遮住时 AppKit 会跳过滚动处理，导致合成事件无效
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self.begin() }
    }

    private func after(_ delay: Double, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
    }

    private func begin() {
        guard let scroll = ScrollSync.shared.previewScroll else {
            say("失败：预览滚动视图未创建")
            exit(1)
        }
        preview = scroll
        let pane = preview.convert(preview.bounds, to: nil)
        point = NSPoint(x: pane.midX, y: pane.midY)
        let docHeight = preview.documentView?.frame.height ?? 0
        say("预览文档高度=\(Int(docHeight)) 可见高度=\(Int(preview.contentView.bounds.height))")
        let inners = findInnerScrollViews(in: preview)
        inner = inners.first
        if let inner {
            let rect = inner.convert(inner.bounds, to: preview.documentView)
            say("发现 \(inners.count) 个内层滚动视图（\(type(of: inner))），首个位于文档 y=\(Int(rect.minY))..\(Int(rect.maxY))")
        } else {
            say("警告：未找到内层（代码块）滚动视图")
        }

        preview.contentView.scroll(to: .zero)
        preview.reflectScrolledClipView(preview.contentView)
        after(0.3) {
            self.phaseStart = self.preview.contentView.bounds.origin.y
            self.sent = 0; self.maxStall = 0; self.lastOrigin = -1
            self.run(phase: 1)
        }
    }

    /// 阶段 1：把滚轮直接派发给预览滚动视图，应能滚到文档底部
    /// 阶段 2：把代码块挪到视口中央，把滚轮派发给代码块内嵌滚动视图，外层预览应跟随滚动
    private func run(phase: Int) {
        dispatchWheel(phase: phase)
        let origin = preview.contentView.bounds.origin.y
        let maxScroll = (preview.documentView?.frame.height ?? 0) - preview.contentView.bounds.height
        if origin < maxScroll - 2 {
            if abs(origin - lastOrigin) < 0.5 {
                maxStall += 1
            } else {
                maxStall = 0
            }
        }
        lastOrigin = origin

        guard sent >= EVENTS_PER_PHASE else {
            after(INTERVAL) { self.run(phase: phase) }
            return
        }

        let moved = origin - phaseStart
        if phase == 1 {
            let pass = origin >= maxScroll - 2
            say("阶段 1（滚到文档底部）: 位移=\(Int(moved)) 最大滚动=\(Int(maxScroll)) 到底前最长卡顿=\(maxStall) 次事件 → \(pass ? "通过" : "失败")")
            if !pass { failures.append("连续滚轮无法滚到文档底部（停在 \(Int(origin))/\(Int(maxScroll))）") }

            guard let inner else {
                finish()
                return
            }
            let rect = inner.convert(inner.bounds, to: preview.documentView)
            let target = min(max(0, rect.midY - preview.contentView.bounds.height / 2), maxScroll)
            preview.contentView.scroll(to: NSPoint(x: 0, y: target))
            preview.reflectScrolledClipView(preview.contentView)
            say("阶段 2（滚轮打在代码块上）: 起始 origin=\(Int(target))")
            after(0.3) {
                self.phaseStart = self.preview.contentView.bounds.origin.y
                self.sent = 0; self.maxStall = 0; self.lastOrigin = -1
                self.run(phase: 2)
            }
            return
        }

        let pass = moved > 200
        say("阶段 2（滚轮打在代码块上）: 位移=\(Int(moved)) 到底前最长卡顿=\(maxStall) 次事件 → \(pass ? "通过" : "失败")")
        if !pass { failures.append("指针停在代码块上时预览滚不动（位移 \(Int(moved))，事件被内层滚动视图吞掉）") }
        finish()
    }

    private func finish() {
        if failures.isEmpty {
            say("RESULT: PASS — 预览区滚动正常")
            exit(0)
        }
        for item in failures { say("  · \(item)") }
        say("RESULT: FAIL")
        exit(1)
    }

    private func findInnerScrollViews(in view: NSView) -> [NSScrollView] {
        var found: [NSScrollView] = []
        for sub in view.subviews {
            if let scroll = sub as? NSScrollView, scroll !== preview { found.append(scroll) }
            found += findInnerScrollViews(in: sub)
        }
        return found
    }

    private func dispatchWheel(phase: Int) {
        let screenPoint = window.convertPoint(toScreen: point)
        let mainHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height ?? 1080
        guard let cg = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1,
                               wheel1: WHEEL_LINES, wheel2: 0, wheel3: 0) else { return }
        cg.location = CGPoint(x: screenPoint.x, y: mainHeight - screenPoint.y)
        cg.timestamp = mach_absolute_time()
        guard let event = NSEvent(cgEvent: cg) else { return }
        if phase == 2, let inner {
            inner.scrollWheel(with: event)
        } else {
            preview.scrollWheel(with: event)
        }
        sent += 1
    }
}

@main
struct PreviewScrollCheck {
    static func main() {
        let application = NSApplication.shared
        let delegate = ScrollCheckDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
    }
}
