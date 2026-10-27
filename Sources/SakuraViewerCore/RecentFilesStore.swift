import Foundation
import Combine

/// 最近文件存储：去重、置顶、按设置上限裁剪，持久化到 UserDefaults。
public final class RecentFilesStore: ObservableObject {

    @Published public private(set) var urls: [URL] = []

    private let defaultsKey: String
    private let defaults: UserDefaults
    /// 上限由设置控制；发生变化时调用 reconcile。
    public var limit: Int {
        didSet { reconcile() }
    }

    public init(defaults: UserDefaults = .standard, key: String = "sakura.recent.files", limit: Int = 10) {
        self.defaults = defaults
        self.defaultsKey = key
        self.limit = max(limit, 1)
        load()
    }

    public func add(_ url: URL) {
        guard url.isFileURL else { return }
        let standardized = url.standardizedFileURL
        var updated = urls.filter { $0 != standardized }
        updated.insert(standardized, at: 0)
        urls = Array(updated.prefix(limit))
        save()
    }

    public func remove(_ url: URL) {
        urls.removeAll { $0 == url }
        save()
    }

    public func clear() {
        urls = []
        save()
    }

    /// 更新上限后裁剪现有列表。
    public func reconcile() {
        let clipped = Array(urls.prefix(limit))
        if clipped != urls {
            urls = clipped
            save()
        }
    }

    /// 过滤已不存在的文件（懒清理）。
    public func purgeMissing() {
        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        if existing != urls {
            urls = existing
            save()
        }
    }

    private func load() {
        let paths = defaults.stringArray(forKey: defaultsKey) ?? []
        urls = paths.compactMap { URL(string: $0) }
    }

    private func save() {
        defaults.set(urls.map(\.absoluteString), forKey: defaultsKey)
    }
}
