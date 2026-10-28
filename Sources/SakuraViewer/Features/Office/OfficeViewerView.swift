import SwiftUI
import QuickLookUI
import AppKit

/// Office documents use macOS Quick Look for an in-app preview. The default
/// compatible application remains available as a fallback for editing.
struct OfficeViewerView: View {

    @EnvironmentObject private var services: AppServices
    @ObservedObject var tab: TabDocument
    let isActive: Bool

    var body: some View {
        VStack(spacing: 0) {
            OfficePreviewView(url: tab.currentURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            HStack(spacing: 10) {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.blue)
                Text(tab.currentURL.lastPathComponent)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer()
                Button("用默认应用打开") {
                    NSWorkspace.shared.open(tab.currentURL)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
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

private struct OfficePreviewView: NSViewRepresentable {

    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)!
        view.autostarts = true
        view.previewItem = PreviewItem(url: url)
        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        if context.coordinator.url != url {
            context.coordinator.url = url
            view.previewItem = PreviewItem(url: url)
            view.refreshPreviewItem()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator {
        var url: URL
        init(url: URL) { self.url = url }
    }
}

private final class PreviewItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    let previewItemTitle: String?

    init(url: URL) {
        self.previewItemURL = url
        self.previewItemTitle = url.lastPathComponent
    }
}
