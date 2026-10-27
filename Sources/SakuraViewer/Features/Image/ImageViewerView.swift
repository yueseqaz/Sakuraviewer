import SwiftUI
import AppKit

/// 图片缩放画布：NSScrollView + NSImageView，触控板捏合缩放、双指平移。
struct ImageCanvasView: NSViewRepresentable {

    @ObservedObject var model: ImageViewModel

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .underPageBackgroundColor
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.02
        scrollView.maxMagnification = 40
        scrollView.frameCenterRotation = 0

        let imageView = NSImageView()
        imageView.imageScaling = .scaleNone
        imageView.animates = true
        imageView.translatesAutoresizingMaskIntoConstraints = true
        scrollView.documentView = imageView

        if let clip = scrollView.contentView as? NSClipView {
            clip.copiesOnScroll = false
        }

        let coordinator = context.coordinator
        coordinator.scrollView = scrollView
        coordinator.imageView = imageView
        coordinator.model = model

        // 捏合结束 → 回写 zoom
        coordinator.observers.append(NotificationCenter.default.addObserver(
            forName: NSScrollView.didEndLiveMagnifyNotification, object: scrollView, queue: .main
        ) { [weak coordinator] _ in
            coordinator?.syncZoomFromScroll()
        })
        coordinator.observers.append(NotificationCenter.default.addObserver(
            forName: NSScrollView.didEndLiveScrollNotification, object: scrollView, queue: .main
        ) { [weak coordinator] _ in
            coordinator?.syncZoomFromScroll()
        })
        // 容器尺寸变化 → fit 重新计算
        coordinator.observers.append(NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification, object: scrollView, queue: .main
        ) { [weak coordinator] _ in
            coordinator?.applyCurrentState(force: false)
        })
        scrollView.postsFrameChangedNotifications = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.model = model
        coordinator.applyCurrentState(force: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {

        weak var scrollView: NSScrollView?
        weak var imageView: NSImageView?
        var model: ImageViewModel?
        var observers: [NSObjectProtocol] = []

        private var appliedImage: NSImage?
        private var appliedRotation: Double = -1
        private var appliedAnimated = false
        private var suppressZoomSync = false

        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }

        /// 应用模型状态到视图。
        func applyCurrentState(force: Bool) {
            guard let scrollView, let imageView, let model else { return }
            let needsNewImage = force || appliedImage !== model.image || appliedRotation != model.rotation
            if needsNewImage {
                let display = model.rotatedImageIfNeeded()
                imageView.image = display
                imageView.animates = model.isAnimated && model.rotation == 0
                if let display {
                    imageView.frame = NSRect(origin: .zero, size: display.size)
                }
                appliedImage = model.image
                appliedRotation = model.rotation
                appliedAnimated = model.isAnimated
                scrollView.magnification = model.effectiveZoom
            }
            applyZoom(force: needsNewImage)
        }

        private func applyZoom(force: Bool) {
            guard let scrollView, let model else { return }
            let target = model.effectiveZoom
            if model.mode == .fit {
                let fit = fitScale(for: scrollView)
                if model.fitScale != fit {
                    model.fitScale = fit
                }
                if force || abs(scrollView.magnification - fit) > 0.001 {
                    suppressZoomSync = true
                    scrollView.magnification = fit
                }
            } else if force || abs(scrollView.magnification - target) > 0.001 {
                suppressZoomSync = true
                scrollView.magnification = target
            }
        }

        private func fitScale(for scrollView: NSScrollView) -> Double {
            guard let size = imageView?.image?.size, size.width > 0, size.height > 0 else { return 1 }
            let container = scrollView.contentSize
            guard container.width > 8, container.height > 8 else { return 1 }
            let scale = min(container.width / size.width, container.height / size.height)
            return min(max(scale, 0.02), 8)
        }

        /// 捏合手势结束后回写模型。
        func syncZoomFromScroll() {
            guard let scrollView, let model else { return }
            guard !suppressZoomSync else {
                suppressZoomSync = false
                return
            }
            let value = scrollView.magnification
            model.zoom = min(max(value, 0.02), 40)
            model.mode = .custom
            model.updateStatus()
        }
    }
}

