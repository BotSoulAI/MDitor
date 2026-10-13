import AppKit
import SwiftUI

/// 实时预览：把解析出的块渲染为原生 SwiftUI 视图
struct MarkdownPreview: View {
    let markdown: String
    var width: CGFloat = 0

    var body: some View {
        PreviewScrollView(markdown: markdown, width: width)
    }
}

/// 预览内容（无滚动容器，供 NSHostingView 使用）。
/// 通过 heightChanged 上报真实布局高度，作为 NSScrollView 文档视图的高度。
///
/// 关键约定：所有块级视图在垂直方向都使用自身理想高度（fixedSize vertical），
/// 因此上报的高度与「宿主给出的高度 proposal」无关 ——
/// 宿主无需先给一个超大高度再回填，也就不会出现「文档高度虚高、视口落进空白区」的白屏闪烁。
struct PreviewContent: View {
    let markdown: String
    var heightChanged: ((CGFloat) -> Void)? = nil

    var body: some View {
        let blocks = MarkdownParser.parse(markdown)
        if blocks.isEmpty {
            Text("暂无内容")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 400)
                .background(heightReporter)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(heightReporter)
        }
    }

    /// 测量本视图实际布局尺寸并上报高度（宽度由宿主容器决定）
    /// 宽度变化时也重新上报：换行变化会改变内容高度
    private var heightReporter: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { heightChanged?(geo.size.height) }
                .onChange(of: geo.size.height) { newHeight in heightChanged?(newHeight) }
                .onChange(of: geo.size.width) { _ in heightChanged?(geo.size.height) }
        }
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            let size: CGFloat = [28, 24, 20, 17, 15, 14][max(0, min(level - 1, 5))]
            Text(styled(text, size: size, baseWeight: .bold))
                .font(.system(size: size, weight: .bold))
                .padding(.top, level <= 2 ? 8 : 0)
                .fixedSize(horizontal: false, vertical: true)

        case .paragraph(let text):
            Text(styled(text, size: 15))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

        case .code(let lang, let code):
            VStack(alignment: .leading, spacing: 0) {
                if let lang, !lang.isEmpty {
                    Text(lang)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                }
                CodeBlockView(code: code)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .quaternarySystemFill)))

        case .quote(let text):
            // 竖条用 background 实现：不参与尺寸计算（否则形状会被拉伸撑高整个引用块）
            Text(styled(text, size: 14))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 13)
                .padding(.vertical, 2)
                .background(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.75))
                        .frame(width: 3)
                        .padding(.trailing, 10)
                }

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        Text(styled(item, size: 15))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(idx + 1).").foregroundStyle(.secondary)
                        Text(styled(item, size: 15))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)

        case .taskList(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: item.checked ? "checkmark.square.fill" : "square")
                            .foregroundStyle(item.checked ? Color.accentColor : Color.secondary)
                        Text(styled(item.text, size: 15))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)

        case .table(let header, let rows):
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                GridRow {
                    ForEach(Array(header.enumerated()), id: \.offset) { _, h in
                        Text(styled(h, size: 13, baseWeight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(padded(row, count: header.count).enumerated()), id: \.offset) { _, cell in
                            Text(styled(cell, size: 13))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .quaternarySystemFill)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor).opacity(0.65)))

        case .divider:
            Divider().padding(.vertical, 4)
        }
    }

    private func padded(_ row: [String], count: Int) -> [String] {
        row.count >= count ? row : row + Array(repeating: "", count: count - row.count)
    }

    private func styled(_ markdown: String, size: CGFloat, baseWeight: Font.Weight = .regular) -> AttributedString {
        var out = AttributedString()
        for seg in InlineParser.parse(markdown) {
            var a = AttributedString(seg.text)
            var font = Font.system(size: size, weight: baseWeight)
            switch seg.style {
            case .bold:
                font = .system(size: size, weight: .bold)
            case .italic:
                font = .system(size: size, weight: baseWeight).italic()
            case .code:
                font = .system(size: size - 1.5, design: .monospaced)
                a.backgroundColor = Color(nsColor: .secondarySystemFill)
                a.foregroundColor = Color(nsColor: .labelColor)
            case .strike:
                a.strikethroughStyle = .single
            case .normal:
                break
            }
            if let url = seg.url, let u = URL(string: url) {
                a.link = u
                a.underlineStyle = .single
                a.foregroundColor = Color.accentColor
            }
            a.font = font
            if a.foregroundColor == nil { a.foregroundColor = .primary }
            out += a
        }
        return out
    }
}

