import Foundation
import SakuraViewerCore

enum SessionStoreTests {

    static let name = "SessionStoreTests"

    static func runAll() {
        runCase(name, "roundtrip") { roundtrip() }
        runCase(name, "loadMissingReturnsNil") { loadMissingReturnsNil() }
        runCase(name, "corruptDataReturnsNil") { corruptDataReturnsNil() }
    }

    static func roundtrip() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SessionStore(directory: dir)
        let snapshot = SessionSnapshot(paths: ["/tmp/a.md", "/tmp/b.swift"], selected: 1)
        store.save(snapshot)

        let loaded = SessionStore(directory: dir).load()
        checkEqual(loaded, snapshot)
    }

    static func loadMissingReturnsNil() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        check(SessionStore(directory: dir).load() == nil)
    }

    static func corruptDataReturnsNil() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? Data("not json".utf8).write(to: dir.appendingPathComponent("session.json"))
        check(SessionStore(directory: dir).load() == nil, "损坏数据应返回 nil 而非崩溃")
    }
}

enum MediaPlaylistBuilderTests {

    static let name = "MediaPlaylistBuilderTests"

    static func runAll() {
        runCase(name, "playlistContainsOnlySameKind") { try playlistContainsOnlySameKind() }
        runCase(name, "videoPlaylist") { try videoPlaylist() }
        runCase(name, "singleFilePlaylist") { try singleFilePlaylist() }
    }

    private static func makeMediaDir() throws -> (URL, [URL]) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var urls: [URL] = []
        for fileName in ["03-third.mp3", "01-first.mp3", "02-second.mp3", "ignore.txt", "photo.png"] {
            let url = dir.appendingPathComponent(fileName)
            try Data("x".utf8).write(to: url)
            urls.append(url)
        }
        return (dir, urls)
    }

    static func playlistContainsOnlySameKind() throws {
        let (_, urls) = try makeMediaDir()
        guard let anchor = urls.first(where: { $0.lastPathComponent == "02-second.mp3" }) else {
            fail("锚点文件缺失")
            return
        }
        let (tracks, index) = MediaPlaylistBuilder.playlist(for: anchor)
        checkEqual(tracks.map(\.title), ["01-first", "02-second", "03-third"], "播放列表只含音频且按名称排序")
        checkEqual(index, 1)
    }

    static func videoPlaylist() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let a = dir.appendingPathComponent("b.mov")
        let b = dir.appendingPathComponent("a.mp4")
        try Data("x".utf8).write(to: a)
        try Data("x".utf8).write(to: b)
        let (tracks, index) = MediaPlaylistBuilder.playlist(for: a)
        checkEqual(tracks.count, 2)
        checkEqual(index, 1)
    }

    static func singleFilePlaylist() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let only = dir.appendingPathComponent("lonely.mp3")
        try Data("x".utf8).write(to: only)
        let (tracks, index) = MediaPlaylistBuilder.playlist(for: only)
        checkEqual(tracks.count, 1)
        checkEqual(index, 0)
    }
}

enum FormatterTests {

    static let name = "FormatterTests"

    static func runAll() {
        runCase(name, "duration") { duration() }
        runCase(name, "zoomPercent") { zoomPercent() }
        runCase(name, "fileSize") { fileSize() }
    }

    static func duration() {
        checkEqual(SakuraFormatter.duration(0), "0:00")
        checkEqual(SakuraFormatter.duration(59), "0:59")
        checkEqual(SakuraFormatter.duration(61), "1:01")
        checkEqual(SakuraFormatter.duration(3661), "1:01:01")
    }

    static func zoomPercent() {
        checkEqual(SakuraFormatter.zoomPercent(1.25), "125%")
        checkEqual(SakuraFormatter.zoomPercent(1), "100%")
    }

    static func fileSize() {
        check(!SakuraFormatter.fileSize(1024).isEmpty)
        check(!SakuraFormatter.fileSize(5_000_000).isEmpty)
    }
}
