import AppKit
import SwiftUI

/// 用 NSTextView 实现编辑器（支持撤销、查找、光标选区），与 EditorState 双向同步
struct MarkdownTextView: NSViewRepresentable {
    @ObservedObject var editor: EditorState

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let tv = scroll.documentView as? NSTextView else { return scroll }
        context.coordinator.parent = self

        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.allowsUndo = true
        tv.font = .monospacedSystemFont(ofSize: 13.5, weight: .regular)
        tv.textColor = .textColor
        tv.backgroundColor = .textBackgroundColor
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.usesFindBar = true
        tv.textContainerInset = NSSize(width: 12, height: 12)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        // 文本容器宽度跟随视图：窗口缩放时实时换行，而不是宽度确定后才重排
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: tv.frame.width, height: .greatestFiniteMagnitude)
        // 窗口缩放过程中强制按当前宽度重新排版
        NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification, object: scroll, queue: .main
        ) { [weak scroll] _ in
            guard let scroll,
                  let tv = scroll.documentView as? NSTextView,
                  let container = tv.textContainer else { return }
            container.containerSize = NSSize(width: max(tv.frame.width, 50), height: .greatestFiniteMagnitude)
            tv.layoutManager?.ensureLayout(for: container)
            tv.needsDisplay = true
        }

        editor.textView = tv
        tv.string = editor.text
        // 注册到滚动同步器：编辑区滚动时驱动预览区
        ScrollSync.shared.registerEditor(scroll)
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = nsView.documentView as? NSTextView else { return }
        if tv.string != editor.text {
            let sel = tv.selectedRange()
            tv.string = editor.text
            let clamped = min(sel.location, (editor.text as NSString).length)
            tv.setSelectedRange(NSRange(location: clamped, length: 0))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView?

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView, let parent else { return }
            parent.editor.text = tv.string
        }
    }
}
