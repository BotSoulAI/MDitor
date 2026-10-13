import AppKit
import SwiftUI

/// 实时预览：把解析出的块渲染为原生 SwiftUI 视图
struct MarkdownPreview: View {
    let markdown: String

    var body: some View {
        PreviewScrollView(markdown: markdown)
    }
}

/// 预览内容（无滚动容器，供 NSHostingView 使用）。
/// 通过 heightChanged 上报真实布局高度，解决 NSHostingView 无法可靠测量内容高度的问题。
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
    private var heightReporter: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { heightChanged?(geo.size.height) }
                .onChange(of: geo.size.height) { newHeight in heightChanged?(newHeight) }
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
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(size: 12.5, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .quaternarySystemFill)))

        case .quote(let text):
            // 竖条用 background 实现：不参与尺寸计算（否则形状会被拉伸撑高整个引用块）
            Text(styled(text, size: 14))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                    }
                }
            }

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(idx + 1).").foregroundStyle(.secondary)
                        Text(styled(item, size: 15))
                            .textSelection(.enabled)
                    }
                }
            }

        case .taskList(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: item.checked ? "checkmark.square.fill" : "square")
                            .foregroundStyle(item.checked ? Color.accentColor : Color.secondary)
                        Text(styled(item.text, size: 15))
                            .textSelection(.enabled)
                    }
                }
            }

        case .table(let header, let rows):
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                GridRow {
                    ForEach(Array(header.enumerated()), id: \.offset) { _, h in
                        Text(styled(h, size: 13, baseWeight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(padded(row, count: header.count).enumerated()), id: \.offset) { _, cell in
                            Text(styled(cell, size: 13))
                                .frame(maxWidth: .infinity, alignment: .leading)
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

/// 预览区滚动容器：NSScrollView + NSHostingView，可被 ScrollSync 监听驱动。
/// documentView 高度由 PreviewContent 上报的真实布局高度决定，保证内容完整显示。
struct PreviewScrollView: NSViewRepresentable {
    let markdown: String

    private func heightUpdater(for scroll: NSScrollView) -> (CGFloat) -> Void {
        { height in
            DispatchQueue.main.async {
                guard let doc = scroll.documentView else { return }
                let target = max(height, scroll.contentView.bounds.height)
                if abs(doc.frame.height - target) > 1 {
                    doc.setFrameSize(NSSize(width: doc.frame.width, height: target))
                    scroll.reflectScrolledClipView(scroll.contentView)
                }
            }
        }
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        let hosting = NSHostingView(
            rootView: PreviewContent(markdown: markdown, heightChanged: heightUpdater(for: scroll))
        )
        hosting.autoresizingMask = [.width]
        // 初始给一个足够大的高度，让 SwiftUI 内容完整布局、测得真实内容高度
        hosting.setFrameSize(NSSize(width: 800, height: 10000))
        scroll.documentView = hosting
        // 窗口尺寸变化时按新宽度重新布局预览内容（否则内容不换行、被裁剪隐藏）
        NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification, object: scroll, queue: .main
        ) { [weak scroll] _ in
            guard let scroll,
                  let hosting = scroll.documentView as? NSHostingView<PreviewContent> else { return }
            let w = max(scroll.contentView.bounds.width, 100)
            if abs(hosting.frame.width - w) > 1 {
                hosting.setFrameSize(NSSize(width: w, height: hosting.frame.height))
                hosting.needsLayout = true
            }
        }
        ScrollSync.shared.registerPreview(scroll)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let hosting = scroll.documentView as? NSHostingView<PreviewContent> else { return }
        hosting.rootView = PreviewContent(markdown: markdown, heightChanged: heightUpdater(for: scroll))
        // 只跟随视口宽度，高度保持由内容上报维护（不得重置为固定值，
        // 否则内容高度不变时 onChange 不触发、高度会停留在错误值上）
        let w = max(scroll.contentView.bounds.width, 100)
        hosting.setFrameSize(NSSize(width: w, height: hosting.frame.height))
        hosting.needsLayout = true
    }
}
