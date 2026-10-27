import Foundation
import SakuraViewerCore
import SwiftUI
import AppKit

/// 侧边栏「文件夹」条目。
struct FolderEntry: Identifiable, Codable, Equatable {
    let id: URL
    var name: String

    init(url: URL) {
        self.id = url
        self.name = url.lastPathComponent
    }
}

/// 文件夹媒体库：记录添加的文件夹并扫描其中支持的文件，按类型分组展示。
@MainActor
final class FolderLibraryStore: ObservableObject {

    @Published private(set) var folders: [FolderEntry] = []
    /// folderURL -> 扫描到的文件
    @Published private(set) var filesByFolder: [URL: [URL]] = [:]

    private let defaults: UserDefaults
    private static let key = "sakura.folders"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    @discardableResult
    func addFolder(_ url: URL) -> Bool {
        guard url.hasDirectoryPath else { return false }
        let entry = FolderEntry(url: url)
        guard !folders.contains(entry) else { return false }
        folders.append(entry)
        rescan(folder: url)
        save()
        return true
    }

    func removeFolder(_ url: URL) {
        folders.removeAll { $0.id == url }
        filesByFolder.removeValue(forKey: url)
        save()
    }

    func rescan(folder url: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let files = Self.scanSupportedFiles(in: url)
            DispatchQueue.main.async {
                self?.filesByFolder[url] = files
            }
        }
    }

    func rescanAll() {
        for folder in folders {
            rescan(folder: folder.id)
        }
    }

    /// 递归扫描支持的文件（上限保护）。
    nonisolated static func scanSupportedFiles(in directory: URL, limit: Int = 4000) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [URL] = []
        for case let url as URL in enumerator {
            if results.count >= limit { break }
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            if FileKind.detect(url: url) != .unsupported {
                results.append(url)
            }
        }
        return results.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func load() {
        let raw = defaults.stringArray(forKey: Self.key) ?? []
        folders = raw.compactMap { string in
            guard let url = URL(string: string) else { return nil }
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return FolderEntry(url: url)
        }
        rescanAll()
    }

    private func save() {
        defaults.set(folders.map { $0.id.absoluteString }, forKey: Self.key)
    }
}
