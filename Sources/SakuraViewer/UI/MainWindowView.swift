import SwiftUI
import UniformTypeIdentifiers
import SakuraViewerCore

/// 主窗口：侧边栏 + 标签栏 + 内容区 + 状态栏，支持拖拽打开。
struct MainWindowView: View {

    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var workspace: WorkspaceModel
    @EnvironmentObject private var router: ViewerRouter

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isDropTargeted = false
    @State private var didRestoreSession = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 260, max: 360)
        } detail: {
            detail
        }
        .onChange(of: workspace.selectedTabId) { newId in
            router.activate(tabId: newId)
            scheduleSessionSave()
        }
    }

    // MARK: 详情区

    private var detail: some View {
        VStack(spacing: 0) {
            if workspace.tabs.isEmpty {
                TabBarView()
                EmptyStateView()
                StatusBarView()
            } else {
                TabBarView()
                contentArea
                StatusBarView()
            }
        }
        .toolbar { toolbarContent }
        .navigationTitle(windowTitle)
        .modifier(DropFilesModifier(isTargeted: $isDropTargeted))
        .overlay { dropOverlay }
        .onAppear {
            if !didRestoreSession {
                didRestoreSession = true
                services.restoreSessionIfEnabled()
                router.activate(tabId: workspace.selectedTabId)
            }
        }
    }

    /// 所有标签保活（隐藏不销毁），保证媒体播放与滚动位置不丢失。
    private var contentArea: some View {
        ZStack {
            ForEach(workspace.tabs) { tab in
                TabContentView(tab: tab, isActive: tab.id == workspace.selectedTabId)
                    .opacity(tab.id == workspace.selectedTabId ? 1 : 0)
                    .allowsHitTesting(tab.id == workspace.selectedTabId)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
        .animation(.easeOut(duration: 0.12), value: workspace.selectedTabId)
    }

    private var windowTitle: String {
        guard let tab = workspace.selectedTab else { return "Sakuraviewer" }
        return "\(tab.title) — Sakuraviewer"
    }

    // MARK: 工具栏（全局项；文件类型相关项由各查看器提供）

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // 侧边栏切换由 NavigationSplitView 自动提供，避免出现重复按钮。
        ToolbarItemGroup(placement: .navigation) {
            Button {
                if let urls = FilePicker.pickFiles() {
                    services.open(urls: urls)
                }
            } label: {
                Image(systemName: "folder")
            }
            .help("打开文件（⌘O）")
            .accessibilityLabel("打开文件")

            Button {
                if let url = FilePicker.pickFolder() {
                    services.open(urls: [url])
                }
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .help("打开文件夹（⌘⇧O）")
            .accessibilityLabel("打开文件夹")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            if let tab = workspace.selectedTab {
                favoriteButton(for: tab)
                Button {
                    tab.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("刷新（⌘R）")
                .accessibilityLabel("刷新")
            }
        }
    }

    private func favoriteButton(for tab: TabDocument) -> some View {
        let isFavorite = services.favorites.isFavorite(tab.currentURL)
        return Button {
            let added = services.favorites.toggle(tab.currentURL)
            _ = added
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .foregroundColor(isFavorite ? .orange : .primary)
        }
        .help(isFavorite ? "取消收藏" : "收藏")
        .accessibilityLabel(isFavorite ? "取消收藏" : "收藏")
    }

    // MARK: 拖拽覆盖层

    @ViewBuilder
    private var dropOverlay: some View {
        if isDropTargeted {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(SakuraTheme.accent, style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(SakuraTheme.accent)
                    Text("松开以打开文件 / 文件夹")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            .padding(24)
            .transition(.opacity)
            .allowsHitTesting(false)
        }
    }

    private func scheduleSessionSave() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            services.saveSession()
        }
    }
}

// MARK: - 拖拽打开

struct DropFilesModifier: ViewModifier {

    @Binding var isTargeted: Bool
    @EnvironmentObject private var services: AppServices

    func body(content: Content) -> some View {
        content
            .onDrop(
                of: [UTType.fileURL],
                delegate: FileDropDelegate(services: services, isTargeted: $isTargeted)
            )
    }
}

/// 文件拖放代理：接受文件 URL（含多文件与文件夹）。
struct FileDropDelegate: DropDelegate {

    let services: AppServices
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in info.itemProviders(for: [UTType.fileURL]) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                defer { group.leave() }
                if let url {
                    DispatchQueue.main.async {
                        urls.append(url)
                    }
                }
            }
        }
        group.notify(queue: .main) { [services] in
            guard !urls.isEmpty else { return }
            services.open(urls: urls)
        }
        return true
    }
}

// MARK: - 标签内容分发

/// 按文件类型分发到对应查看器。
struct TabContentView: View {

    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var router: ViewerRouter
    @EnvironmentObject private var settings: AppSettings
    let tab: TabDocument
    let isActive: Bool

    var body: some View {
        switch tab.kind {
        case .image:
            ImageViewerView(tab: tab, isActive: isActive)
        case .video:
            VideoViewerView(tab: tab, isActive: isActive)
        case .audio:
            AudioViewerView(tab: tab, isActive: isActive)
        case .pdf:
            PDFViewerView(tab: tab, isActive: isActive)
        case .code:
            CodeViewerView(tab: tab, isActive: isActive)
        case .markdown:
            MarkdownViewerView(tab: tab, isActive: isActive)
        case .plainText:
            TextViewerView(tab: tab, isActive: isActive)
        case .unsupported:
            UnsupportedViewerView(tab: tab, isActive: isActive)
        }
    }
}
