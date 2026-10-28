import SwiftUI
import AppKit
import SakuraViewerCore

/// 左侧边栏：打开入口与文件树。
/// 使用 ScrollView + 自绘分区替代 List：展开与滚动行为完全可控，避免
/// List 中 DisclosureGroup 与自定义行背景组合产生的展开/复用怪癖。
struct SidebarView: View {

    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var workspace: WorkspaceModel

    @State private var expandedFolders: Set<URL> = []
    @State private var expandedNodes: Set<URL> = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Color.clear.frame(height: 0)
                .onAppear { seedFolderExpansion() }
                .onChange(of: services.folders.folders) { _ in seedFolderExpansion() }
            VStack(alignment: .leading, spacing: 18) {
                actionsRow

                sidebarSection("文件树") {
                    if services.folders.folders.isEmpty {
                        placeholder("⌘⇧O 添加文件夹")
                    }
                    ForEach(services.folders.folders) { folder in
                        folderRow(folder)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(.easeOut(duration: 0.18), value: expandedFolders)
        .animation(.easeOut(duration: 0.18), value: expandedNodes)
    }

    private func seedFolderExpansion() {
        for folder in services.folders.folders {
            expandedFolders.insert(folder.id)
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
        }
    }

    private func actionButton(_ system: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: system)
                    .font(.system(size: 10.5))
                Text(help)
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
        let nodes = services.folders.treeByFolder[folder.id] ?? []
        return VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    if isExpanded {
                        expandedFolders.remove(folder.id)
                    } else {
                        expandedFolders.insert(folder.id)
                        services.folders.rescan(folder: folder.id)
                    }
                }
            } label: {
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

                    if !isExpanded, !nodes.isEmpty {
                        Text("\(nodeCount(nodes))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: SakuraTheme.smallCornerRadius)
                        .fill(Color.primary.opacity(hoverablePlaceholderOpacity))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("重新扫描") { services.folders.rescan(folder: folder.id) }
                Divider()
                Button("从侧边栏移除") { services.folders.removeFolder(folder.id) }
            }
            .help(folder.id.path)

            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    if nodes.isEmpty {
                        placeholder("扫描中…")
                    } else {
                        ForEach(nodes) { node in
                            SidebarTreeNodeView(node: node, indent: 0, expandedNodes: $expandedNodes)
                        }
                    }
                }
                .padding(.leading, 14)
                .transition(.opacity)
            }
        }
    }

    private func nodeCount(_ nodes: [FolderTreeNode]) -> Int {
        nodes.reduce(0) { total, node in
            total + (node.isDirectory ? nodeCount(node.children) : 1)
        }
    }

}

/// A recursive tree row kept as its own view so folder clicks never bubble
/// into an ancestor row and release builds keep a finite view type.
private struct SidebarTreeNodeView: View {

    let node: FolderTreeNode
    let indent: Int
    @Binding var expandedNodes: Set<URL>
    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        if node.isDirectory {
            let isExpanded = expandedNodes.contains(node.url)
            VStack(alignment: .leading, spacing: 1) {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        if isExpanded {
                            expandedNodes.remove(node.url)
                        } else {
                            expandedNodes.insert(node.url)
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        Image(systemName: isExpanded ? "folder.fill" : "folder")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)
                        Text(node.url.lastPathComponent)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("在 Finder 中显示") {
                        NSWorkspace.shared.activateFileViewerSelecting([node.url])
                    }
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(node.children) { child in
                            SidebarTreeNodeView(node: child, indent: indent + 1, expandedNodes: $expandedNodes)
                        }
                    }
                    .padding(.leading, 14)
                    .transition(.opacity)
                }
            }
        } else {
            SidebarFileRow(
                url: node.url,
                kind: FileKind.displayKind(url: node.url),
                isSelected: workspace.selectedTab?.currentURL == node.url,
                indent: indent > 0
            )
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

            Text(url.lastPathComponent)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .primary : .primary.opacity(0.85))
                .lineLimit(1)
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
