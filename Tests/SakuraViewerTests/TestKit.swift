import Foundation

/// 零依赖测试执行器。
/// 背景：纯 Command Line Tools 环境不提供 XCTest 框架与 swift-testing 宏插件，
/// 因此测试以纯 Swift 编写，本地与 CI 使用同一执行路径。
enum TestHarness {

    struct Failure {
        let path: String
        let message: String
        let location: String
    }

    static var failures: [Failure] = []
    static var passedCount = 0
    static var currentPath = ""

    static func check(_ condition: Bool, _ message: String, file: StaticString, line: UInt) {
        if condition {
            passedCount += 1
        } else {
            let fileName = String(describing: file).split(separator: "/").last.map(String.init)
                ?? String(describing: file)
            failures.append(Failure(
                path: currentPath,
                message: message.isEmpty ? "断言失败" : message,
                location: "\(fileName):\(line)"
            ))
        }
    }
}

/// 断言：条件为真。
func check(_ condition: Bool, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    TestHarness.check(condition, message, file: file, line: line)
}

/// 断言：两个值相等。
func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    TestHarness.check(actual == expected, message.isEmpty ? "期望 \(expected)，实际 \(actual)" : message, file: file, line: line)
}

/// 标记失败。
func fail(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
    TestHarness.check(false, message, file: file, line: line)
}

/// 运行单个测试用例。
func runCase(_ suite: String, _ name: String, body: () throws -> Void) {
    TestHarness.currentPath = "\(suite).\(name)"
    do {
        try body()
        print("  ✓ \(suite).\(name)")
    } catch {
        TestHarness.check(false, "抛出异常：\(error)", file: #filePath, line: #line)
    }
}

/// 执行所有测试套件并返回退出码。
@discardableResult
func runAllTests(suites: [(name: String, run: () -> Void)]) -> Int32 {
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🌸 Sakura-Viewer 单元测试（自研零依赖执行器）")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    for suite in suites {
        print("▶ \(suite.name)")
        suite.run()
    }
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    if TestHarness.failures.isEmpty {
        print("✅ 全部通过：\(TestHarness.passedCount) 项断言")
        return 0
    }
    print("❌ 失败 \(TestHarness.failures.count) 项（通过 \(TestHarness.passedCount) 项断言）：")
    for failure in TestHarness.failures {
        print("   [\(failure.path)] \(failure.message) —— \(failure.location)")
    }
    return 1
}
