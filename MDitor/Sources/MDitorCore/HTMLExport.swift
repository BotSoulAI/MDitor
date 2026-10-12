import Foundation

/// Markdown → HTML 导出（轻量实现）
public enum MarkdownToHTML {
    public static func render(_ markdown: String, title: String) -> String {
        var body: [String] = []
        for block in MarkdownParser.parse(markdown) {
            switch block {
            case .heading(let level, let text):
                let tag = "h\(min(max(level, 1), 6))"
                body.append("<\(tag)>\(inlineHTML(text))</\(tag)>")
            case .paragraph(let text):
                body.append("<p>\(inlineHTML(text))</p>")
            case .code(let lang, let text):
                let cls = lang.map { " class=\"language-\(escapeHTML($0))\"" } ?? ""
                body.append("<pre><code\(cls)>\(escapeHTML(text))</code></pre>")
            case .quote(let text):
                body.append("<blockquote><p>\(inlineHTML(text))</p></blockquote>")
            case .unorderedList(let items):
                body.append("<ul>\(items.map { "<li>\(inlineHTML($0))</li>" }.joined())</ul>")
            case .orderedList(let items):
                body.append("<ol>\(items.map { "<li>\(inlineHTML($0))</li>" }.joined())</ol>")
            case .taskList(let items):
                let lis = items.map { item in
                    let mark = item.checked ? "☑" : "☐"
                    return "<li>\(mark) \(inlineHTML(item.text))</li>"
                }.joined()
                body.append("<ul class=\"task-list\">\(lis)</ul>")
            case .table(let header, let rows):
                var t = "<table><thead><tr>"
                for h in header { t += "<th>\(inlineHTML(h))</th>" }
                t += "</tr></thead><tbody>"
                for row in rows {
                    t += "<tr>"
                    for cell in row { t += "<td>\(inlineHTML(cell))</td>" }
                    t += "</tr>"
                }
                t += "</tbody></table>"
                body.append(t)
            case .divider:
                body.append("<hr>")
            }
        }

        let css = """
        body { max-width: 780px; margin: 48px auto; padding: 0 24px; font-family: -apple-system, "PingFang SC", "Helvetica Neue", sans-serif; line-height: 1.7; color: #1d1d1f; }
        h1, h2, h3, h4, h5, h6 { line-height: 1.3; margin: 1.4em 0 0.5em; }
        pre { background: #f5f5f7; padding: 14px 16px; border-radius: 8px; overflow-x: auto; }
        code { font-family: "SF Mono", Menlo, monospace; font-size: 0.9em; background: #f5f5f7; padding: 2px 5px; border-radius: 4px; }
        pre code { background: none; padding: 0; }
        blockquote { border-left: 3px solid #d2d2d7; margin: 0; padding-left: 16px; color: #6e6e73; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #e5e5ea; padding: 8px 12px; text-align: left; }
        th { background: #f5f5f7; }
        a { color: #0a66c2; }
        hr { border: none; border-top: 1px solid #e5e5ea; margin: 2em 0; }
        .task-list { list-style: none; padding-left: 0; }
        """

        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escapeHTML(title))</title>
        <style>\(css)</style>
        </head>
        <body>
        \(body.joined(separator: "\n"))
        </body>
        </html>
        """
    }

    private static func inlineHTML(_ text: String) -> String {
        var out = ""
        for seg in InlineParser.parse(text) {
            var s = escapeHTML(seg.text)
            switch seg.style {
            case .bold: s = "<strong>\(s)</strong>"
            case .italic: s = "<em>\(s)</em>"
            case .code: s = "<code>\(s)</code>"
            case .strike: s = "<del>\(s)</del>"
            case .normal: break
            }
            if let url = seg.url {
                s = "<a href=\"\(escapeHTML(url))\">\(s)</a>"
            }
            out += s
        }
        return out
    }

    public static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
