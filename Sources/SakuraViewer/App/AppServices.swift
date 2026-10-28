import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SakuraViewerCore

/// 应用服务组合根：持有各存储与工作区，注入 SwiftUI 环境。
@MainActor
final class AppServices: ObservableObject {

    static let shared = AppServices()

    let workspace = WorkspaceModel()
    let router = ViewerRouter()
    let recents: RecentFilesStore
    let favorites = FavoritesStore()
    let folders = FolderLibraryStore()
    let session = SessionStore()
    let settings: AppSettings

    private init() {
        let settings = AppSettings()
        self.settings = settings
        self.recents = RecentFilesStore(limit: settings.maxRecentFiles)

        settings.onRecentLimitChange = { [weak self] limit in
            self?.recents.limit = limit
        }
        // 懒清理失效的最近文件
        recents.purgeMissing()
    }

    // MARK: 打开

    func open(urls: [URL]) {
        var files: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                _ = folders.addFolder(url)
                continue
            }
            // Office documents are handed to the user's default compatible app;
            // the viewer still tracks them as recently opened files.
            if FileKind.isOfficeDocument(url) {
                NSWorkspace.shared.open(url)
                recents.add(url)
                continue
            }
            files.append(url)
        }
        guard !files.isEmpty else { return }
        workspace.open(urls: files)
        for file in files {
            recents.add(file)
        }
    }

    // MARK: 会话

    func saveSession() {
        guard settings.restoreSession else { return }
        let paths = workspace.paths
        let selected = workspace.selectedTab.flatMap { tab in
            workspace.tabs.firstIndex { $0.id == tab.id }
        } ?? -1
        session.save(SessionSnapshot(paths: paths, selected: selected))
    }

    func restoreSessionIfEnabled() {
        guard settings.restoreSession, workspace.tabs.isEmpty else { return }
        guard let snapshot = session.load(), !snapshot.paths.isEmpty else { return }
        let urls = snapshot.paths
            .compactMap { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !urls.isEmpty else { return }
        workspace.open(urls: urls)
        if snapshot.selected >= 0, snapshot.selected < workspace.tabs.count {
            workspace.selectedTabId = workspace.tabs[snapshot.selected].id
        }
    }
}

// MARK: - 文件选择面板

@MainActor
enum FilePicker {

    /// 选择一个或多个文件（支持全部可查看类型）。
    static func pickFiles() -> [URL]? {
        let panel = NSOpenPanel()
        panel.title = "打开文件"
        panel.message = "选择要查看的文件，可多选"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = FileKind.allSupportedUTTypes
        guard panel.runModal() == .OK else { return nil }
        return panel.urls.isEmpty ? nil : panel.urls
    }

    /// 选择文件夹。
    static func pickFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "打开文件夹"
        panel.message = "选择一个文件夹加入侧边栏媒体库"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url
    }
}
