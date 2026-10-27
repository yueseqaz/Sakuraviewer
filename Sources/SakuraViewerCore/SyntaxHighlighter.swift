import Foundation
import AppKit

// MARK: - 语言识别

/// 支持语法高亮的语言集合。
public enum CodeLanguage: String, CaseIterable, Sendable {
    case swift, javascript, typescript, python, java, c, cpp, go, rust
    case html, css, json, yaml, xml, shell, sql, markdown, plain

    /// 按文件扩展名识别。
    public init(fileExtension ext: String) {
        self = Self.fromExtension(ext) ?? .plain
    }

    public static func fromExtension(_ ext: String) -> CodeLanguage? {
        switch ext.lowercased() {
        case "swift": return .swift
        case "js", "mjs", "cjs", "jsx": return .javascript
        case "ts", "tsx": return .typescript
        case "py", "pyw": return .python
        case "java", "kt", "kts", "scala", "cs", "dart": return .java
        case "c", "h": return .c
        case "cpp", "cc", "cxx", "hpp", "hh", "mm": return .cpp
        case "go": return .go
        case "rs": return .rust
        case "html", "htm", "vue", "svelte": return .html
        case "css", "scss", "less": return .css
        case "json", "jsonc": return .json
        case "yaml", "yml", "toml": return .yaml
        case "xml", "plist", "svg", "xsl": return .xml
        case "sh", "bash", "zsh", "fish", "bat", "ps1": return .shell
        case "sql": return .sql
        case "md", "markdown": return .markdown
        default: return nil
        }
    }

    /// Markdown 代码块围栏语言标识（支持别名）。
    public init(fence language: String?) {
        guard let language, !language.isEmpty else {
            self = .plain
            return
        }
        let normalized = language.lowercased()
        let aliases: [String: CodeLanguage] = [
            "js": .javascript, "node": .javascript, "javascript": .javascript,
            "ts": .typescript, "typescript": .typescript,
            "py": .python, "python": .python, "python3": .python,
            "sh": .shell, "bash": .shell, "shell": .shell, "zsh": .shell, "console": .shell,
            "yml": .yaml, "yaml": .yaml,
            "c++": .cpp, "cxx": .cpp, "objc": .c, "objective-c": .c,
            "golang": .go, "rust": .rust, "rs": .rust,
            "kotlin": .java, "java": .java, "csharp": .java, "c#": .java,
            "html": .html, "xml": .xml, "css": .css, "scss": .css,
            "json": .json, "json5": .json, "jsonc": .json,
            "sql": .sql, "md": .markdown, "markdown": .markdown,
            "swift": .swift, "c": .c, "cpp": .cpp,
        ]
        self = aliases[normalized] ?? .plain
    }

    public var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .python: return "Python"
        case .java: return "Java"
        case .c: return "C"
        case .cpp: return "C++"
        case .go: return "Go"
        case .rust: return "Rust"
        case .html: return "HTML"
        case .css: return "CSS"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .xml: return "XML"
        case .shell: return "Shell"
        case .sql: return "SQL"
        case .markdown: return "Markdown"
        case .plain: return "纯文本"
        }
    }
}

// MARK: - Token 模型

public enum TokenKind: Equatable, Sendable {
    case plain
    case keyword
    case type
    case string
    case comment
    case number
    case function
    case property   // JSON key / CSS 属性 / YAML 键
    case tag        // HTML/XML 标签名
}

public struct TokenRange: Equatable, Sendable {
    public let range: Range<String.Index>
    public let kind: TokenKind

    public init(range: Range<String.Index>, kind: TokenKind) {
        self.range = range
        self.kind = kind
    }
}

// MARK: - 主题

/// 高亮配色：随系统亮/暗模式自动切换。
public struct HighlightTheme {
    public var plain: NSColor
    public var keyword: NSColor
    public var type: NSColor
    public var string: NSColor
    public var comment: NSColor
    public var number: NSColor
    public var function: NSColor
    public var property: NSColor
    public var tag: NSColor

    public init(
        plain: NSColor, keyword: NSColor, type: NSColor, string: NSColor,
        comment: NSColor, number: NSColor, function: NSColor, property: NSColor, tag: NSColor
    ) {
        self.plain = plain
        self.keyword = keyword
        self.type = type
        self.string = string
        self.comment = comment
        self.number = number
        self.function = function
        self.property = property
        self.tag = tag
    }

