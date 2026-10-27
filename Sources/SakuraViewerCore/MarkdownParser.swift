import Foundation

// MARK: - 数据模型

/// 行内节点。
public indirect enum MarkdownInline: Equatable {
    case text(String)
    case bold([MarkdownInline])
    case italic([MarkdownInline])
    case boldItalic([MarkdownInline])
    case strikethrough([MarkdownInline])
    case code(String)
    case link(children: [MarkdownInline], url: String)
    case image(alt: String, url: String)
    /// 行内 HTML/自动链接等无法安全渲染的内容，原样以文本展示。
    case literal(String)
}

public struct MarkdownListItem: Equatable {
    public var blocks: [MarkdownBlock]
    /// 任务列表状态：nil 表示普通列表项。
    public var taskDone: Bool?

    public init(blocks: [MarkdownBlock], taskDone: Bool? = nil) {
        self.blocks = blocks
        self.taskDone = taskDone
    }
}

public enum MarkdownTableAlignment: Equatable {
    case left, center, right
}

public struct MarkdownTable: Equatable {
    public var header: [[MarkdownInline]]
    public var rows: [[[MarkdownInline]]]
    public var alignments: [MarkdownTableAlignment]

    public init(header: [[MarkdownInline]], rows: [[[MarkdownInline]]], alignments: [MarkdownTableAlignment]) {
        self.header = header
        self.rows = rows
        self.alignments = alignments
    }
}

/// 块级节点。
public indirect enum MarkdownBlock: Equatable {
    case heading(level: Int, inline: [MarkdownInline])
    case paragraph([MarkdownInline])
    case codeBlock(language: String?, code: String)
    case quote([MarkdownBlock])
    case list(ordered: Bool, start: Int, items: [MarkdownListItem])
    case table(MarkdownTable)
    case divider
    case html(String)
}

/// 目录条目。anchor 与渲染层共享同一稳定哈希。
public struct MarkdownTocEntry: Identifiable, Equatable {
    public let id: Int
    public let level: Int
    public let title: String
    public let anchor: String

    public init(id: Int, level: Int, title: String, anchor: String) {
        self.id = id
        self.level = level
        self.title = title
        self.anchor = anchor
    }
}

public struct MarkdownDocument: Equatable {
    public var blocks: [MarkdownBlock]
    public var toc: [MarkdownTocEntry]

    public init(blocks: [MarkdownBlock], toc: [MarkdownTocEntry]) {
        self.blocks = blocks
        self.toc = toc
    }
}

// MARK: - 解析器

/// 务实的 Markdown 解析器：覆盖标题、段落、围栏代码、引用、有序/无序/任务列表、
/// GFM 表格、分隔线、行内样式（粗体/斜体/删除线/行内代码/链接/图片/自动链接）。
public enum MarkdownParser {

    public static func parse(_ source: String) -> MarkdownDocument {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
                               .replacingOccurrences(of: "\r", with: "\n")
        var lines = normalized.components(separatedBy: "\n")
        let blocks = parseBlocks(&lines)
        var toc: [MarkdownTocEntry] = []
        var index = 0
        collectToc(blocks, into: &toc, counter: &index)
        return MarkdownDocument(blocks: blocks, toc: toc)
    }

    // MARK: 块级解析

    private static func parseBlocks(_ lines: inout [String]) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraphBuffer: [String] = []

        func flushParagraph() {
            guard !paragraphBuffer.isEmpty else { return }
            let text = paragraphBuffer.joined(separator: "\n")
            paragraphBuffer = []
            blocks.append(.paragraph(parseInline(text)))
        }

