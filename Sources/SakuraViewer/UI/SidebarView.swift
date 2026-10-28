import SwiftUI
import SakuraViewerCore

/// 左侧边栏：打开入口、最近文件、收藏、文件夹媒体库、当前打开（按类型分组）。
/// 使用 ScrollView + 自绘分区替代 List：展开与滚动行为完全可控，避免
/// List 中 DisclosureGroup 与自定义行背景组合产生的展开/复用怪癖。
struct SidebarView: View {

    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var workspace: WorkspaceModel

    @State private var expandedFolders: Set<URL> = []
    @State private var expandedGroups: Set<FileKind> = []
    /// 「当前打开」是核心导航，默认展开所有已有内容的分组。
    @State private var didSeedGroups = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Color.clear.frame(height: 0)
                .onAppear { seedGroupsIfNeeded() }
                .onChange(of: workspace.tabs.count) { _ in seedGroupsIfNeeded() }
            VStack(alignment: .leading, spacing: 18) {
                actionsRow

                sidebarSection("最近文件") {
                    if services.recents.urls.isEmpty {
                        placeholder("暂无记录")
                    }
                    ForEach(services.recents.urls, id: \.absoluteString) { url in
                        SidebarFileRow(
                            url: url,
                            kind: FileKind.detect(url: url),
                            isSelected: workspace.selectedTab?.originURL == url
                        )
                    }
                }

                sidebarSection("收藏") {
                    if services.favorites.urls.isEmpty {
                        placeholder("右键文件可添加收藏")
                    }
                    ForEach(services.favorites.urls, id: \.absoluteString) { url in
                        SidebarFileRow(
                            url: url,
                            kind: FileKind.detect(url: url),
                            isSelected: workspace.selectedTab?.originURL == url
                        )
                    }
                }

                sidebarSection("文件夹") {
                    if services.folders.folders.isEmpty {
                        placeholder("⌘⇧O 添加文件夹")
                    }
                    ForEach(services.folders.folders) { folder in
                        folderRow(folder)
                    }
                }

                sidebarSection("当前打开") {
                    if workspace.tabs.isEmpty {
                        placeholder("尚未打开文件")
                    }
                    let groups = groupedOpenTabs
                    if groups.isEmpty && !workspace.tabs.isEmpty {
                        placeholder("整理中…")
                    }
                    ForEach(groups, id: \.0) { kind, tabs in
                        openGroupRow(kind: kind, tabs: tabs)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(.easeOut(duration: 0.18), value: expandedFolders)
        .animation(.easeOut(duration: 0.18), value: expandedGroups)
        .animation(.easeOut(duration: 0.18), value: workspace.tabs.map(\.id))
        .animation(.easeOut(duration: 0.18), value: services.recents.urls)
    }

    /// 新打开的文件类型自动展开对应分组（不折叠用户手动收起的分组）。
    private func seedGroupsIfNeeded() {
        guard !didSeedGroups else {
            for tab in workspace.tabs where !expandedGroups.contains(tab.kind) {
                expandedGroups.insert(tab.kind)
            }
            return
        }
        didSeedGroups = true
        for tab in workspace.tabs {
            expandedGroups.insert(tab.kind)
        }
    }

    // MARK: 打开操作行

    private var actionsRow: some View {
        HStack(spacing: 8) {
            actionButton("doc", "打开文件") {
                if let urls = FilePicker.pickFiles() { services.open(urls: urls) }
            }
            actionButton("folder", "打开文件夹") {
                if let url = FilePicker.pickFolder() { services.open(urls: [url]) }
            }
            actionButton("clock.arrow.circlepath", "清理失效") {
                services.recents.purgeMissing()
            }
        }
    }

    private func actionButton(_ system: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: system)
                    .font(.system(size: 10.5))
                Text(help == "清理失效" ? "清理失效" : help)
                    .font(.system(size: 11.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: SakuraTheme.smallCornerRadius)
                    .fill(Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    // MARK: 通用构件

    private func sidebarSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 6)
                .padding(.bottom, 4)
            content()
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(.secondary.opacity(0.65))
            .padding(.leading, 6)
            .padding(.vertical, 3)
    }

    // MARK: 文件夹（自定义展开）

    private func folderRow(_ folder: FolderEntry) -> some View {
        let isExpanded = expandedFolders.contains(folder.id)
        let files = services.folders.filesByFolder[folder.id] ?? []
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 7) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))

                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)

                Text(folder.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Spacer()

                if !isExpanded, !files.isEmpty {
                    Text("\(files.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: SakuraTheme.smallCornerRadius)
                    .fill(Color.primary.opacity(hoverablePlaceholderOpacity))
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.18)) {
                    toggleSet(&expandedFolders, folder.id)
                    if isExpanded == false {
                        services.folders.rescan(folder: folder.id)
                    }
                }
            }
            .contextMenu {
                Button("重新扫描") { services.folders.rescan(folder: folder.id) }
                Divider()
                Button("从侧边栏移除") { services.folders.removeFolder(folder.id) }
            }
            .help(folder.id.path)

            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    if files.isEmpty {
                        placeholder("扫描中…")
                    } else {
                        ForEach(files.prefix(300), id: \.absoluteString) { url in
                            SidebarFileRow(
                                url: url,
                                kind: FileKind.detect(url: url),
                                isSelected: workspace.selectedTab?.currentURL == url,
                                indent: true
                            )
                        }
                        if files.count > 300 {
                            placeholder("已显示前 300 个文件")
                        }
                    }
                }
                .padding(.leading, 14)
                .transition(.opacity)
            }
        }
    }

    // MARK: 当前打开（按类型分组，自定义展开）

    private func openGroupRow(kind: FileKind, tabs: [TabDocument]) -> some View {
        let isExpanded = expandedGroups.contains(kind)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 7) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))

                Image(systemName: kind.symbolName)
                    .font(.system(size: 12))
                    .foregroundColor(SakuraTheme.kindColor(kind))

                Text(kind.displayName)
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                Text("\(tabs.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: SakuraTheme.smallCornerRadius)
                    .fill(Color.primary.opacity(hoverablePlaceholderOpacity))
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.18)) {
                    toggleSet(&expandedGroups, kind)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(tabs) { tab in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(SakuraTheme.kindColor(tab.kind))
                                .frame(width: 5, height: 5)
                            Text(tab.title)
                                .font(.system(size: 11.5))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: SakuraTheme.smallCornerRadius)
                                .fill(workspace.selectedTabId == tab.id ? SakuraTheme.accentSoft : Color.clear)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            workspace.selectedTabId = tab.id
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("打开的\(tab.kind.displayName)：\(tab.title)")
                    }
                }
                .padding(.leading, 14)
                .transition(.opacity)
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

    private func toggleSet<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}

/// 行背景的默认透明度（hover 由 SidebarHoverBackground 单独处理）。
private let hoverablePlaceholderOpacity: Double = 0

// MARK: - 文件行

struct SidebarFileRow: View {

    let url: URL
    let kind: FileKind
    let isSelected: Bool
    var indent = false

    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 12))
                .foregroundColor(SakuraTheme.kindColor(kind))
                .frame(width: 15)

            VStack(alignment: .leading, spacing: 1) {
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .primary : .primary.opacity(0.85))
                    .lineLimit(1)
                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .padding(.leading, indent ? 8 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SakuraTheme.smallCornerRadius)
                .fill(isSelected ? SakuraTheme.accentSoft : Color.primary.opacity(hovered ? 0.06 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture {
            services.open(urls: [url])
        }
        .contextMenu {
            Button("从列表中移除") {
                services.recents.remove(url)
                services.favorites.remove(url)
            }
            Divider()
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
}