    /// 动态颜色工具。
    private static func dynamic(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> NSColor {
        NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255, alpha: 1)
        }
    }

    /// Sakura 主题：樱花粉关键字 + 柔和的代码配色。
    public static let sakura = HighlightTheme(
        plain: .labelColor,
        keyword: dynamic(light: (199, 68, 129), dark: (240, 130, 180)),
        type: dynamic(light: (146, 92, 200), dark: (185, 140, 235)),
        string: dynamic(light: (64, 132, 84), dark: (126, 199, 140)),
        comment: dynamic(light: (128, 128, 134), dark: (140, 145, 152)),
        number: dynamic(light: (52, 116, 196), dark: (110, 170, 240)),
        function: dynamic(light: (24, 116, 160), dark: (100, 190, 225)),
        property: dynamic(light: (178, 96, 36), dark: (235, 155, 95)),
        tag: dynamic(light: (199, 68, 129), dark: (240, 130, 180))
    )

    public func color(for kind: TokenKind) -> NSColor {
        switch kind {
        case .plain: return plain
        case .keyword: return keyword
        case .type: return type
        case .string: return string
        case .comment: return comment
        case .number: return number
        case .function: return function
        case .property: return property
        case .tag: return tag
        }
    }
}

// MARK: - 高亮器

/// 轻量级语法高亮扫描器：单遍状态机，识别注释/字符串/数字/关键字/类型/函数。
/// 为查看器场景设计（只读展示），追求零崩溃与足够好的视觉效果。
public enum SyntaxHighlighter {

    // MARK: 语言配置

    struct LanguageSyntax {
        var lineComments: [String] = []
        var blockComments: [(open: String, close: String)] = []
        var stringDelimiters: [String] = ["\""]
        var rawMultilineStrings: [String] = []   // 可跨行的字符串（反引号 / 三引号）
        var keywords: Set<String> = []
        var types: Set<String> = []
        var caseInsensitive = false
        var propertyAfterColon = false           // 字符串/标识符后接冒号视为属性（JSON/YAML/CSS）
        var propertyAtLineStart = false          // 行首标识符后接冒号视为属性（YAML）
        var isMarkup = false                     // HTML/XML 标签状态机
        var preprocessorPrefix: String? = nil    // C 系 # 指令
    }

    public static func tokenize(_ text: String, language: CodeLanguage) -> [TokenRange] {
        guard language != .plain, !text.isEmpty else { return [] }
        switch language {
        case .html, .xml: return tokenizeMarkup(text)
        default: break
        }
        let syntax = Self.syntax(for: language)
        var tokens = scan(text: text, syntax: syntax)
        if syntax.propertyAfterColon {
            tokens = reclassifyProperties(text: text, tokens: tokens)
        }
        return tokens
    }

    /// 字符串后紧跟冒号 → 视为属性名（JSON/CSS 键）。
    private static func reclassifyProperties(text: String, tokens: [TokenRange]) -> [TokenRange] {
        let end = text.endIndex
        return tokens.map { token in
            guard token.kind == .string else { return token }
            var k = token.range.upperBound
            while k < end, text[k] == " " || text[k] == "\t" {
                k = text.index(after: k)
            }
            if k < end, text[k] == ":" {
                return TokenRange(range: token.range, kind: .property)
            }
            return token
        }
    }

    /// 生成带主题配色的高亮 NSAttributedString。
    public static func attributed(
        _ text: String,
        language: CodeLanguage,
        theme: HighlightTheme = .sakura,
        font: NSFont
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text)
        let full = NSRange(location: 0, length: (text as NSString).length)
        result.addAttributes([
            .font: font,
            .foregroundColor: theme.plain,
        ], range: full)

