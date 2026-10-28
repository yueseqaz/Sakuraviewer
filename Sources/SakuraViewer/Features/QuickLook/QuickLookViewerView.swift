import SwiftUI
import QuickLookUI
import AppKit

/// Formats that macOS already knows how to render are intentionally delegated
/// to Quick Look. This keeps the app small while covering RTF, EPUB, archives,
/// fonts and common design files with the same reliable preview surface.
struct QuickLookViewerView: View {

    @EnvironmentObject private var services: AppServices
    @ObservedObject var tab: TabDocument
    let isActive: Bool

    var body: some View {
        VStack(spacing: 0) {
            QuickLookPreviewView(url: tab.currentURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            HStack(spacing: 10) {
                Image(systemName: tab.kind.symbolName)
                    .foregroundColor(SakuraTheme.kindColor(tab.kind))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.currentURL.lastPathComponent)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    Text(tab.kind.displayName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
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
            services.router.register(ViewerRegistration(
                tabId: tab.id,
                capabilities: [],
                perform: { action in
                    if case .refresh = action { tab.refresh() }
                }
            ))
        }
        .onDisappear {
            services.router.unregister(tab.id)
        }
    }
}

private struct QuickLookPreviewView: NSViewRepresentable {

    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)!
        view.autostarts = true
        view.previewItem = PreviewItem(url: url)
        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        guard context.coordinator.url != url else { return }
        context.coordinator.url = url
        view.previewItem = PreviewItem(url: url)
        view.refreshPreviewItem()
    }

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
