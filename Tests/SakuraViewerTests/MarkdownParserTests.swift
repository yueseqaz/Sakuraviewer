import Foundation
import SakuraViewerCore

enum MarkdownParserTests {

    static let name = "MarkdownParserTests"

    static func runAll() {
        runCase(name, "heading") { heading() }
        runCase(name, "paragraphAndInlineStyles") { paragraphAndInlineStyles() }
        runCase(name, "linkAndImage") { linkAndImage() }
        runCase(name, "codeFence") { codeFence() }
        runCase(name, "unorderedList") { unorderedList() }
        runCase(name, "orderedList") { orderedList() }
        runCase(name, "taskList") { taskList() }
        runCase(name, "blockquote") { blockquote() }
        runCase(name, "table") { table() }
        runCase(name, "divider") { divider() }
        runCase(name, "setextHeading") { setextHeading() }
        runCase(name, "headingAnchorStable") { headingAnchorStable() }
    }

    static func heading() {
        let doc = MarkdownParser.parse("# 主标题\n## 二级")
        checkEqual(doc.blocks.count, 2)
        guard case .heading(let level1, _) = doc.blocks[0] else {
            fail("第一个块应为标题")
            return
        }
        guard case .heading(let level2, _) = doc.blocks[1] else {
            fail("第二个块应为标题")
            return
        }
        checkEqual(level1, 1)
        checkEqual(level2, 2)
        checkEqual(doc.toc.count, 2)
        checkEqual(doc.toc[0].title, "主标题")
    }

    static func paragraphAndInlineStyles() {
        let doc = MarkdownParser.parse("这是 **粗体** 与 *斜体* 与 `code` 与 ~~删除~~ 文本")
        guard case .paragraph(let inline) = doc.blocks.first else {
            fail("应为段落")
            return
        }
        check(inline.contains { if case .bold = $0 { return true }; return false }, "应识别粗体")
        check(inline.contains { if case .italic = $0 { return true }; return false }, "应识别斜体")
        check(inline.contains { if case .code = $0 { return true }; return false }, "应识别行内代码")
        check(inline.contains { if case .strikethrough = $0 { return true }; return false }, "应识别删除线")
    }

    static func linkAndImage() {
        let doc = MarkdownParser.parse("[链接](https://example.com)\n\n![图片](pic.png)")
        checkEqual(doc.blocks.count, 2)
        guard case .paragraph(let linkInline) = doc.blocks[0] else {
            fail("第一块应为段落")
            return
        }
        check(linkInline.contains { if case .link(_, let url) = $0 { return url == "https://example.com" }; return false }, "应识别链接")
        guard case .paragraph(let imageInline) = doc.blocks[1] else {
            fail("第二块应为段落")
            return
        }
        check(imageInline.contains { if case .image(_, let url) = $0 { return url == "pic.png" }; return false }, "应识别图片")
    }

    static func codeFence() {
        let source = """
        ```swift
        let x = 1
        print(x)
        ```
        """
        let doc = MarkdownParser.parse(source)
        guard case .codeBlock(let language, let code) = doc.blocks.first else {
            fail("应为代码块")
            return
        }
        checkEqual(language, "swift")
        check(code.contains("let x = 1"))
    }

    static func unorderedList() {
        let source = "- 项目一\n- 项目二\n- 项目三"
        let doc = MarkdownParser.parse(source)
        guard case .list(let ordered, _, let items) = doc.blocks.first else {
            fail("应为列表")
            return
        }
        check(!ordered)
        checkEqual(items.count, 3)
    }

    static func orderedList() {
        let source = "1. 第一\n2. 第二"
        let doc = MarkdownParser.parse(source)
        guard case .list(let ordered, _, let items) = doc.blocks.first else {
            fail("应为列表")
            return
        }
        check(ordered)
        checkEqual(items.count, 2)
    }

    static func taskList() {
        let source = "- [x] 已完成\n- [ ] 未完成"
        let doc = MarkdownParser.parse(source)
        guard case .list(_, _, let items) = doc.blocks.first else {
            fail("应为列表")
            return
        }
        checkEqual(items[0].taskDone, true)
        checkEqual(items[1].taskDone, false)
    }

    static func blockquote() {
        let doc = MarkdownParser.parse("> 引用内容\n> 第二行")
        guard case .quote(let children) = doc.blocks.first else {
            fail("应为引用")
            return
        }
        check(!children.isEmpty)
    }

    static func table() {
        let source = "| 名称 | 数量 |\n|:---|---:|\n| 苹果 | 3 |\n| 樱桃 | 12 |"
        let doc = MarkdownParser.parse(source)
        guard case .table(let table) = doc.blocks.first else {
            fail("应为表格")
            return
        }
        checkEqual(table.header.count, 2)
        checkEqual(table.rows.count, 2)
        checkEqual(table.alignments, [.left, .right], "表格对齐解析")
    }

    static func divider() {
        let doc = MarkdownParser.parse("段落\n\n***\n\n下一段")
        check(doc.blocks.contains { if case .divider = $0 { return true }; return false }, "应识别分隔线")
    }

    static func setextHeading() {
        let doc = MarkdownParser.parse("大标题\n=====\n\n正文")
        guard case .heading(let level, _) = doc.blocks.first else {
            fail("Setext === 应解析为 H1")
            return
        }
        checkEqual(level, 1)
    }

    static func headingAnchorStable() {
        let a = MarkdownParser.headingAnchor(level: 2, text: "标题")
        let b = MarkdownParser.headingAnchor(level: 2, text: "标题")
        let c = MarkdownParser.headingAnchor(level: 3, text: "标题")
        checkEqual(a, b)
        check(a != c)
    }
}
