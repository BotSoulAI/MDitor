import AppKit
import SwiftUI

/// 实时预览：把解析出的块渲染为原生 SwiftUI 视图
struct MarkdownPreview: View {
    let markdown: String

    var body: some View {
        PreviewScrollView(markdown: markdown)
    }
}

/// 预览内容（无滚动容器，供 NSHostingView 使用）
struct PreviewContent: View {
    let markdown: String

    var body: some View {
        let blocks = MarkdownParser.parse(markdown)
        if blocks.isEmpty {
            Text("暂无内容")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 400)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
            .padding(28)
            .frame(maxWidth: 780, alignment: .leading)
            .frame(maxWidth: .infinity)
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
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.75))
                    .frame(width: 3)
                Text(styled(text, size: 14))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(.leading, 10)
                    .padding(.vertical, 2)
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

/// 预览区滚动容器：NSScrollView + NSHostingView，可被 ScrollSync 监听驱动
struct PreviewScrollView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        let hosting = NSHostingView(rootView: PreviewContent(markdown: markdown))
        hosting.autoresizingMask = [.width]
        scroll.documentView = hosting
        ScrollSync.shared.registerPreview(scroll)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let hosting = scroll.documentView as? NSHostingView<PreviewContent> else { return }
        hosting.rootView = PreviewContent(markdown: markdown)
        // 内容宽度 = 视口宽度，高度 = 内容自适应（至少撑满一屏）
        let w = max(scroll.contentView.bounds.width, 100)
        hosting.setFrameSize(NSSize(width: w, height: 0))
        hosting.layoutSubtreeIfNeeded()
        let h = hosting.fittingSize.height
        hosting.setFrameSize(NSSize(width: w, height: max(h, scroll.contentView.bounds.height)))
        hosting.needsLayout = true
    }
}
