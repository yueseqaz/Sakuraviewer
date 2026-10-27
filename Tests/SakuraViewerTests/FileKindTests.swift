import Foundation
import SakuraViewerCore

enum FileKindTests {

    static func runAll() {
        runCase(name, "extensionDetection") { try extensionDetection() }
        runCase(name, "specialFileNames") { try specialFileNames() }
        runCase(name, "unknownTextExtensionSniffsAsText") { try unknownTextExtensionSniffsAsText() }
        runCase(name, "unknownBinaryExtensionSniffsAsUnsupported") { try unknownBinaryExtensionSniffsAsUnsupported() }
        runCase(name, "looksLikeBinaryHeuristic") { looksLikeBinaryHeuristic() }
    }

    static let name = "FileKindTests"

    private static func tempFile(named fileName: String, content: Data) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName)
        try content.write(to: url)
        return url
    }

    static func extensionDetection() throws {
        let cases: [(String, FileKind)] = [
            ("photo.jpg", .image), ("photo.JPEG", .image), ("anim.gif", .image),
            ("vector.svg", .image), ("shot.heic", .image), ("pic.webp", .image),
            ("movie.mp4", .video), ("clip.mov", .video), ("video.m4v", .video),
            ("song.mp3", .audio), ("track.m4a", .audio), ("lossless.flac", .audio),
            ("sound.wav", .audio),
            ("doc.pdf", .pdf),
            ("readme.md", .markdown), ("notes.markdown", .markdown),
            ("main.swift", .code), ("app.js", .code), ("script.ts", .code),
            ("app.py", .code), ("main.go", .code), ("lib.rs", .code),
            ("index.html", .code), ("style.css", .code), ("data.json", .code),
            ("config.yaml", .code), ("query.sql", .code), ("build.sh", .code),
            ("notes.txt", .plainText), ("app.log", .plainText), ("table.csv", .plainText),
        ]
        for (fileName, expected) in cases {
            let url = try tempFile(named: fileName, content: Data("x".utf8))
            check(FileKind.detect(url: url) == expected, "扩展名识别失败：\(fileName)（得到 \(FileKind.detect(url: url))，期望 \(expected)）")
        }
    }

    static func specialFileNames() throws {
        let makefile = try tempFile(named: "Makefile", content: Data("all:\n".utf8))
        check(FileKind.detect(url: makefile) == .code, "Makefile 应识别为代码")
        let license = try tempFile(named: "LICENSE", content: Data("MIT".utf8))
        check(FileKind.detect(url: license) == .code, "LICENSE 应识别为代码")
    }

    static func unknownTextExtensionSniffsAsText() throws {
        let url = try tempFile(named: "mystery.config", content: Data("hello world\nplain text\n".utf8))
        check(FileKind.detect(url: url) == .plainText, "未知扩展名的文本内容应嗅探为文本")
    }

    static func unknownBinaryExtensionSniffsAsUnsupported() throws {
        var bytes = Data([0x89, 0x50, 0x4E, 0x47]) // PNG magic 但扩展名未知
        bytes.append(Data(repeating: 0x00, count: 64))
        let url = try tempFile(named: "mystery.xyz", content: bytes)
        check(FileKind.detect(url: url) == .unsupported, "未知扩展名的二进制内容应识别为不支持")
    }

    static func looksLikeBinaryHeuristic() {
        check(!FileKind.looksLikeBinary(Data("just text 123\n".utf8)), "纯文本不应判为二进制")
        check(FileKind.looksLikeBinary(Data([0x00, 0x01, 0x02, 0x03])), "含 NUL 应判为二进制")
    }
}
