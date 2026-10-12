import Foundation

/// 块级 Markdown 结构
public enum Block: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case code(language: String?, text: String)
    case quote(String)
    case unorderedList([String])
    case orderedList([String])
    case taskList([TaskItem])
    case table(header: [String], rows: [[String]])
    case divider
}

public struct TaskItem: Equatable {
    public let checked: Bool
    public let text: String

    public init(checked: Bool, text: String) {
        self.checked = checked
        self.text = text
    }
}

/// 把 Markdown 文本解析为块级结构（无外部依赖，纯 Foundation）
public enum MarkdownParser {
    public static func parse(_ markdown: String) -> [Block] {
        let lines = markdown.components(separatedBy: "\n")
        var blocks: [Block] = []
        var i = 0
        let n = lines.count

        func trim(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespaces)
        }

        while i < n {
            let raw = lines[i]
            let line = trim(raw)

            if line.isEmpty {
                i += 1
                continue
            }

            // 围栏代码块
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                let fence = line.hasPrefix("```") ? "```" : "~~~"
                let lang = line.dropFirst(fence.count).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                i += 1
                while i < n && !trim(lines[i]).hasPrefix(fence) {
                    code.append(lines[i])
                    i += 1
                }
                i += 1 // 跳过闭合围栏（或到末尾）
                blocks.append(.code(language: lang.isEmpty ? nil : lang, text: code.joined(separator: "\n")))
                continue
            }

            // 标题
            if raw.hasPrefix("#") {
                let hashCount = raw.prefix(while: { $0 == "#" }).count
                if hashCount <= 6 {
                    let content = trim(String(raw.dropFirst(hashCount)))
                    blocks.append(.heading(level: hashCount, text: content))
                    i += 1
                    continue
                }
            }

            // 分隔线
            if line == "---" || line == "***" || line == "___" {
                blocks.append(.divider)
                i += 1
                continue
            }

            // 引用
            if raw.hasPrefix(">") {
                var quote: [String] = []
                while i < n && lines[i].hasPrefix(">") {
                    quote.append(trim(String(lines[i].dropFirst())))
                    i += 1
                }
                blocks.append(.quote(quote.joined(separator: "\n")))
                continue
            }

            // 无序列表 / 任务清单
            if isBullet(line) {
                var items: [String] = []
                var tasks: [TaskItem] = []
                var isTask = false
                while i < n {
                    let t = trim(lines[i])
                    guard isBullet(t) else { break }
                    var content = String(t.dropFirst(2))
                    if content.hasPrefix("[ ] ") {
                        tasks.append(TaskItem(checked: false, text: String(content.dropFirst(4))))
                        isTask = true
                    } else if content.hasPrefix("[x] ") || content.hasPrefix("[X] ") {
                        tasks.append(TaskItem(checked: true, text: String(content.dropFirst(4))))
                        isTask = true
                    } else {
                        items.append(content)
                    }
                    i += 1
                }
                if isTask {
                    blocks.append(.taskList(tasks))
                } else {
                    blocks.append(.unorderedList(items))
                }
                continue
            }

            // 有序列表
            if isOrderedStart(line) {
                var items: [String] = []
                while i < n {
                    let t = trim(lines[i])
                    guard isOrderedStart(t) else { break }
                    items.append(orderedContent(t))
                    i += 1
                }
                blocks.append(.orderedList(items))
                continue
            }

            // 表格（需要下一行是分隔行）
            if line.hasPrefix("|") && i + 1 < n && isTableSeparator(lines[i + 1]) {
                let header = parseRow(line)
                i += 2
                var rows: [[String]] = []
                while i < n {
                    let t = trim(lines[i])
                    guard t.hasPrefix("|") else { break }
                    rows.append(parseRow(t))
                    i += 1
                }
                blocks.append(.table(header: header, rows: rows))
                continue
            }

            // 段落
            var para: [String] = [raw]
            i += 1
            while i < n {
                let t = lines[i]
                let tt = trim(t)
                if tt.isEmpty { break }
                if tt.hasPrefix("```") || tt.hasPrefix("~~~") { break }
                if t.hasPrefix("#") && tt.prefix(while: { $0 == "#" }).count <= 6 { break }
                if t.hasPrefix(">") { break }
                if isBullet(tt) || isOrderedStart(tt) { break }
                if tt == "---" || tt == "***" || tt == "___" { break }
                if tt.hasPrefix("|") && i + 1 < n && isTableSeparator(trim(lines[i + 1])) { break }
                para.append(t)
                i += 1
            }
            blocks.append(.paragraph(para.joined(separator: "\n")))
        }
        return blocks
    }

    private static func isBullet(_ s: String) -> Bool {
        s.hasPrefix("- ") || s.hasPrefix("* ") || s.hasPrefix("+ ")
    }

    private static func isOrderedStart(_ s: String) -> Bool {
        guard let dot = s.firstIndex(of: ".") else { return false }
        if dot == s.startIndex { return false }
        let num = s[s.startIndex..<dot]
        guard !num.isEmpty, num.allSatisfy({ $0.isNumber }) else { return false }
        let after = s[s.index(after: dot)...]
        return after.hasPrefix(" ")
    }

    private static func orderedContent(_ s: String) -> String {
        guard let dot = s.firstIndex(of: ".") else { return s }
        return String(s[s.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
    }

    private static func isTableSeparator(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.contains("-") else { return false }
        let allowed = CharacterSet(charactersIn: "|:- ")
        return t.rangeOfCharacter(from: allowed.inverted) == nil
    }

    private static func parseRow(_ s: String) -> [String] {
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
