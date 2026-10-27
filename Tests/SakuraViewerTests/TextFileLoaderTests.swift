import Foundation
import SakuraViewerCore

enum TextFileLoaderTests {

    static let name = "TextFileLoaderTests"

    static func runAll() {
        runCase(name, "loadUTF8") { try loadUTF8() }
        runCase(name, "loadMissingFile") { loadMissingFile() }
        runCase(name, "loadTooLarge") { try loadTooLarge() }
        runCase(name, "emptyFile") { try emptyFile() }
        runCase(name, "directoryRejected") { try directoryRejected() }
    }

    private static func tempFile(named fileName: String, content: Data) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName)
        try content.write(to: url)
        return url
    }

    static func loadUTF8() throws {
        let url = try tempFile(named: "a.txt", content: Data("hello 你好".utf8))
        let result = TextFileLoader.load(url: url)
        guard case .success(let payload) = result else {
            fail("应加载成功")
            return
        }
        checkEqual(payload.text, "hello 你好")
        checkEqual(payload.encoding.displayName, "UTF-8")
        check(!payload.truncated)
    }

    static func loadMissingFile() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID()).txt")
        guard case .failure(.fileNotFound) = TextFileLoader.load(url: url) else {
            fail("应为 fileNotFound")
            return
        }
        check(true)
    }

    static func loadTooLarge() throws {
        let url = try tempFile(named: "big.txt", content: Data("xxx".utf8))
        guard case .failure(.tooLarge) = TextFileLoader.load(url: url, maxBytes: 2) else {
            fail("应为 tooLarge")
            return
        }
        check(true)
    }

    static func emptyFile() throws {
        let url = try tempFile(named: "empty.txt", content: Data())
        guard case .success(let payload) = TextFileLoader.load(url: url) else {
            fail("空文件应加载成功")
            return
        }
        check(payload.text.isEmpty)
    }

    static func directoryRejected() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard case .failure = TextFileLoader.load(url: dir) else {
            fail("目录应加载失败而非崩溃")
            return
        }
        check(true)
    }
}
