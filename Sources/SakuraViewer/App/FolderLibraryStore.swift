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

/// A visible node in the sidebar file tree. Empty directories are omitted;
/// regular files remain visible even when their preview type is unsupported.
struct FolderTreeNode: Identifiable, Equatable {
    let url: URL
    let isDirectory: Bool
    var children: [FolderTreeNode] = []

    var id: URL { url }
}

/// 文件夹媒体库：记录添加的文件夹并按目录层级展示文件树。
@MainActor
final class FolderLibraryStore: ObservableObject {

    @Published private(set) var folders: [FolderEntry] = []
    /// folderURL -> 文件树的顶层节点
    @Published private(set) var treeByFolder: [URL: [FolderTreeNode]] = [:]

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
        treeByFolder.removeValue(forKey: url)
        save()
    }

    func rescan(folder url: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let tree = Self.scanTree(in: url)
            DispatchQueue.main.async {
                self?.treeByFolder[url] = tree
            }
        }
    }

    func rescanAll() {
        for folder in folders {
            rescan(folder: folder.id)
        }
    }

    /// 扫描文件并保留目录层级（上限保护）。
    nonisolated static func scanTree(in directory: URL, limit: Int = 4000) -> [FolderTreeNode] {
        var fileCount = 0

        func visit(_ directory: URL) -> [FolderTreeNode] {
            guard fileCount < limit,
                  let urls = try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                  ) else { return [] }

            var nodes: [FolderTreeNode] = []
            for url in urls.sorted(by: Self.fileTreeSort) {
                guard fileCount < limit,
                      let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey]) else {
                    continue
                }
                if values.isDirectory == true {
                    let children = visit(url)
                    if !children.isEmpty {
                        nodes.append(FolderTreeNode(url: url, isDirectory: true, children: children))
                    }
                } else if values.isRegularFile == true {
                    fileCount += 1
                    nodes.append(FolderTreeNode(url: url, isDirectory: false))
                }
            }
            return nodes
        }

        return visit(directory)
    }

    /// Compatibility helper for callers that only need the flattened file list.
    nonisolated static func scanSupportedFiles(in directory: URL, limit: Int = 4000) -> [URL] {
        func flatten(_ nodes: [FolderTreeNode]) -> [URL] {
            nodes.flatMap { node -> [URL] in
                if node.isDirectory { return flatten(node.children) }
                return FileKind.detect(url: node.url) == .unsupported ? [] : [node.url]
            }
        }
        return flatten(scanTree(in: directory, limit: limit)).sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    private nonisolated static func fileTreeSort(_ lhs: URL, _ rhs: URL) -> Bool {
        let lhsDirectory = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let rhsDirectory = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if lhsDirectory != rhsDirectory { return lhsDirectory }
        return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
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
