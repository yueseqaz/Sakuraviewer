import SwiftUI
import PDFKit
import SakuraViewerCore

/// PDFView 封装：连续滚动、页面/缩放事件同步。
struct PDFCanvasView: NSViewRepresentable {

    @ObservedObject var model: PDFViewerModel

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = false
        pdfView.backgroundColor = .underPageBackgroundColor
        pdfView.pageShadowsEnabled = true
        pdfView.delegate = context.coordinator
        pdfView.minScaleFactor = 0.1
        pdfView.maxScaleFactor = 16

        let coordinator = context.coordinator
        coordinator.pdfView = pdfView
        coordinator.model = model

        coordinator.observers.append(NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged, object: pdfView, queue: .main
        ) { [weak coordinator] _ in
            coordinator?.model?.syncFromView()
        })
        coordinator.observers.append(NotificationCenter.default.addObserver(
            forName: .PDFViewScaleChanged, object: pdfView, queue: .main
        ) { [weak coordinator] _ in
            coordinator?.model?.syncFromView()
        })

        // 首次创建即挂载文档（从隐藏占位切回时恢复内容）
        if pdfView.document !== model.loadedDocument {
            pdfView.document = model.loadedDocument
        }

        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        context.coordinator.model = model
        if model.pdfView !== pdfView {
            model.pdfView = pdfView
        }
        // PDFView 按需创建：重新可见时恢复文档、页码与缩放
        if pdfView.document !== model.loadedDocument {
            pdfView.document = model.loadedDocument
            if model.currentPage > 1 {
                model.goToPage(model.currentPage)
            }
            model.applyZoomPreference()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, PDFViewDelegate {
        weak var pdfView: PDFView?
        weak var model: PDFViewerModel?
        var observers: [NSObjectProtocol] = []

        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }
    }
}

/// PDF 缩略图侧栏。
struct PDFThumbnailCanvas: NSViewRepresentable {

    @ObservedObject var model: PDFViewerModel

    func makeNSView(context: Context) -> PDFThumbnailView {
        let view = PDFThumbnailView()
        view.thumbnailSize = CGSize(width: 72, height: 96)
        view.backgroundColor = .clear
        view.pdfView = model.pdfView
        return view
    }

    func updateNSView(_ view: PDFThumbnailView, context: Context) {
        if view.pdfView !== model.pdfView {
            view.pdfView = model.pdfView
        }
    }
}

/// PDF 查看器主视图。
struct PDFViewerView: View {

    @EnvironmentObject private var services: AppServices
    @ObservedObject var tab: TabDocument
    let isActive: Bool

    @StateObject private var model: PDFViewerModel
    @FocusState private var findFocused: Bool

    init(tab: TabDocument, isActive: Bool) {
        self.tab = tab
        self.isActive = isActive
        _model = StateObject(wrappedValue: PDFViewerModel(tab: tab))
    }

    var body: some View {
        content
            .toolbar { toolbar }
            .onAppear {
                if model.pdfView == nil || model.pageCount == 0 {
                    model.loadDocument()
                }
                registerRouter()
            }
            .onDisappear {
                services.router.unregister(tab.id)
            }
            .onChange(of: tab.reloadToken) { _ in
                model.loadDocument()
            }
    }

    // MARK: 内容

    @ViewBuilder
    private var content: some View {
        if let error = model.errorText {
            ErrorStateView(
                title: "无法打开 PDF",
                message: "\(tab.currentURL.lastPathComponent)：\(error)",
                retryAction: { model.loadDocument() }
            )
        } else if model.isLoading {
            LoadingStateView(text: "正在解析 PDF…")
        } else {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 0) {
                    if model.thumbnailsVisible {
                        PDFThumbnailCanvas(model: model)
                            .frame(width: 96)
                            .background(Color.primary.opacity(0.03))
                            .overlay(alignment: .trailing) { Divider() }
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    // PDFKit 的页面渲染层在 opacity(0) 的隐藏容器中不提交，
                    // 因此仅激活标签时挂载 PDFView；文档与页码由 model 保持恢复。
                    if isActive {
                        PDFCanvasView(model: model)
                    } else {
                        Rectangle()
                            .fill(Color(nsColor: .underPageBackgroundColor))
                    }
                }
                .accessibilityLabel("PDF 文档：\(tab.title)")

                if model.isFindVisible {
                    FindBarView(
                        query: $model.searchQuery,
                        matchCount: model.matchCount,
                        matchIndex: model.matchIndex,
                        onNext: { model.findTick += 1 },
                        onPrev: { model.findBackTick += 1 },
                        onClose: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                model.isFindVisible = false
                                findFocused = false
                            }
                        },
                        isFocused: $findFocused
                    )
                    .padding(.trailing, 16)
                }
            }
            .animation(.easeOut(duration: 0.18), value: model.thumbnailsVisible)
            .animation(.easeOut(duration: 0.15), value: model.isFindVisible)
        }
    }

    // MARK: 工具栏

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isActive {
            ToolbarItemGroup(placement: .primaryAction) {
                pageField

                IconButton(systemName: "sidebar.trailing", size: 26, iconSize: 12, isActive: model.thumbnailsVisible) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        model.thumbnailsVisible.toggle()
                    }
                }
                .help("缩略图（⇧⌘T）")
                .accessibilityLabel("缩略图")

                Divider()

                IconButton(systemName: "magnifyingglass", size: 26, iconSize: 12) {
                    showFind()
                }
                .help("搜索（⌘F）")
                .accessibilityLabel("搜索")

                Divider()

                IconButton(systemName: "minus.magnifyingglass", size: 26, iconSize: 12) { model.zoomOut() }
                    .help("缩小（⌘-）")
                    .accessibilityLabel("缩小")

                Text(SakuraFormatter.zoomPercent(model.zoom))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 44)
                    .accessibilityLabel("缩放比例")

                IconButton(systemName: "plus.magnifyingglass", size: 26, iconSize: 12) { model.zoomIn() }
                    .help("放大（⌘+）")
                    .accessibilityLabel("放大")

                IconButton(systemName: "arrow.down.right.and.arrow.up.left", size: 26, iconSize: 12) { model.fitToWindow() }
                    .help("适应窗口")
                    .accessibilityLabel("适应窗口")
            }
        }
    }

    private var pageField: some View {
        HStack(spacing: 5) {
            TextField("页码", text: $model.pageInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 44)
                .onSubmit {
                    if let number = Int(model.pageInput) {
                        model.goToPage(number)
                    } else {
                        model.pageInput = String(model.currentPage)
                    }
                }
                .accessibilityLabel("页码跳转")

            Text("/ \(model.pageCount)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private func showFind() {
        withAnimation(.easeOut(duration: 0.15)) {
            model.isFindVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            findFocused = true
        }
    }

    // MARK: 路由

    private func registerRouter() {
        services.router.register(ViewerRegistration(
            tabId: tab.id,
            capabilities: [.zoom, .paging, .find, .thumbnails],
            perform: { action in
                switch action {
                case .zoomIn: model.zoomIn()
                case .zoomOut: model.zoomOut()
                case .zoomFit: model.fitToWindow()
                case .zoomActual: model.actualSize()
                case .nextItem: model.nextPage()
                case .prevItem: model.previousPage()
                case .focusFind: showFind()
                case .findNext: model.gotoNextMatch()
                case .findPrev: model.gotoPrevMatch()
                case .toggleThumbnails: model.thumbnailsVisible.toggle()
                case .refresh: model.loadDocument()
                default: break
                }
            }
        ))
    }
}