// MARK: - 预览滚动容器

/// 预览区滚动容器：NSScrollView + NSHostingView（documentView）。
///
/// 高度管理：NSHostingView 的高度 == 预览内容的真实布局高度，
/// 由 PreviewContent 的 GeometryReader 上报（applyContentHeight），
/// 不再使用「先设 100000 再回填」的临时高度 ——
/// 那个临时高度会在窗口拖拽缩放期间把可滚动范围放大到 10 万点，
/// 使视口落进内容下方的空白区（用户看到的白屏闪烁）。
struct PreviewScrollView: NSViewRepresentable {
    let markdown: String
    /// 当前分栏实际宽度（由 ContentView 传入）：分栏切换/窗口缩放时该值变化，
    /// 触发 updateNSView 按新宽度重新布局
    var width: CGFloat = 0

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = PreviewContainerScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        scroll.horizontalScrollElasticity = .none

        let hosting = NSHostingView<AnyView>(rootView: AnyView(hostingRoot(for: scroll)))
        hosting.autoresizingMask = []
        // 初始宽度：优先用 SwiftUI 传来的分栏宽度，避免用 0 宽度测量导致高度虚高
        let initialWidth = max(width > 0 ? width : 720, 120)
        hosting.frame = NSRect(x: 0, y: 0, width: initialWidth, height: 1)
        scroll.documentView = hosting
        scroll.hostingView = hosting
        ScrollSync.shared.registerPreview(scroll)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let scroll = scroll as? PreviewContainerScrollView,
              let hosting = scroll.hostingView else { return }
        // 更新根视图（不使用 .id() 强制重建：重建会整树销毁/重建，缩放时会闪白）
        hosting.rootView = AnyView(hostingRoot(for: scroll))
        // 宽度兜底：clip view 宽度可用时由 PreviewContainerScrollView.layout()/tile() 负责贴合并换行
        let w = max(width > 0 ? width : scroll.contentView.bounds.width, 120)
        scroll.applyContentWidth(w)
    }

    private func hostingRoot(for scroll: NSScrollView) -> some View {
        PreviewContent(markdown: markdown) { [weak scroll] height in
            (scroll as? PreviewContainerScrollView)?.applyContentHeight(height)
        }
    }
}

/// 预览专用 NSScrollView：文档视图宽度始终等于可见宽度，高度始终等于内容高度。
final class PreviewContainerScrollView: NSScrollView {
    weak var hostingView: NSHostingView<AnyView>?
    /// 最近一次由 SwiftUI 上报的内容高度
    private var reportedHeight: CGFloat = 0

    override func layout() {
        super.layout()
        syncDocumentWidth()
        syncDocumentHeight()
    }

    /// 滚动条出现/消失会改变 clip view 宽度（传统滚动条会占位），tile() 是
    /// NSScrollView 重算滚动条布局的时机，这里同步一次文档视图宽度
    override func tile() {
        super.tile()
        syncDocumentWidth()
    }

    /// SwiftUI 侧传下来的分栏宽度：仅在自身还测不到可见宽度时作为兜底。
    /// 文档视图宽度以 clip view 宽度为准，否则传统滚动条占位时右侧内容会被裁掉一截。
    func applyContentWidth(_ width: CGFloat) {
        guard let hosting = hostingView else { return }
        guard contentView.bounds.width <= 1 else { return }
        let w = max(width, 1)
        if abs(hosting.frame.width - w) > 0.5 {
            hosting.setFrameSize(NSSize(width: w, height: hosting.frame.height))
            needsLayout = true
        }
    }

