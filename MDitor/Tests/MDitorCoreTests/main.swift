import Foundation

// 独立测试运行器（不依赖 XCTest / SPM，直接用 swiftc 与 MDitorCore 源码一同编译运行）
var passed = 0
var failed = 0

func check(_ cond: Bool, _ name: String) {
    if cond {
        passed += 1
        print("PASS  \(name)")
    } else {
        failed += 1
        print("FAIL  \(name)")
    }
}

func checkEqual<T: Equatable>(_ a: T, _ b: T, _ name: String) {
    if a == b {
        passed += 1
        print("PASS  \(name)")
    } else {
        failed += 1
        print("FAIL  \(name): \(a) != \(b)")
    }
}

// MARK: - 块级解析

let h = MarkdownParser.parse("# Title\n\n## Sub\n\n### H3")
checkEqual(h.count, 3, "heading count")
checkEqual(h[0], Block.heading(level: 1, text: "Title"), "h1")
checkEqual(h[1], Block.heading(level: 2, text: "Sub"), "h2")
checkEqual(h[2], Block.heading(level: 3, text: "H3"), "h3")

let code = MarkdownParser.parse("```swift\nlet x = 1\n```")
checkEqual(code, [Block.code(language: "swift", text: "let x = 1")], "fenced code with lang")

let code2 = MarkdownParser.parse("```\nplain\n```")
checkEqual(code2, [Block.code(language: nil, text: "plain")], "fenced code no lang")

let lists = MarkdownParser.parse("- a\n- b\n\n- [ ] todo\n- [x] done")
checkEqual(lists.count, 2, "list count")
checkEqual(lists[0], Block.unorderedList(["a", "b"]), "unordered list")
checkEqual(
    lists[1],
    Block.taskList([
        TaskItem(checked: false, text: "todo"),
        TaskItem(checked: true, text: "done"),
    ]),
    "task list"
)

let ordered = MarkdownParser.parse("1. first\n2. second")
checkEqual(ordered, [Block.orderedList(["first", "second"])], "ordered list")

let table = MarkdownParser.parse("| a | b |\n| --- | --- |\n| 1 | 2 |")
checkEqual(table, [Block.table(header: ["a", "b"], rows: [["1", "2"]])], "table")

let quote = MarkdownParser.parse("> hello\n> world")
checkEqual(quote, [Block.quote("hello\nworld")], "quote")

checkEqual(MarkdownParser.parse("---"), [Block.divider], "divider")

let para = MarkdownParser.parse("第一行\n第二行")
checkEqual(para, [Block.paragraph("第一行\n第二行")], "paragraph with soft break")

// MARK: - 行内解析

let inline = InlineParser.parse("**bold** and `code` and [link](https://x.com)")
checkEqual(inline.count, 5, "inline segment count")
checkEqual(inline[0], InlineSegment(text: "bold", style: .bold), "bold")
checkEqual(inline[1], InlineSegment(text: " and ", style: .normal), "plain")
checkEqual(inline[2], InlineSegment(text: "code", style: .code), "code")
checkEqual(inline[4], InlineSegment(text: "link", style: .normal, url: "https://x.com"), "link")

let em = InlineParser.parse("*em* and ~~del~~")
checkEqual(em[0], InlineSegment(text: "em", style: .italic), "italic")
checkEqual(em[2], InlineSegment(text: "del", style: .strike), "strike")

checkEqual(
    InlineParser.parse("a ** b"),
    [InlineSegment(text: "a ** b", style: .normal)],
    "unmatched marker stays literal"
)

let nested = InlineParser.parse("**bold with `code` inside**")
check(nested.contains { $0.style == .bold && $0.text == "bold with " }, "nested bold prefix")
check(nested.contains { $0.style == .code && $0.text == "code" }, "code inside bold")

// MARK: - HTML 导出

let html = MarkdownToHTML.render("# T\n\n| a | b |\n| - | - |\n| 1 | 2 |", title: "doc")
check(html.contains("<h1>T</h1>"), "html h1")
check(html.contains("<table>"), "html table")
check(html.contains("<title>doc</title>"), "html title")

let escaped = MarkdownToHTML.escapeHTML("<a & b>")
checkEqual(escaped, "&lt;a &amp; b&gt;", "html escape")

print("\n\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
