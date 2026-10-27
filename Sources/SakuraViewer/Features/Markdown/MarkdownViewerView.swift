import SwiftUI
import Combine
import SakuraViewerCore

/// Markdown 查看器：目录侧栏 + 原生渲染 + 代码高亮。
struct MarkdownViewerView: View {

    @EnvironmentObject private var services: AppServices
    @ObservedObject var tab: TabDocument
    let isActive: Bool

    @State private var document: MarkdownDocument?
    @State private var loadError: String?
    @State private var showTOC = false
    @State private var isReloading = false

    var body: some View {
        content
            .toolbar { toolbar }
            .onAppear {
                if document == nil, loadError == nil {
                    load()
                }
                registerRouter()
            }
            .onDisappear {
                services.router.unregister(tab.id)
            }
            .onChange(of: tab.reloadToken) { _ in
                load()
            }
    }

    // MARK: 加载

    private func load() {
        tab.status = .loading
        let url = tab.currentURL
        Task.detached(priority: .userInitiated) {
            let result = TextFileLoader.load(url: url)
            await MainActor.run {
                guard self.tab.currentURL == url else { return }
                switch result {
                case .failure(let error):
                    self.loadError = "读取失败：\(error)"
                    self.tab.status = .failed(self.loadError!)
                case .success(let payload):
                    let parsed = MarkdownParser.parse(payload.text)
                    self.document = parsed
                    self.loadError = nil
                    self.tab.status = .ready
                    self.tab.statusDetail = "\(parsed.toc.count) 个标题 · \(payload.encoding.displayName) · \(SakuraFormatter.fileSize(payload.fileSize))"
                }
            }
        }
    }

    // MARK: 内容

    @ViewBuilder
    private var content: some View {
        if let error = loadError {
            ErrorStateView(
                title: "无法打开 Markdown",
                message: "\(tab.currentURL.lastPathComponent)：\(error)",
                retryAction: { load() }
            )
        } else if let document {
            HStack(spacing: 0) {
                markdownBody(document)
                if showTOC {
                    Divider()
                    tocPanel(document)
                        .frame(width: 220)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.18), value: showTOC)
        } else {
            LoadingStateView(text: "正在渲染 Markdown…")
        }
    }

    private func markdownBody(_ document: MarkdownDocument) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                        MarkdownBlockView(block: block, baseURL: tab.currentURL.deletingLastPathComponent())
                            .padding(.horizontal, 28)
                    }
                    // 底部留白
                    Color.clear.frame(height: 48)
                }
                .padding(.top, 20)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
            .accessibilityLabel("Markdown 文档：\(tab.title)")
            .onChange(of: showTOC) { _ in } // 保持 scrollReader 引用稳定
            .onReceive(tocScrollPublisher) { anchor in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(anchor, anchor: .top)
                }
            }
        }
    }

    /// TOC 点击事件总线。
    private static let tocSubject = PassthroughSubject<String, Never>()
    private var tocScrollPublisher: AnyPublisher<String, Never> {
        Self.tocSubject.eraseToAnyPublisher()
    }

    private func tocPanel(_ document: MarkdownDocument) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("目录")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                IconButton(systemName: "xmark", size: 18, iconSize: 8, tint: .secondary) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showTOC = false
                    }
                }
                .help("关闭目录")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if document.toc.isEmpty {
                Text("此文档没有标题结构")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(12)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(document.toc) { entry in
                        Text(entry.title)
                            .font(.system(size: entry.level <= 2 ? 12 : 11.5, weight: entry.level <= 2 ? .medium : .regular))
                            .foregroundColor(entry.level <= 2 ? .primary : .secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .padding(.leading, CGFloat(entry.level - 1) * 10 + 12)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Self.tocSubject.send(entry.anchor)
                            }
                            .help(entry.title)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("目录条目：\(entry.title)")
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .background(Color.primary.opacity(0.02))
    }

    // MARK: 工具栏

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isActive {
            ToolbarItemGroup(placement: .primaryAction) {
                Chip(text: "Markdown")

                IconButton(systemName: "list.number", size: 26, iconSize: 12, isActive: showTOC) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        showTOC.toggle()
                    }
                }
                .help("目录（⇧⌘D）")
                .accessibilityLabel("显示目录")
                .disabled(document?.toc.isEmpty ?? true)
            }
        }
    }

    private func registerRouter() {
        services.router.register(ViewerRegistration(
            tabId: tab.id,
            capabilities: [.toc],
            perform: { action in
                switch action {
                case .toggleTOC:
                    withAnimation(.easeOut(duration: 0.18)) {
                        showTOC.toggle()
                    }
                case .refresh:
                    load()
                default:
                    break
                }
            }
        ))
    }
}
