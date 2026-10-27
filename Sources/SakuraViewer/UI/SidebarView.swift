import SwiftUI
import SakuraViewerCore

/// 左侧边栏：打开入口、最近文件、收藏、文件夹媒体库（按类型分组）、当前打开。
struct SidebarView: View {

    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    sidebarButton("doc", "打开文件") {
                        if let urls = FilePicker.pickFiles() { services.open(urls: urls) }
                    }
                    sidebarButton("folder", "打开文件夹") {
                        if let url = FilePicker.pickFolder() { services.open(urls: [url]) }
                    }
                    sidebarButton("clock.arrow.circlepath", "清理失效的最近文件") {
                        services.recents.purgeMissing()
                    }
                }
                .padding(.vertical, 2)
            }

            recentsSection

            favoritesSection

            folderSection

            openTabsSection
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .navigationTitle("")
    }

    // MARK: 通用小组件

    private func sidebarButton(_ system: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: system)
                    .font(.system(size: 11))
                Text(help)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: SakuraTheme.smallCornerRadius)
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private func fileRow(_ url: URL, isSelected: Bool, onRemove: (() -> Void)? = nil) -> some View {
        let kind = FileKind.detect(url: url)
        return HStack(spacing: 8) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 12))
                .foregroundColor(SakuraTheme.kindColor(kind))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sidebarRowStyle(selected: isSelected)
        .contentShape(Rectangle())
        .onTapGesture {
            services.open(urls: [url])
        }
        .contextMenu {
            if let onRemove {
                Button("从列表中移除", action: onRemove)
                Divider()
            }
            Button("在 Finder 中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            Button(services.favorites.isFavorite(url) ? "取消收藏" : "添加到收藏") {
                services.favorites.toggle(url)
            }
        }
        .help(url.path)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.displayName)文件 \(url.lastPathComponent)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: 最近文件

    private var recentsSection: some View {
        Section("最近文件") {
            if services.recents.urls.isEmpty {
                Text("暂无记录")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            ForEach(services.recents.urls, id: \.absoluteString) { url in
                fileRow(url, isSelected: workspace.selectedTab?.originURL == url) {
                    services.recents.remove(url)
                }
            }
        }
    }

    // MARK: 收藏

    private var favoritesSection: some View {
        Section("收藏") {
            if services.favorites.urls.isEmpty {
                Text("右键文件可添加收藏")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            ForEach(services.favorites.urls, id: \.absoluteString) { url in
                fileRow(url, isSelected: workspace.selectedTab?.originURL == url) {
                    services.favorites.remove(url)
                }
            }
        }
    }

    // MARK: 文件夹媒体库

    private var folderSection: some View {
        Section("文件夹") {
            if services.folders.folders.isEmpty {
                Text("⌘⇧O 添加文件夹")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            ForEach(services.folders.folders) { folder in
                FolderDisclosureView(folder: folder)
            }
        }
    }

    // MARK: 当前打开（按类型分组）

    private var openTabsSection: some View {
        Section("当前打开") {
            if workspace.tabs.isEmpty {
                Text("尚未打开文件")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            ForEach(groupedOpenTabs, id: \.0) { group in
                DisclosureGroup {
                    ForEach(group.1) { tab in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(SakuraTheme.kindColor(tab.kind))
                                .frame(width: 5, height: 5)
                            Text(tab.title)
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sidebarRowStyle(selected: workspace.selectedTabId == tab.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            workspace.selectedTabId = tab.id
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("打开的\(tab.kind.displayName)：\(tab.title)")
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: group.0.symbolName)
                            .font(.system(size: 12))
                            .foregroundColor(SakuraTheme.kindColor(group.0))
                        Text("\(group.0.displayName) · \(group.1.count)")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
            }
        }
    }

    private var groupedOpenTabs: [(FileKind, [TabDocument])] {
        var buckets: [FileKind: [TabDocument]] = [:]
        for tab in workspace.tabs {
            buckets[tab.kind, default: []].append(tab)
        }
        return FileKind.allCases.compactMap { kind in
            guard let tabs = buckets[kind], !tabs.isEmpty else { return nil }
            return (kind, tabs)
        }
    }
}

/// 文件夹展开行：按类型分组列出其中的文件。
private struct FolderDisclosureView: View {

    @EnvironmentObject private var services: AppServices
    let folder: FolderEntry

    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            let files = services.folders.filesByFolder[folder.id] ?? []
            if files.isEmpty {
                Text("扫描中…")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            } else {
                ForEach(groupByKind(files), id: \.0) { kind, urls in
                    DisclosureGroup {
                        ForEach(urls, id: \.absoluteString) { url in
                            Text(url.lastPathComponent)
                                .font(.system(size: 11.5))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 8)
                                .sidebarRowStyle(selected: false)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    services.open(urls: [url])
                                }
                                .help(url.path)
                        }
                    } label: {
                        Label("\(kind.displayName) · \(urls.count)", systemImage: kind.symbolName)
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 4)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text(folder.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
        }
        .contextMenu {
            Button("重新扫描") {
                services.folders.rescan(folder: folder.id)
            }
            Divider()
            Button("从侧边栏移除") {
                services.folders.removeFolder(folder.id)
            }
        }
        .help(folder.id.path)
    }

    private func groupByKind(_ urls: [URL]) -> [(FileKind, [URL])] {
        var buckets: [FileKind: [URL]] = [:]
        for url in urls {
            buckets[FileKind.detect(url: url), default: []].append(url)
        }
        return FileKind.allCases.compactMap { kind in
            guard let list = buckets[kind], !list.isEmpty else { return nil }
            return (kind, list)
        }
    }
}
