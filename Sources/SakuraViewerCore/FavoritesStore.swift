import Foundation
import Combine

/// 收藏文件存储。
public final class FavoritesStore: ObservableObject {

    @Published public private(set) var urls: [URL] = []

    private let defaultsKey: String
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard, key: String = "sakura.favorite.files") {
        self.defaults = defaults
        self.defaultsKey = key
        load()
    }

    public func isFavorite(_ url: URL) -> Bool {
        urls.contains(url.standardizedFileURL)
    }

    public func toggle(_ url: URL) -> Bool {
        let standardized = url.standardizedFileURL
        if let index = urls.firstIndex(of: standardized) {
            urls.remove(at: index)
            save()
            return false
        }
        urls.insert(standardized, at: 0)
        save()
        return true
    }

    public func remove(_ url: URL) {
        urls.removeAll { $0 == url }
        save()
    }

    private func load() {
        let paths = defaults.stringArray(forKey: defaultsKey) ?? []
        urls = paths.compactMap { URL(string: $0) }
    }

    private func save() {
        defaults.set(urls.map(\.absoluteString), forKey: defaultsKey)
    }
}
