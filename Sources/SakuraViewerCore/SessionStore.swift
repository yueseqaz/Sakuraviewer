import Foundation

/// 会话快照：窗口标签页与选中状态，用于「恢复上次会话」。
public struct SessionSnapshot: Codable, Equatable {
    public var paths: [String]
    public var selected: Int

    public init(paths: [String], selected: Int) {
        self.paths = paths
        self.selected = selected
    }
}

/// 会话持久化：JSON 存于应用支持目录，任何异常静默降级。
public final class SessionStore {

    private let fileURL: URL

    public init(directory: URL? = nil) {
        let base: URL
        if let directory {
            base = directory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            base = appSupport.appendingPathComponent("SakuraViewer", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("session.json")
    }

    public func save(_ snapshot: SessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    public func load() -> SessionSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(SessionSnapshot.self, from: data)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
