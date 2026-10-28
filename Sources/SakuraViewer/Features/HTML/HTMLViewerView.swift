import SwiftUI
import WebKit
import AppKit

/// HTML viewer backed by the system WebKit engine. Local assets are allowed
/// from the document's directory while non-file links open in the browser.
struct HTMLViewerView: View {

    @EnvironmentObject private var services: AppServices
    @ObservedObject var tab: TabDocument
    let isActive: Bool

    var body: some View {
        HTMLWebView(url: tab.currentURL, reloadToken: tab.reloadToken)
            .onAppear {
                tab.status = .ready
                registerRouter()
            }
            .onDisappear {
                services.router.unregister(tab.id)
            }
    }

    private func registerRouter() {
        services.router.register(ViewerRegistration(
            tabId: tab.id,
            capabilities: [],
            perform: { action in
                if case .refresh = action { tab.refresh() }
            }
        ))
    }
}

private struct HTMLWebView: NSViewRepresentable {

    let url: URL
    let reloadToken: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.load(url: url, in: webView, reloadToken: reloadToken)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(url: url, in: webView, reloadToken: reloadToken)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private var loadedURL: URL?
        private var loadedReloadToken = -1

        func load(url: URL, in webView: WKWebView, reloadToken: Int) {
            guard loadedURL != url || loadedReloadToken != reloadToken else { return }
            loadedURL = url
            loadedReloadToken = reloadToken
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
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