        var i = 0
        while i < lines.count {
            let rawLine = lines[i]
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // 空行
            if line.isEmpty {
                flushParagraph()
                i += 1
                continue
            }

            // 围栏代码块
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                flushParagraph()
                let fence = String(line.prefix(3))
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    let l = lines[i]
                    if l.trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                        i += 1
                        break
                    }
                    codeLines.append(l)
                    i += 1
                }
                var lang: String? = language.isEmpty ? nil : language
                if let l = lang, l.isEmpty { lang = nil }
                blocks.append(.codeBlock(language: lang, code: codeLines.joined(separator: "\n")))
                continue
            }

            // ATX 标题
            if line.hasPrefix("#"), let hashEnd = line.firstIndex(where: { $0 != "#" }),
               line.distance(from: line.startIndex, to: hashEnd) <= 6 {
                let level = line.distance(from: line.startIndex, to: hashEnd)
                var content = String(line[hashEnd...]).trimmingCharacters(in: .whitespaces)
                // 去除尾部 # 闭合
                while content.hasSuffix("#") {
                    content = String(content.dropLast()).trimmingCharacters(in: .whitespaces)
                }
                blocks.append(.heading(level: level, inline: parseInline(content)))
                i += 1
                continue
            }

            // Setext 标题（优先于分隔线：段落后的 --- 是 h2 下划线）
            if !paragraphBuffer.isEmpty, isSetextUnderline(line) {
                let level = line.hasPrefix("=") ? 1 : 2
                let text = paragraphBuffer.joined(separator: "\n")
                paragraphBuffer = []
                blocks.append(.heading(level: level, inline: parseInline(text)))
                i += 1
                continue
            }

            // 分隔线
            if isHorizontalRule(line) {
                flushParagraph()
                blocks.append(.divider)
                i += 1
                continue
            }

            // 引用
            if line.hasPrefix(">") {
                flushParagraph()
                var quoteLines: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if l.hasPrefix(">") {
                        var inner = String(l.dropFirst())
                        if inner.hasPrefix(" ") { inner.removeFirst() }
                        quoteLines.append(inner)
                        i += 1
                    } else if !l.isEmpty {
                        // 懒惰延续行
                        quoteLines.append(l)
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.quote(parseBlocks(&quoteLines)))
                continue
            }

            // 列表（无序/有序/任务）
            if let listMatch = listMarker(in: line) {
                flushParagraph()
                let (ordered, _) = listMatch
                var items: [MarkdownListItem] = []
                var taskDone: Bool? = nil
                var itemLines: [String] = []

                func flushItem() {
                    guard !itemLines.isEmpty || taskDone != nil else { return }
                    let itemBlocks = parseBlocks(&itemLines)
                    items.append(MarkdownListItem(blocks: itemBlocks, taskDone: taskDone))
                    itemLines = []
                    taskDone = nil
                }

                while i < lines.count {
                    let l = lines[i]
                    let trimmed = l.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty {
                        // 空行：若下一行还是列表则继续（松散列表），否则结束
                        let next = i + 1 < lines.count ? lines[i + 1].trimmingCharacters(in: .whitespaces) : ""
                        if next.isEmpty || (!next.hasPrefix("-") && !next.hasPrefix("*") && !isOrderedMarker(next)) {
                            break
                        }
                        itemLines.append("")
                        i += 1
                        continue
                    }
                    if let m = listMarker(in: trimmed), (l.count - trimmed.count) <= 3 || !itemLines.isEmpty {
                        flushItem()
                        // 任务列表
                        var content = String(trimmed.dropFirst(m.width))
                        if content.hasPrefix(" ") { content.removeFirst() }
                        if content.hasPrefix("[ ] ") || content.hasPrefix("[ ]\t") {
                            taskDone = false
                            content = String(content.dropFirst(4))
                        } else if content.hasPrefix("[x] ") || content.hasPrefix("[X] ") {
                            taskDone = true
                            content = String(content.dropFirst(4))
                        }
                        itemLines.append(content)
                        i += 1
                    } else if l.hasPrefix("  ") || !itemLines.isEmpty {
                        var cont = l
                        var strip = 2
                        while strip > 0, cont.hasPrefix(" ") {
                            cont.removeFirst()
                            strip -= 1
                        }
                        itemLines.append(cont)
                        i += 1
                    } else {
                        break
                    }
                }
                flushItem()
                blocks.append(.list(ordered: ordered, start: 1, items: items))
                continue
            }

            // 表格：当前行含 |，下一行是分隔行
            if line.contains("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                flushParagraph()
                let headerCells = splitTableRow(line)
                let alignments = parseAlignments(splitTableRow(lines[i + 1]))
                i += 2
                var rows: [[[MarkdownInline]]] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if l.isEmpty || !l.contains("|") { break }
                    rows.append(splitTableRow(l).map { parseInline($0) })
                    i += 1
                }
                let header = headerCells.map { parseInline($0) }
                blocks.append(.table(MarkdownTable(header: header, rows: rows, alignments: alignments)))
                continue
            }

            // 行内 HTML 块（简单处理：整块原文展示）
            if line.hasPrefix("<"), !line.hasPrefix("<!--"),
               ["<div", "<p", "<table", "<ul", "<ol", "<br", "<img", "<video", "<iframe", "<script"].contains(where: { line.lowercased().hasPrefix($0) }) {
                flushParagraph()
                var htmlLines = [rawLine]
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    htmlLines.append(lines[i])
                    i += 1
                }
                blocks.append(.html(htmlLines.joined(separator: "\n")))
                continue
            }

            // 普通段落
            paragraphBuffer.append(line)
            i += 1
        }
        flushParagraph()
        return blocks
    }

    // MARK: 辅助判断

    private static func isHorizontalRule(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        if stripped.count < 3 { return false }
        for ch in ["-", "*", "_"] where stripped.allSatisfy({ $0 == Character(ch) }) {
            return true
        }
        return false
    }

    private static func isSetextUnderline(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        guard !stripped.isEmpty else { return false }
        return stripped.allSatisfy { $0 == "=" } || stripped.allSatisfy { $0 == "-" }
    }

    private static func listMarker(in line: String) -> (ordered: Bool, width: Int)? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return (false, 2)
        }
        // 有序标记 1. / 1) 
        if let dotIndex = line.firstIndex(where: { $0 == "." || $0 == ")" }) {
            let prefix = line[line.startIndex..<dotIndex]
            if !prefix.isEmpty, prefix.allSatisfy({ $0.isNumber }),
               let after = line.index(dotIndex, offsetBy: 1, limitedBy: line.endIndex),
               line[after].isWhitespace {
                return (true, line.distance(from: line.startIndex, to: after) + 1)
            }
        }
        return nil
    }

    private static func isOrderedMarker(_ line: String) -> Bool {
        listMarker(in: line)?.ordered == true
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let stripped = line.trimmingCharacters(in: .whitespaces)
        guard stripped.contains("-") else { return false }
        let cells = splitTableRow(stripped)
        return !cells.isEmpty && cells.allSatisfy { cell in
            let c = cell.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ":", with: "")
            return !c.isEmpty && c.allSatisfy { $0 == "-" }
        }
    }

    private static func splitTableRow(_ line: String) -> [String] {
        var l = line.trimmingCharacters(in: .whitespaces)
        if l.hasPrefix("|") { l.removeFirst() }
        if l.hasSuffix("|") { l.removeLast() }
        // 处理转义的 \|
        let placeholder = "\u{FFFC}"
        l = l.replacingOccurrences(of: "\\|", with: placeholder)
        return l.components(separatedBy: "|").map {
            $0.replacingOccurrences(of: placeholder, with: "|").trimmingCharacters(in: .whitespaces)
        }
    }

    private static func parseAlignments(_ cells: [String]) -> [MarkdownTableAlignment] {
        cells.map { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            let startsColon = c.hasPrefix(":")
            let endsColon = c.hasSuffix(":")
            if startsColon && endsColon { return .center }
            if endsColon { return .right }
            return .left
        }
    }

    // MARK: 行内解析

    public static func parseInline(_ source: String) -> [MarkdownInline] {
        parseInlineText(source)
    }

    private static func parseInlineText(_ text: String) -> [MarkdownInline] {
        var nodes: [MarkdownInline] = []
        var buffer = ""
        var i = text.startIndex
        let end = text.endIndex

        func flush() {
            if !buffer.isEmpty {
                nodes.append(.text(buffer))
                buffer = ""
            }
        }

        while i < end {
            let c = text[i]

            // 转义
            if c == "\\", i != text.index(before: end) || true {
                let next = text.index(after: i)
                if next < end, "\\`*_{}[]()#+-.!<>|~".contains(text[next]) {
                    buffer.append(text[next])
                    i = text.index(after: next)
                    continue
                }
                buffer.append(c)
                i = next
                continue
            }

            // 行内代码
            if c == "`" {
                if let code = readCodeSpan(text, from: i) {
                    flush()
                    nodes.append(.code(code.content))
                    i = code.end
                    continue
                }
            }

            // 图片（先于链接判断）
            if c == "!", text[i...].hasPrefix("![") {
                if let image = readLinkSpan(text, from: text.index(after: i), image: true) {
                    flush()
                    nodes.append(.image(alt: image.textContent, url: image.url))
                    i = image.end
                    continue
                }
            }

            // 链接
            if c == "[" {
                if let link = readLinkSpan(text, from: i, image: false) {
                    flush()
                    let children: [MarkdownInline] = link.textContent.isEmpty ? [] : [.text(link.textContent)]
                    nodes.append(.link(children: children, url: link.url))
                    i = link.end
                    continue
                }
            }

            // 自动链接 <http://…>
            if c == "<", text[i...].hasPrefix("<http://") || text[i...].hasPrefix("<https://") {
                if let gt = text[i...].firstIndex(of: ">") {
                    flush()
                    let url = String(text[text.index(after: i)..<gt])
                    nodes.append(.link(children: [.text(url)], url: url))
                    i = text.index(after: gt)
                    continue
                }
            }

            // 强调
            if c == "*" || c == "_" {
                let runLength = delimiterRunLength(text, from: i, of: c)
                if runLength >= 1 {
                    let marker = String(repeating: c, count: min(runLength, 3))
                    if let closed = readEmphasis(text, from: i, marker: marker) {
                        flush()
                        let children = parseInlineText(closed.content)
                        switch marker.count {
                        case 1: nodes.append(.italic(children))
                        case 2: nodes.append(.bold(children))
                        default: nodes.append(.boldItalic(children))
                        }
                        i = closed.end
                        continue
                    }
                }
            }

            // 删除线
            if c == "~", text[i...].hasPrefix("~~") {
                if let closed = readEmphasis(text, from: i, marker: "~~") {
                    flush()
                    nodes.append(.strikethrough(parseInlineText(closed.content)))
                    i = closed.end
                    continue
                }
            }

            // 其余 HTML 字面量（如 <br>、<mark>）原样保留
            if c == "<", !text[i...].hasPrefix("<http") {
                if let gt = text[i...].firstIndex(of: ">"), text.distance(from: i, to: gt) <= 40,
                   text[text.index(after: i)..<gt].allSatisfy({ $0.isLetter || $0 == "/" || $0.isNumber }) {
                    flush()
                    nodes.append(.literal(String(text[i...gt])))
                    i = text.index(after: gt)
                    continue
                }
            }

            buffer.append(c)
            i = text.index(after: i)
        }
        flush()
        return nodes
    }

    private static func delimiterRunLength(_ text: String, from: String.Index, of char: Character) -> Int {
        var count = 0
        var i = from
        while i < text.endIndex, text[i] == char {
            count += 1
            i = text.index(after: i)
        }
        return count
    }

    /// 读取行内代码 `…`（支持双反引号包裹反引号）。
    private static func readCodeSpan(_ text: String, from: String.Index) -> (content: String, end: String.Index)? {
        let run = delimiterRunLength(text, from: from, of: "`")
        let fence = String(repeating: "`", count: run)
        guard let bodyStart = text.index(from, offsetBy: run, limitedBy: text.endIndex) else { return nil }
        guard let close = text.range(of: fence, range: bodyStart..<text.endIndex) else {
            return nil
        }
        var content = String(text[text.index(from, offsetBy: run)..<close.lowerBound])
        // 常见空格剥离
        if content.hasPrefix(" ") && content.hasSuffix(" ") && content.count > 2 {
            content = String(content.dropFirst().dropLast())
        }
        return (content, close.upperBound)
    }

    /// 读取 [text](url) / ![alt](url)。
    private static func readLinkSpan(_ text: String, from openBracket: String.Index, image: Bool) -> (textContent: String, url: String, end: String.Index)? {
        guard let closeBracket = matchingBracket(text, from: openBracket) else { return nil }
        let afterBracket = text.index(after: closeBracket)
        guard afterBracket < text.endIndex, text[afterBracket] == "(" else { return nil }
        guard let closeParen = matchingParen(text, from: afterBracket) else { return nil }
        let inner = String(text[text.index(after: openBracket)..<closeBracket])
        var url = String(text[text.index(after: afterBracket)..<closeParen])
        url = url.trimmingCharacters(in: .whitespaces)
        // 忽略引用式与带标题的写法中的标题部分
        if let spaceIndex = url.firstIndex(where: { $0 == " " }) {
            url = String(url[..<spaceIndex])
        }
        let end = text.index(after: closeParen)
        return (inner, url, end)
    }

    /// 读取强调内容（简单闭合匹配）。
    private static func readEmphasis(_ text: String, from: String.Index, marker: String) -> (content: String, end: String.Index)? {
        let searchStart = text.index(from, offsetBy: marker.count, limitedBy: text.endIndex)
        guard let start = searchStart, start < text.endIndex else { return nil }
        // 空行首不接受
        if text[start] == " " || text[start] == "\n" { return nil }
        guard let closeRange = text.range(of: marker, range: start..<text.endIndex) else { return nil }
        let content = String(text[start..<closeRange.lowerBound])
        if content.isEmpty { return nil }
        if content.hasSuffix(" ") { return nil }
        return (content, closeRange.upperBound)
    }

    private static func matchingBracket(_ text: String, from open: String.Index) -> String.Index? {
        var depth = 0
        var i = open
        while i < text.endIndex {
            let c = text[i]
            if c == "\\" {
                i = text.index(after: i)
            } else if c == "[" {
                depth += 1
            } else if c == "]" {
                depth -= 1
                if depth == 0 { return i }
            } else if c == "\n" {
                return nil
            }
            i = text.index(after: i)
        }
        return nil
    }

    private static func matchingParen(_ text: String, from open: String.Index) -> String.Index? {
        var depth = 0
        var i = open
        while i < text.endIndex {
            let c = text[i]
            if c == "\\" {
                i = text.index(after: i)
            } else if c == "(" {
                depth += 1
            } else if c == ")" {
                depth -= 1
                if depth == 0 { return i }
            } else if c == "\n" && depth == 0 {
                return nil
            }
            i = text.index(after: i)
        }
        return nil
    }

    // MARK: TOC 提取

    private static func collectToc(_ blocks: [MarkdownBlock], into toc: inout [MarkdownTocEntry], counter: inout Int) {
        for block in blocks {
            switch block {
            case .heading(let level, let inline):
                let title = inline.map(inlineText).joined()
                toc.append(MarkdownTocEntry(
                    id: counter, level: level, title: title,
                    anchor: headingAnchor(level: level, text: title)
                ))
                counter += 1
            case .quote(let children):
                collectToc(children, into: &toc, counter: &counter)
            case .list(_, _, let items):
                for item in items {
                    collectToc(item.blocks, into: &toc, counter: &counter)
                }
            default:
                break
            }
        }
    }

    /// 提取行内节点的纯文本。
    public static func inlineText(_ node: MarkdownInline) -> String {
        switch node {
        case .text(let s): return s
        case .code(let s): return s
        case .literal(let s): return s
        case .bold(let c), .italic(let c), .boldItalic(let c), .strikethrough(let c):
            return c.map(inlineText).joined()
        case .link(let children, _):
            return children.isEmpty ? "" : children.map(inlineText).joined()
        case .image(let alt, _):
            return alt
        }
    }

    /// 标题锚点：level+文本 的稳定哈希，渲染层与目录共用。
    public static func headingAnchor(level: Int, text: String) -> String {
        var hash: UInt64 = 5381
        for byte in Array("\(level)#\(text)".utf8) {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return "h-\(hash % 1_000_000_007)"
    }

    /// 统计标题数量（供渲染层对齐 heading id 与 TOC）。
    public static func countHeadings(_ blocks: [MarkdownBlock]) -> Int {
        var count = 0
        for block in blocks {
            switch block {
            case .heading: count += 1
            case .quote(let children): count += countHeadings(children)
            case .list(_, _, let items):
                for item in items { count += countHeadings(item.blocks) }
            default: break
            }
        }
        return count
    }
}
