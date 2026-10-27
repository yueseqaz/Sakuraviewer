import Foundation
import SakuraViewerCore
import SwiftUI

/// 标签加载状态。
enum TabStatus: Equatable {
    case loading
    case ready
    case failed(String)
}

/// 一个打开的文件标签。子查看器持有本对象以更新状态栏。
@MainActor
final class TabDocument: ObservableObject, Identifiable {

    let id = UUID()
    let kind: FileKind
    /// 打开时的原始文件。
    let originURL: URL
    /// 当前展示的文件（图片切换 / 媒体播放列表会变化）。
    @Published var currentURL: URL
    @Published var status: TabStatus = .loading
    /// 状态栏附加信息（编码、页码、时长、缩放等）。
    @Published var statusDetail: String = ""
    /// 刷新令牌：自增触发查看器重新加载。
    @Published var reloadToken: Int = 0

    init(url: URL, kindOverride: FileKind? = nil) {
        self.originURL = url
        self.currentURL = url
        self.kind = kindOverride ?? FileKind.detect(url: url)
    }

    var title: String {
        currentURL.deletingPathExtension().lastPathComponent
    }

    var fileExtension: String {
        currentURL.pathExtension
    }

    func refresh() {
        status = .loading
        reloadToken += 1
    }
}

/// 工作区：标签集合与选中管理。
@MainActor
final class WorkspaceModel: ObservableObject {

    @Published var tabs: [TabDocument] = []
    @Published var selectedTabId: UUID?

    var selectedTab: TabDocument? {
        tabs.first { $0.id == selectedTabId }
    }

    /// 用于驱动「恢复会话」「按类型分组」等观察。
    var paths: [String] {
        tabs.map { $0.originURL.path }
    }

    // MARK: 操作

    @discardableResult
    func open(url: URL, kindOverride: FileKind? = nil) -> TabDocument? {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }
        if isDirectory.boolValue {
            return nil // 文件夹由 FolderLibraryStore 处理
        }
        // 已打开则聚焦
        if let existing = tabs.first(where: { $0.originURL.standardizedFileURL == url.standardizedFileURL }) {
            selectedTabId = existing.id
            return existing
        }
        let tab = TabDocument(url: url, kindOverride: kindOverride)
        tabs.append(tab)
        selectedTabId = tab.id
        return tab
    }

    func open(urls: [URL]) {
        for url in urls {
            _ = open(url: url)
        }
        if let last = urls.last, let tab = tabs.first(where: { $0.originURL == last }) {
            selectedTabId = tab.id
        }
    }

    func close(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasSelected = selectedTabId == id
        tabs.remove(at: index)
        if wasSelected {
            if tabs.isEmpty {
                selectedTabId = nil
            } else {
                selectedTabId = tabs[min(index, tabs.count - 1)].id
            }
        }
    }

    func closeCurrent() {
        guard let id = selectedTabId else { return }
        close(id: id)
    }

    func closeOthers(except id: UUID) {
        tabs.removeAll { $0.id != id }
        selectedTabId = id
    }

    func selectNext() {
        guard !tabs.isEmpty, let current = selectedTabId,
              let index = tabs.firstIndex(where: { $0.id == current }) else { return }
        selectedTabId = tabs[(index + 1) % tabs.count].id
    }

    func selectPrevious() {
        guard !tabs.isEmpty, let current = selectedTabId,
              let index = tabs.firstIndex(where: { $0.id == current }) else { return }
        selectedTabId = tabs[(index - 1 + tabs.count) % tabs.count].id
    }
}
