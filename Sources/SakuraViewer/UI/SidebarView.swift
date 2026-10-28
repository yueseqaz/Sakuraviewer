import SwiftUI
import AppKit
import SakuraViewerCore

/// Native file browser sidebar. The tree is backed by a List/OutlineGroup so
/// disclosure hit targets and row recycling behave like Finder.
struct SidebarView: View {

    @EnvironmentObject private var services: AppServices
    @State private var expandedRoots: Set<URL> = []

    var body: some View {
        VStack(spacing: 0) {
            actionsRow
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if services.folders.folders.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("文件树")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("⌘⇧O 添加文件夹")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 8)
                Spacer()
            } else {
                List {
                    Section("文件树") {
                        ForEach(services.folders.folders) { folder in
                            DisclosureGroup(isExpanded: rootBinding(for: folder.id)) {
                                if let nodes = services.folders.treeByFolder[folder.id] {
                                    if nodes.isEmpty {
                                        Text("没有可查看的文件")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    } else {
                                        OutlineGroup(nodes, children: \.outlineChildren) { node in
                                            SidebarTreeRow(node: node)
                                        }
                                    }
                                } else {
                                    Text("扫描中…")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            } label: {
                                Label(folder.name, systemImage: "folder")
                                    .font(.system(size: 12, weight: .medium))
                                    .contentShape(Rectangle())
                            }
                            .contextMenu {
                                Button("重新扫描") { services.folders.rescan(folder: folder.id) }
                                Divider()
                                Button("从侧边栏移除") { services.folders.removeFolder(folder.id) }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .onAppear { seedRootExpansion() }
        .onChange(of: services.folders.folders) { _ in seedRootExpansion() }
    }

    private func rootBinding(for url: URL) -> Binding<Bool> {
        Binding(
            get: { expandedRoots.contains(url) },
            set: { isExpanded in
                if isExpanded { expandedRoots.insert(url) }
                else { expandedRoots.remove(url) }
            }
        )
    }

    private func seedRootExpansion() {
        for folder in services.folders.folders {
            expandedRoots.insert(folder.id)
        }
    }

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

    private func actionButton(_ system: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: system)
                .font(.system(size: 11.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: SakuraTheme.smallCornerRadius)
                        .fill(Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

/// A node row used by OutlineGroup. Directories are disclosure-only; files
/// are buttons, preventing a click on one row from being interpreted by a
/// neighboring or ancestor folder.
private struct SidebarTreeRow: View {

    let node: FolderTreeNode
    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var workspace: WorkspaceModel
    @State private var hovered = false

    private var kind: FileKind { FileKind.displayKind(url: node.url) }
    private var isOffice: Bool { FileKind.isOfficeDocument(node.url) }
    private var isSelected: Bool { workspace.selectedTab?.currentURL == node.url }

    var body: some View {
        Group {
            if node.isDirectory {
                folderLabel
            } else {
                Button { services.open(urls: [node.url]) } label: { fileLabel }
                    .buttonStyle(.plain)
            }
        }
        .onHover { hovered = $0 }
        .contentShape(Rectangle())
        .contextMenu {
            Button("在 Finder 中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([node.url])
            }
            if !node.isDirectory {
                Button(services.favorites.isFavorite(node.url) ? "取消收藏" : "添加到收藏") {
                    _ = services.favorites.toggle(node.url)
                }
            }
        }
        .help(node.url.path)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(node.isDirectory ? "文件夹 \(node.url.lastPathComponent)" : "\(isOffice ? "Office" : kind.displayName)文件 \(node.url.lastPathComponent)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var folderLabel: some View {
        Label(node.url.lastPathComponent, systemImage: "folder")
            .font(.system(size: 12))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fileLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: isOffice ? "doc.on.doc" : kind.symbolName)
                .font(.system(size: 12))
                .foregroundColor(isOffice ? .blue : SakuraTheme.kindColor(kind))
                .frame(width: 15)
            Text(node.url.lastPathComponent)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .primary : .primary.opacity(0.85))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
        .background(isSelected ? SakuraTheme.accentSoft : Color.clear)
    }
}
