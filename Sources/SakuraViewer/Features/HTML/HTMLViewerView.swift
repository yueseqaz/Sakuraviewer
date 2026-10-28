import SwiftUI
import WebKit
import AppKit

/// HTML viewer backed by WebKit. Local assets are allowed from the document's
/// directory while external links are handed to the user's default browser.
struct HTMLViewerView: View {

    @EnvironmentObject private var services: AppServices
    @ObservedObject var tab: TabDocument
    let isActive: Bool
    @StateObject private var model = HTMLViewModel()

    var body: some View {
        HTMLWebView(url: tab.currentURL, reloadToken: tab.reloadToken, model: model)
            .toolbar { toolbar }
            .onAppear {
                tab.status = .ready
                registerRouter()
            }
            .onDisappear {
                services.router.unregister(tab.id)
            }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { model.goBack() } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!model.canGoBack)
            .help("后退")
            .accessibilityLabel("后退")

            Button { model.goForward() } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!model.canGoForward)
            .help("前进")
            .accessibilityLabel("前进")

            Button { model.reload() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("刷新页面")
            .accessibilityLabel("刷新页面")

            Menu {
                Button("放大") { model.zoom(by: 1.1) }
                Button("缩小") { model.zoom(by: 0.9) }
                Button("恢复默认缩放") { model.resetZoom() }
                Divider()
                Button("在浏览器打开") { NSWorkspace.shared.open(tab.currentURL) }
            } label: {
                Image(systemName: "globe")
            }
            .help("网页选项")
            .accessibilityLabel("网页选项")
        }
    }

    private func registerRouter() {
        services.router.register(ViewerRegistration(
            tabId: tab.id,
            capabilities: [.zoom],
            perform: { action in
                switch action {
                case .refresh: tab.refresh()
                case .zoomIn: model.zoom(by: 1.1)
                case .zoomOut: model.zoom(by: 0.9)
                case .zoomActual: model.resetZoom()
                default: break
                }
            }
        ))
    }
}

@MainActor
private final class HTMLViewModel: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false

    weak var webView: WKWebView?

    func attach(_ webView: WKWebView) {
        self.webView = webView
        updateNavigationState()
    }

    func updateNavigationState() {
        canGoBack = webView?.canGoBack ?? false
        canGoForward = webView?.canGoForward ?? false
    }

    func goBack() { webView?.goBack(); updateNavigationState() }
    func goForward() { webView?.goForward(); updateNavigationState() }
    func reload() { webView?.reload() }
    func zoom(by factor: CGFloat) {
        guard let webView else { return }
        webView.pageZoom = max(0.25, min(webView.pageZoom * factor, 3.0))
    }
    func resetZoom() { webView?.pageZoom = 1.0 }
}

private struct HTMLWebView: NSViewRepresentable {
    let url: URL
    let reloadToken: Int
    @ObservedObject var model: HTMLViewModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.load(url: url, in: webView, reloadToken: reloadToken)
        model.attach(webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        model.attach(webView)
        context.coordinator.load(url: url, in: webView, reloadToken: reloadToken)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let model: HTMLViewModel
        private var loadedURL: URL?
        private var loadedReloadToken = -1

        init(model: HTMLViewModel) { self.model = model }

        func load(url: URL, in webView: WKWebView, reloadToken: Int) {
            guard loadedURL != url || loadedReloadToken != reloadToken else { return }
            loadedURL = url
            loadedReloadToken = reloadToken
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            model.updateNavigationState()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            model.updateNavigationState()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if url.isFileURL {
                decisionHandler(.allow)
            } else {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            }
        }
    }
}
