import Foundation

public enum InlineStyle: Equatable {
    case normal, bold, italic, code, strike
}

public struct InlineSegment: Equatable {
    public let text: String
    public let style: InlineStyle
    public let url: String?

    public init(text: String, style: InlineStyle, url: String? = nil) {
        self.text = text
        self.style = style
        self.url = url
    }
}

/// 行内 Markdown 解析：粗体、斜体、行内代码、删除线、链接
public enum InlineParser {
    public static func parse(_ s: String) -> [InlineSegment] {
        let chars = Array(s)
        var segments: [InlineSegment] = []
        var plain = ""
        let n = chars.count
        var i = 0

        func flush() {
            if !plain.isEmpty {
                segments.append(InlineSegment(text: plain, style: .normal))
                plain = ""
            }
        }

        func findClose(from: Int, marker: [Character]) -> Int? {
            var j = from
            while j < n {
                if chars[j] == "\\" { j += 2; continue }
                if j + marker.count <= n, Array(chars[j..<(j + marker.count)]) == marker {
                    return j
                }
                j += 1
            }
            return nil
        }

        while i < n {
            let c = chars[i]

            // 转义
            if c == "\\", i + 1 < n, "`*~[]()\\".contains(chars[i + 1]) {
                plain.append(chars[i + 1])
                i += 2
                continue
            }

            // 行内代码 `...`
            if c == "`" {
                var run = 1
                while i + run < n && chars[i + run] == "`" { run += 1 }
                if let close = findClose(from: i + run, marker: Array(repeating: "`", count: run)) {
                    flush()
                    segments.append(InlineSegment(text: String(chars[(i + run)..<close]), style: .code))
                    i = close + run
                    continue
                }
            }

            // 粗体 **...**
            if c == "*", i + 1 < n, chars[i + 1] == "*" {
                if let close = findClose(from: i + 2, marker: ["*", "*"]) {
                    flush()
                    for seg in parse(String(chars[(i + 2)..<close])) {
                        segments.append(InlineSegment(
                            text: seg.text,
                            style: seg.style == .normal ? .bold : seg.style,
                            url: seg.url
                        ))
                    }
                    i = close + 2
                    continue
                }
            }

            // 斜体 *...*
            if c == "*" {
                if i + 1 < n && chars[i + 1] == "*" {
                    plain.append(c)
                    i += 1
                    continue
                }
                if let close = findClose(from: i + 1, marker: ["*"]) {
                    // 闭合的 * 不能是 ** 的一部分
                    if close + 1 < n && chars[close + 1] == "*" && (close - i) == 1 {
                        plain.append(c)
                        i += 1
                        continue
                    }
                    flush()
                    for seg in parse(String(chars[(i + 1)..<close])) {
                        segments.append(InlineSegment(
                            text: seg.text,
                            style: seg.style == .normal ? .italic : seg.style,
                            url: seg.url
                        ))
                    }
                    i = close + 1
                    continue
                }
            }

            // 删除线 ~~...~~
            if c == "~", i + 1 < n, chars[i + 1] == "~" {
                if let close = findClose(from: i + 2, marker: ["~", "~"]) {
                    flush()
                    segments.append(InlineSegment(text: String(chars[(i + 2)..<close]), style: .strike))
                    i = close + 2
                    continue
                }
            }

            // 链接 [text](url)
            if c == "[" {
                if let closeBracket = findClose(from: i + 1, marker: ["]"]),
                   closeBracket + 1 < n, chars[closeBracket + 1] == "(" {
                    var j = closeBracket + 2
                    var depth = 1
                    var urlChars: [Character] = []
                    while j < n && depth > 0 {
                        let ch = chars[j]
                        if ch == ")" { depth -= 1; if depth == 0 { break } }
                        if ch == "(" { depth += 1 }
                        urlChars.append(ch)
                        j += 1
                    }
                    if depth == 0 {
                        let label = String(chars[(i + 1)..<closeBracket])
                        var url = String(urlChars).trimmingCharacters(in: .whitespaces)
                        if url.hasPrefix("<"), url.hasSuffix(">") {
                            url = String(url.dropFirst().dropLast())
                        }
                        if !url.isEmpty {
                            flush()
                            let labelSegs = parse(label)
                            if labelSegs.isEmpty {
                                segments.append(InlineSegment(text: "", style: .normal, url: url))
                            } else {
                                for seg in labelSegs {
                                    segments.append(InlineSegment(text: seg.text, style: seg.style, url: url))
                                }
                            }
                            i = j + 1
                            continue
                        }
                    }
                }
            }

            plain.append(c)
            i += 1
        }
        flush()
        return segments
    }
}