    /// 内容高度上报：文档视图高度 = max(内容高度, 可见高度)
    func applyContentHeight(_ height: CGFloat) {
        guard height.isFinite, height > 0 else { return }
        reportedHeight = height
        // 高度变化会让竖直滚动条出现/消失，clip view 宽度随之变化，需要重新贴合
        syncDocumentWidth()
        syncDocumentHeight()
    }

    private func syncDocumentWidth() {
        guard let hosting = hostingView else { return }
        let w = max(contentView.bounds.width, 1)
        if abs(hosting.frame.width - w) > 0.5 {
            hosting.setFrameSize(NSSize(width: w, height: hosting.frame.height))
        }
    }

    private func syncDocumentHeight() {
        guard let hosting = hostingView, reportedHeight > 0 else { return }
        let target = max(reportedHeight, contentView.bounds.height)
        guard abs(hosting.frame.height - target) > 0.5 else { return }
        hosting.setFrameSize(NSSize(width: hosting.frame.width, height: target))
        reflectScrolledClipView(contentView)
    }
}

// MARK: - 代码块

/// 代码块：横向可滚动展示长行，纵向滚轮事件透传给外层预览滚动视图。
///
/// 为什么不用 SwiftUI 的 ScrollView(.horizontal)：它会把纵向滚轮事件吞掉
/// （既滚不动自己，也不传递给外层），导致鼠标停在代码块上时整个预览「滚不动」，
/// 必须把指针移开才能继续滚动 —— 这正是用户报告的预览滚动卡住问题。
struct CodeBlockView: NSViewRepresentable {
    let code: String
    var fontSize: CGFloat = 12.5
    var insets: CGFloat = 12

    func makeNSView(context: Context) -> CodeScrollView {
        let scroll = CodeScrollView()
        scroll.hasHorizontalScroller = true
        scroll.hasVerticalScroller = false
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.horizontalScrollElasticity = .allowed
        scroll.verticalScrollElasticity = .none
        scroll.contentView.drawsBackground = false

        let textView = CodeTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: insets, height: insets)
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = []
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.string = code
        scroll.documentView = textView
        scroll.codeTextView = textView
        return scroll
    }

    func updateNSView(_ scroll: CodeScrollView, context: Context) {
        guard let textView = scroll.codeTextView else { return }
        if textView.font?.pointSize != fontSize {
            textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
            textView.needsLayout = true
        }
        if textView.string != code {
            textView.string = code
            textView.needsLayout = true
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: CodeScrollView, context: Context) -> CGSize? {
        let w = proposal.width ?? nsView.contentView.bounds.width
        return CGSize(width: max(w, 1), height: nsView.codeHeight())
    }
}

/// 只负责横向滚动的 NSScrollView：纵向滚轮事件交给外层滚动视图
final class CodeScrollView: NSScrollView {
    weak var codeTextView: NSTextView?

    /// 代码内容高度（不折行，按行数计算），用于让 SwiftUI 给足高度
    func codeHeight() -> CGFloat {
        guard let textView = codeTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return 24 }
        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container)
        return ceil(max(used.height, 1)) + textView.textContainerInset.height * 2
    }

    override func scrollWheel(with event: NSEvent) {
        // 纵向为主的滚轮事件：交给外层（预览）滚动视图处理
        if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX),
           let outer = enclosingScrollViewAncestor() {
            outer.scrollWheel(with: event)
            return
        }
        super.scrollWheel(with: event)
    }

    private func enclosingScrollViewAncestor() -> NSScrollView? {
        var view: NSView? = superview
        while let current = view {
            if let scrollView = current as? NSScrollView, scrollView !== self { return scrollView }
            view = current.superview
        }
        return nil
    }
}

/// 代码文本视图：自身尺寸贴合文本（不折行），供横向滚动使用
final class CodeTextView: NSTextView {
    override func layout() {
        super.layout()
        guard let layoutManager, let textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        let w = ceil(used.width) + textContainerInset.width * 2
        let h = ceil(used.height) + textContainerInset.height * 2
        if abs(frame.width - w) > 0.5 || abs(frame.height - h) > 0.5 {
            setFrameSize(NSSize(width: max(w, 1), height: max(h, 1)))
        }
    }
}
