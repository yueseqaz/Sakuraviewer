import Foundation
import SakuraViewerCore

enum SyntaxHighlighterTests {

    static let name = "SyntaxHighlighterTests"

    static func runAll() {
        runCase(name, "swiftTokens") { swiftTokens() }
        runCase(name, "keywordClassification") { keywordClassification() }
        runCase(name, "types") { types() }
        runCase(name, "stringWithEscape") { stringWithEscape() }
        runCase(name, "jsonProperties") { jsonProperties() }
        runCase(name, "pythonComments") { pythonComments() }
        runCase(name, "fenceLanguageAliases") { fenceLanguageAliases() }
        runCase(name, "extensionMapping") { extensionMapping() }
        runCase(name, "attributedProducesColors") { attributedProducesColors() }
    }

    static func swiftTokens() {
        let code = "let greeting = \"你好\" // 注释\nprint(greeting)"
        let tokens = SyntaxHighlighter.tokenize(code, language: .swift)
        let has = { (kind: TokenKind) in
            tokens.contains { token in
                token.kind == kind && !String(code[token.range]).trimmingCharacters(in: .whitespaces).isEmpty
            }
        }
        check(has(.keyword), "应识别关键字")
        check(has(.string), "应识别字符串")
        check(has(.comment), "应识别注释")
    }

    static func keywordClassification() {
        let code = "func hello() { let x = 1 }"
        let tokens = SyntaxHighlighter.tokenize(code, language: .swift)
        let keywords = tokens.filter { $0.kind == .keyword }.map { String(code[$0.range]) }
        check(keywords.contains("func"), "func 应为关键字")
        check(keywords.contains("let"), "let 应为关键字")
        // 函数调用识别
        let functions = tokens.filter { $0.kind == .function }.map { String(code[$0.range]) }
        check(functions.contains("hello"), "hello() 应识别为函数")
    }

    static func types() {
        let code = "let value: Int = 42"
        let tokens = SyntaxHighlighter.tokenize(code, language: .swift)
        let types = tokens.filter { $0.kind == .type }.map { String(code[$0.range]) }
        check(types.contains("Int"), "Int 应识别为类型")
        let numbers = tokens.filter { $0.kind == .number }.map { String(code[$0.range]) }
        check(numbers.contains("42"), "42 应识别为数字")
    }

    static func stringWithEscape() {
        let code = "let s = \"a\\\"b\""
        let tokens = SyntaxHighlighter.tokenize(code, language: .swift)
        let strings = tokens.filter { $0.kind == .string }.map { String(code[$0.range]) }
        check(strings.contains { $0.contains("a\\\"b") }, "转义引号不应终止字符串：\(strings)")
    }

    static func jsonProperties() {
        let code = "{\n  \"name\": \"sakura\",\n  \"count\": 3\n}"
        let tokens = SyntaxHighlighter.tokenize(code, language: .json)
        let properties = tokens.filter { $0.kind == .property }.map { String(code[$0.range]) }
        check(properties.contains("\"name\""), "JSON 键应识别为属性：\(properties)")
    }

    static func pythonComments() {
        let code = "# 注释\nx = 1  # 行内注释"
        let tokens = SyntaxHighlighter.tokenize(code, language: .python)
        let comments = tokens.filter { $0.kind == .comment }.map { String(code[$0.range]) }
        checkEqual(comments.count, 2, "应识别两条 Python 注释")
    }

    static func fenceLanguageAliases() {
        check(CodeLanguage(fence: "js") == .javascript)
        check(CodeLanguage(fence: "python") == .python)
        check(CodeLanguage(fence: "sh") == .shell)
        check(CodeLanguage(fence: nil) == .plain)
        check(CodeLanguage(fence: "unknownlang") == .plain)
    }

    static func extensionMapping() {
        check(CodeLanguage(fileExtension: "swift") == .swift)
        check(CodeLanguage(fileExtension: "TS") == .typescript)
        check(CodeLanguage(fileExtension: "unknown") == .plain)
    }

    static func attributedProducesColors() {
        let code = "let x = 1"
        let attributed = SyntaxHighlighter.attributed(
            code, language: .swift,
            font: .monospacedSystemFont(ofSize: 12, weight: .regular)
        )
        checkEqual(attributed.string, code)
        check(attributed.length > 0)
    }
}
