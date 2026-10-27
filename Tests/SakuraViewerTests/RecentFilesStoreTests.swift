import Foundation
import SakuraViewerCore

enum RecentFilesStoreTests {

    static let name = "RecentFilesStoreTests"

    static func runAll() {
        runCase(name, "addAndDedupe") { addAndDedupe() }
        runCase(name, "limitTrims") { limitTrims() }
        runCase(name, "limitChangeReconciles") { limitChangeReconciles() }
        runCase(name, "persistence") { persistence() }
        runCase(name, "removeAndClear") { removeAndClear() }
        runCase(name, "purgeMissing") { purgeMissing() }
    }

    private static func makeStore(limit: Int = 10) -> (RecentFilesStore, UserDefaults) {
        let suite = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (RecentFilesStore(defaults: defaults, key: "recents", limit: limit), defaults)
    }

    static func addAndDedupe() {
        let (store, _) = makeStore()
        let a = URL(fileURLWithPath: "/tmp/a.md")
        let b = URL(fileURLWithPath: "/tmp/b.md")
        store.add(a)
        store.add(b)
        store.add(a)
        checkEqual(store.urls.count, 2, "重复添加应去重")
        checkEqual(store.urls.first, a.standardizedFileURL, "最近访问的应置顶")
    }

    static func limitTrims() {
        let (store, _) = makeStore(limit: 3)
        for i in 0..<6 {
            store.add(URL(fileURLWithPath: "/tmp/file\(i).txt"))
        }
        checkEqual(store.urls.count, 3)
        checkEqual(store.urls.first?.lastPathComponent, "file5.txt")
    }

    static func limitChangeReconciles() {
        let (store, _) = makeStore(limit: 10)
        for i in 0..<8 {
            store.add(URL(fileURLWithPath: "/tmp/f\(i).txt"))
        }
        store.limit = 4
        store.reconcile()
        checkEqual(store.urls.count, 4)
    }

    static func persistence() {
        let (store, defaults) = makeStore()
        store.add(URL(fileURLWithPath: "/tmp/persisted.md"))
        // 用相同 defaults 重建应恢复
        let reloaded = RecentFilesStore(defaults: defaults, key: "recents", limit: 10)
        checkEqual(reloaded.urls.map(\.path), store.urls.map(\.path))
    }

    static func removeAndClear() {
        let (store, _) = makeStore()
        let a = URL(fileURLWithPath: "/tmp/a.md")
        store.add(a)
        store.remove(a)
        check(store.urls.isEmpty)
        store.add(a)
        store.clear()
        check(store.urls.isEmpty)
    }

    static func purgeMissing() {
        let (store, _) = makeStore()
        let existing = FileManager.default.temporaryDirectory.appendingPathComponent("exists-\(UUID()).md")
        try? Data("x".utf8).write(to: existing)
        store.add(existing)
        store.add(URL(fileURLWithPath: "/definitely/not/there.md"))
        store.purgeMissing()
        checkEqual(store.urls.count, 1, "失效文件应被清理")
    }
}

enum FavoritesStoreTests {

    static let name = "FavoritesStoreTests"

    static func runAll() {
        runCase(name, "toggle") { toggle() }
    }

    static func toggle() {
        let suite = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = FavoritesStore(defaults: defaults, key: "favorites")

        let url = URL(fileURLWithPath: "/tmp/fav.md")
        check(!store.isFavorite(url))
        check(store.toggle(url), "首次 toggle 应返回 true")
        check(store.isFavorite(url))
        check(!store.toggle(url), "再次 toggle 应返回 false")
        check(!store.isFavorite(url))
    }
}