/// 图片查看器主视图。
struct ImageViewerView: View {

    @EnvironmentObject private var services: AppServices
    @ObservedObject var tab: TabDocument
    let isActive: Bool

    @StateObject private var model: ImageViewModel

    init(tab: TabDocument, isActive: Bool) {
        self.tab = tab
        self.isActive = isActive
        _model = StateObject(wrappedValue: ImageViewModel(
            tab: tab,
            preference: AppServices.shared.settings.zoomPreference
        ))
    }

    var body: some View {
        content
            .toolbar { toolbar }
            .onAppear {
                if model.image == nil && model.loadingError == nil {
                    model.load()
                }
                registerRouter()
            }
            .onDisappear {
                services.router.unregister(tab.id)
            }
            .onChange(of: tab.reloadToken) { _ in
                model.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let error = model.loadingError {
            ErrorStateView(
                title: "无法打开图片",
                message: "\(tab.currentURL.lastPathComponent)：\(error)",
                retryAction: { model.load() }
            )
        } else if model.image == nil {
            LoadingStateView(text: "正在加载图片…")
        } else {
            ZStack {
                ImageCanvasView(model: model)
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        // 悬浮缩放控制
                        VStack(spacing: 4) {
                            IconButton(systemName: "plus.magnifyingglass") { model.zoomIn() }
                                .help("放大（⌘+）")
                            IconButton(systemName: "minus.magnifyingglass") { model.zoomOut() }
                                .help("缩小（⌘-）")
                            IconButton(systemName: "arrow.down.right.and.arrow.up.left") { model.fitToWindow() }
                                .help("适应窗口")
                            IconButton(systemName: "1.magnifyingglass") { model.actualSize() }
                                .help("实际大小（⌘0）")
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial).shadow(radius: 4, y: 2))
                    }
                    .padding(12)
                }
            }
            .accessibilityLabel("图片查看器：\(tab.title)")
        }
    }

    // MARK: 工具栏

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isActive {
            ToolbarItemGroup(placement: .primaryAction) {
                IconButton(systemName: "chevron.left", size: 26, iconSize: 12) { model.goPrevious() }
                    .help("上一张（⌘←）")
                    .accessibilityLabel("上一张")
                    .disabled(!model.canGoPrev)

                IconButton(systemName: "chevron.right", size: 26, iconSize: 12) { model.goNext() }
                    .help("下一张（⌘→）")
                    .accessibilityLabel("下一张")
                    .disabled(!model.canGoNext)

                Divider()

                IconButton(systemName: "rotate.right", size: 26, iconSize: 12) { model.rotate() }
                    .help("旋转 90°（⇧⌘R）")
                    .accessibilityLabel("旋转")

                IconButton(systemName: "arrow.down.right.and.arrow.up.left", size: 26, iconSize: 12) { model.fitToWindow() }
                    .help("适应窗口")
                    .accessibilityLabel("适应窗口")

                IconButton(systemName: "1.magnifyingglass", size: 26, iconSize: 12) { model.actualSize() }
                    .help("实际大小（⌘0）")
                    .accessibilityLabel("实际大小")
            }
        }
    }

    // MARK: 动作注册

    private func registerRouter() {
        services.router.register(ViewerRegistration(
            tabId: tab.id,
            capabilities: [.zoom, .rotate, .paging, .arrowPaging],
            perform: { action in
                switch action {
                case .zoomIn: model.zoomIn()
                case .zoomOut: model.zoomOut()
                case .zoomFit: model.fitToWindow()
                case .zoomActual: model.actualSize()
                case .rotate: model.rotate()
                case .nextItem: model.goNext()
                case .prevItem: model.goPrevious()
                default: break
                }
            }
        ))
    }
}
