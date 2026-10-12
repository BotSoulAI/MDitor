import AppKit

/// 编辑区与预览区的滚动同步协调器：
/// 两边各自监听滚动事件，按“滚动比例”驱动对方，始终保持差不多的行位。
/// 用 isSyncing 标志防止两个方向互相触发造成循环。
final class ScrollSync {
    static let shared = ScrollSync()

    weak var editorScroll: NSScrollView?
    weak var previewScroll: NSScrollView?
    private var isSyncing = false

    private init() {}

    /// 注册编辑区滚动视图并监听其滚动（由 MarkdownTextView 调用）
    func registerEditor(_ scroll: NSScrollView) {
        editorScroll = scroll
        observe(scroll) { [weak self] in self?.editorDidScroll() }
    }

    /// 注册预览区滚动视图并监听其滚动（由 PreviewScrollView 调用）
    func registerPreview(_ scroll: NSScrollView) {
        previewScroll = scroll
        observe(scroll) { [weak self] in self?.previewDidScroll() }
    }

    private func observe(_ scroll: NSScrollView, _ handler: @escaping () -> Void) {
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scroll.contentView,
            queue: .main
        ) { _ in handler() }
    }

    /// 编辑区滚动 → 驱动预览区
    func editorDidScroll() {
        guard !isSyncing, let editor = editorScroll, let preview = previewScroll else { return }
        let r = ratio(of: editor)
        isSyncing = true
        setRatio(r, of: preview)
        isSyncing = false
    }

    /// 预览区滚动 → 驱动编辑区
    func previewDidScroll() {
        guard !isSyncing, let editor = editorScroll, let preview = previewScroll else { return }
        let r = ratio(of: preview)
        isSyncing = true
        setRatio(r, of: editor)
        isSyncing = false
    }

    /// 换文档时两边都回到顶部
    func reset() {
        if let editor = editorScroll {
            editor.contentView.scroll(to: .zero)
            editor.reflectScrolledClipView(editor.contentView)
        }
        if let preview = previewScroll {
            preview.contentView.scroll(to: .zero)
            preview.reflectScrolledClipView(preview.contentView)
        }
    }

    /// 当前滚动位置占可滚动范围的比例（0 = 顶部，1 = 底部）
    private func ratio(of scroll: NSScrollView) -> CGFloat {
        let clip = scroll.contentView
        guard let doc = scroll.documentView else { return 0 }
        let total = doc.frame.height - clip.bounds.height
        guard total > 0 else { return 0 }
        return min(1, max(0, clip.bounds.origin.y / total))
    }

    /// 把目标滚动视图滚动到指定比例位置
    private func setRatio(_ r: CGFloat, of scroll: NSScrollView) {
        let clip = scroll.contentView
        guard let doc = scroll.documentView else { return }
        let total = doc.frame.height - clip.bounds.height
        guard total > 0 else { return }
        clip.scroll(to: NSPoint(x: 0, y: r * total))
        scroll.reflectScrolledClipView(clip)
    }
}