        for token in tokenize(text, language: language) {
            let nsRange = NSRange(token.range, in: text)
            var attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: theme.color(for: token.kind)
            ]
            if token.kind == .comment {
                attributes[.obliqueness] = 0.15
            }
            result.setAttributes(result.attributes(at: nsRange.location, effectiveRange: nil).merging(attributes) { _, new in new }, range: nsRange)
        }
        return result
    }

    // MARK: 通用扫描器

    private static func scan(text: String, syntax: LanguageSyntax) -> [TokenRange] {
        var tokens: [TokenRange] = []
        var i = text.startIndex
        let end = text.endIndex
        var lineStartIndex = i

        func isIdentChar(_ c: Character) -> Bool {
            c.isLetter || c.isNumber || c == "_"
        }

        while i < end {
            let c = text[i]

            // 预处理器指令（# 开头，行首空白后）
            if let prefix = syntax.preprocessorPrefix, c == Character(prefix) {
                let lineEnd = text[i...].firstIndex(of: "\n") ?? end
                tokens.append(TokenRange(range: i..<lineEnd, kind: .keyword))
                i = lineEnd
                continue
            }

            // 行注释
            if let comment = syntax.lineComments.first(where: { text[i...].hasPrefix($0) }) {
                let lineEnd = text[i...].firstIndex(of: "\n") ?? end
                if lineEnd > i {
                    tokens.append(TokenRange(range: i..<lineEnd, kind: .comment))
                }
                i = lineEnd
                continue
            }

            // 块注释
            if let block = syntax.blockComments.first(where: { text[i...].hasPrefix($0.open) }) {
                let searchStart = text.index(i, offsetBy: block.open.count, limitedBy: end) ?? end
                let closeEnd: String.Index
                if let found = text.range(of: block.close, range: searchStart..<end)?.upperBound {
                    closeEnd = found
                } else {
                    closeEnd = end
                }
                tokens.append(TokenRange(range: i..<closeEnd, kind: .comment))
                i = closeEnd
                continue
            }

            // 原始多行字符串（` 与三引号）
            if let raw = syntax.rawMultilineStrings.first(where: { text[i...].hasPrefix($0) }) {
                let searchStart = text.index(i, offsetBy: raw.count, limitedBy: end) ?? end
                let closeEnd = text.range(of: raw, range: searchStart..<end)?.upperBound ?? end
                tokens.append(TokenRange(range: i..<closeEnd, kind: .string))
                i = closeEnd
                continue
            }

            // 普通字符串（处理转义，不跨行）
            if let delim = syntax.stringDelimiters.first(where: { text[i...].hasPrefix($0) }) {
                var j = text.index(i, offsetBy: delim.count, limitedBy: end) ?? end
                var escaped = false
                while j < end {
                    let sc = text[j]
                    if escaped {
                        escaped = false
                    } else if sc == "\\" {
                        escaped = true
                    } else if text[j...].hasPrefix(delim) {
                        j = text.index(j, offsetBy: delim.count, limitedBy: end) ?? end
                        break
                    } else if sc == "\n" {
                        break // 未闭合字符串，止于行尾
                    }
                    j = text.index(after: j)
                }
                tokens.append(TokenRange(range: i..<j, kind: .string))
                i = j
                continue
            }

            // 标识符 / 关键字
            if isIdentStart(c) {
                var j = i
                while j < end, isIdentChar(text[j]) {
                    j = text.index(after: j)
                }
                let word = String(text[i..<j])
                tokens.append(TokenRange(range: i..<j, kind: classify(
                    word: word, text: text, at: j, syntax: syntax,
                    lineStart: i == lineStartIndex || precededOnlyByWhitespace(text, from: lineStartIndex, to: i)
                )))
                i = j
                continue
            }

            // 数字
            if c.isNumber || (c == "." && text.index(after: i) < end && text[text.index(after: i)].isNumber) {
                var j = i
                var previous = Character(" ")
                while j < end {
                    let nc = text[j]
                    if nc.isNumber || nc.isLetter || nc == "." || nc == "_" {
                        previous = nc
                        j = text.index(after: j)
                    } else if (nc == "+" || nc == "-") && (previous == "e" || previous == "E" || previous == "p" || previous == "P") {
                        previous = nc
                        j = text.index(after: j)
                    } else {
                        break
                    }
                }
                tokens.append(TokenRange(range: i..<j, kind: .number))
                i = j
                continue
            }

            if c == "\n" {
                i = text.index(after: i)
                lineStartIndex = i
                continue
            }

            i = text.index(after: i)
        }
        return tokens
    }

    private static func isIdentStart(_ c: Character) -> Bool {
        c.isLetter || c == "_"
    }

    private static func precededOnlyByWhitespace(_ text: String, from start: String.Index, to position: String.Index) -> Bool {
        var k = start
        while k < position {
            let c = text[k]
            if c != " " && c != "\t" { return false }
            k = text.index(after: k)
        }
        return true
    }

    private static func classify(
        word: String, text: String, at wordEnd: String.Index, syntax: LanguageSyntax, lineStart: Bool
    ) -> TokenKind {
        let lookup = syntax.caseInsensitive ? word.lowercased() : word

        // 属性启发式（YAML 行首 key:）
        if syntax.propertyAtLineStart && lineStart {
            let rest = text[wordEnd...]
            if rest.hasPrefix(":") || rest.hasPrefix(": ") { return .property }
        }
        // 属性启发式（JSON/CSS key:）
        if syntax.propertyAfterColon {
            var k = wordEnd
            while k < text.endIndex, text[k] == " " || text[k] == "\t" {
                k = text.index(after: k)
            }
            if k < text.endIndex && text[k] == ":" {
                return .property
            }
        }

        if syntax.keywords.contains(lookup) { return .keyword }
        if syntax.types.contains(lookup) { return .type }

        // 函数调用启发式：后跟 "("
        var k = wordEnd
        while k < text.endIndex, text[k] == " " || text[k] == "\t" {
            k = text.index(after: k)
        }
        if k < text.endIndex && text[k] == "(" {
            return .function
        }
        return .plain
    }

    // MARK: HTML/XML 标记语言扫描器

    private static func tokenizeMarkup(_ text: String) -> [TokenRange] {
        var tokens: [TokenRange] = []
        var i = text.startIndex
        let end = text.endIndex
        var inTag = false

        while i < end {
            let c = text[i]

            if text[i...].hasPrefix("<!--") {
                let searchStart = text.index(i, offsetBy: 4, limitedBy: end) ?? end
                let closeEnd = text.range(of: "-->", range: searchStart..<end)?.upperBound ?? end
                tokens.append(TokenRange(range: i..<closeEnd, kind: .comment))
                i = closeEnd
                continue
            }

            if c == "<" {
                inTag = true
                var j = text.index(after: i)
                if j < end && (text[j] == "/" || text[j] == "!" || text[j] == "?") {
                    j = text.index(after: j)
                }
                var nameEnd = j
                while nameEnd < end, text[nameEnd].isLetter || text[nameEnd].isNumber || text[nameEnd] == "-" || text[nameEnd] == "_" || text[nameEnd] == ":" {
                    nameEnd = text.index(after: nameEnd)
                }
                if nameEnd > j {
                    tokens.append(TokenRange(range: j..<nameEnd, kind: .tag))
                }
                i = nameEnd
                continue
            }

            if c == ">" {
                inTag = false
                i = text.index(after: i)
                continue
            }

            if c == "\"" || c == "'" {
                var j = text.index(after: i)
                while j < end, text[j] != c, text[j] != "\n" {
                    j = text.index(after: j)
                }
                if j < end { j = text.index(after: j) }
                tokens.append(TokenRange(range: i..<j, kind: .string))
                i = j
                continue
            }

            if inTag, isIdentStart(c) {
                var j = i
                while j < end, text[j].isLetter || text[j].isNumber || text[j] == "-" || text[j] == "_" || text[j] == ":" {
                    j = text.index(after: j)
                }
                var k = j
                while k < end, text[k] == " " { k = text.index(after: k) }
                tokens.append(TokenRange(range: i..<j, kind: (k < end && text[k] == "=") ? .property : .plain))
                i = j
                continue
            }

            i = text.index(after: i)
        }
        return tokens
    }

    // MARK: 各语言关键字表

    static func syntax(for language: CodeLanguage) -> LanguageSyntax {
        var s = LanguageSyntax()
        switch language {
        case .html, .xml:
            // 标记语言由独立扫描器处理；此处兜底配置注释。
            s.blockComments = [("<!--", "-->")]
            return s
        case .swift:
            s.lineComments = ["//"]
            s.blockComments = [("/*", "*/")]
            s.stringDelimiters = ["\""]
            s.rawMultilineStrings = ["\"\"\""]
            s.keywords = Set("associatedtype class deinit enum extension fileprivate func import init inout internal let open operator private protocol public rethrows static struct subscript typealias var break case continue default defer do else fallthrough for guard if in repeat return switch where while as any catch is nil super self throw throws try await async indirect mutating nonmutating convenience required lazy weak unowned willSet didSet some each sending borrowing consuming macro".split(separator: " ").map(String.init))
            s.types = Set("Int Int8 Int16 Int32 Int64 UInt UInt8 UInt16 UInt32 UInt64 Float Double Bool String Character Any AnyObject Void Never Optional Array Dictionary Set Range ClosedRange PartialRangeThrough Result Error Codable Hashable Equatable Comparable Sendable Sequence Collection String.Encoding DispatchQueue UUID Date Data".split(separator: " ").map(String.init))
        case .javascript, .typescript:
            s.lineComments = ["//"]
            s.blockComments = [("/*", "*/")]
            s.stringDelimiters = ["\"", "'"]
            s.rawMultilineStrings = ["`"]
            var keywords = "break case catch class const continue debugger default delete do else export extends finally for function if import in instanceof new return super switch this throw try typeof var void while with yield let static async await of get set null true false undefined NaN Infinity".split(separator: " ").map(String.init)
            if language == .typescript {
                keywords += "any boolean number string object unknown never enum interface implements private public protected readonly namespace declare abstract type keyof infer is satisfies override".split(separator: " ").map(String.init)
            }
            s.keywords = Set(keywords)
            s.types = Set("Object Array String Number Boolean Promise Map Set Symbol Math JSON Date RegExp Error BigInt".split(separator: " ").map(String.init))
        case .python:
            s.lineComments = ["#"]
            s.stringDelimiters = ["\"", "'"]
            s.rawMultilineStrings = ["\"\"\"", "'''"]
            s.keywords = Set("and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield match case self cls".split(separator: " ").map(String.init))
            s.types = Set("True False None int float str bool list dict set tuple bytes object type range enumerate zip map filter print len super".split(separator: " ").map(String.init))
        case .java:
            s.lineComments = ["//"]
            s.blockComments = [("/*", "*/")]
            s.keywords = Set("abstract boolean break byte case catch char class const continue default do double else enum extends final finally float for goto if implements import instanceof int interface long native new package private protected public return short static strictfp super switch synchronized this throw throws transient try void volatile while var record sealed permits yield true false null".split(separator: " ").map(String.init))
            s.types = Set("String Integer Long Double Float Boolean Character Object List Map Set ArrayList HashMap Optional Stream".split(separator: " ").map(String.init))
        case .c, .cpp:
            s.lineComments = ["//"]
            s.blockComments = [("/*", "*/")]
            s.preprocessorPrefix = "#"
            s.keywords = Set("auto break case char const continue default do double else enum extern float for goto if inline int long register restrict return short signed sizeof static struct switch typedef union unsigned void volatile while class namespace new delete template typename using virtual override final public private protected friend operator this throw try catch bool true false nullptr constexpr noexcept mutable explicit export".split(separator: " ").map(String.init))
            s.types = Set("size_t ssize_t uint8_t uint16_t uint32_t uint64_t int8_t int16_t int32_t int64_t NSString NSObject id".split(separator: " ").map(String.init))
        case .go:
            s.lineComments = ["//"]
            s.blockComments = [("/*", "*/")]
            s.rawMultilineStrings = ["`"]
            s.keywords = Set("break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var nil true false iota".split(separator: " ").map(String.init))
            s.types = Set("string int int8 int16 int32 int64 uint uint8 uint16 uint32 uint64 uintptr float32 float64 complex64 complex128 bool byte rune error any".split(separator: " ").map(String.init))
        case .rust:
            s.lineComments = ["//"]
            s.blockComments = [("/*", "*/")]
            s.rawMultilineStrings = []
            s.keywords = Set("as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait true type unsafe use where while".split(separator: " ").map(String.init))
            s.types = Set("String Vec Option Result Box Rc Arc HashMap BTreeMap i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f32 f64 bool char str".split(separator: " ").map(String.init))
        case .css:
            s.lineComments = []
            s.blockComments = [("/*", "*/")]
            s.stringDelimiters = ["\"", "'"]
            s.propertyAfterColon = true
            s.keywords = Set("@media @import @keyframes @font-face @supports @charset @layer !important".split(separator: " ").map(String.init))
        case .json:
            s.keywords = Set("true false null".split(separator: " ").map(String.init))
            s.propertyAfterColon = true
        case .yaml:
            s.lineComments = ["#"]
            s.stringDelimiters = ["\"", "'"]
            s.rawMultilineStrings = []
            s.propertyAtLineStart = true
            s.keywords = Set("true false null yes no on off".split(separator: " ").map(String.init))
        case .sql:
            s.lineComments = ["--"]
            s.blockComments = [("/*", "*/")]
            s.stringDelimiters = ["'"]
            s.caseInsensitive = true
            s.keywords = Set("select from where insert update delete into values set create table drop alter add primary key foreign references join inner left right outer full on group by order having limit offset union all distinct as and or not null is in between like exists case when then else end asc desc count sum avg min max integer varchar text boolean timestamp date int bigint decimal numeric begin commit rollback".split(separator: " ").map(String.init))
        case .shell:
            s.lineComments = ["#"]
            s.stringDelimiters = ["\""]
            s.rawMultilineStrings = ["'"]
            s.keywords = Set("if then else elif fi for while until do done case esac function in return exit local export readonly echo cd source alias unset shift trap eval exec declare printf".split(separator: " ").map(String.init))
        case .markdown, .plain:
            return s
        }
        return s
    }
}
