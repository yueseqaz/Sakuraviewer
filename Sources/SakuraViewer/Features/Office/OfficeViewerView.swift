import SwiftUI
import QuickLookUI
import AppKit

/// Office documents use a selectable native text surface when macOS can import
/// the document as rich text, and fall back to Quick Look for other formats.
struct OfficeViewerView: View {

    @EnvironmentObject private var services: AppServices
    @ObservedObject var tab: TabDocument
    let isActive: Bool
    @StateObject private var model = OfficePreviewModel()
    @State private var zoom: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            if isActive {
                ZStack(alignment: .topTrailing) {
                    if let attributed = model.attributed {
                        OfficeTextPreviewView(attributed: attributed, magnification: zoom)
                    } else {
                        OfficePreviewView(url: tab.currentURL)
                    }

                    if model.attributed != nil {
                        HStack(spacing: 4) {
                            Button { zoom = max(0.5, zoom - 0.1) } label: {
                                Image(systemName: "minus.magnifyingglass")
                            }
                            .help("缩小")
                            Button { zoom = min(3, zoom + 0.1) } label: {
                                Image(systemName: "plus.magnifyingglass")
                            }
                            .help("放大")
                            Button("100%") { zoom = 1 }
                                .help("恢复实际大小")
                        }
                        .buttonStyle(.bordered)
                        .padding(12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
            HStack(spacing: 10) {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.blue)
                Text(tab.currentURL.lastPathComponent)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer()
                if model.attributed != nil {
                    Button("复制文字") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(model.attributed?.string ?? "", forType: .string)
                    }
                }
                Button("用默认应用打开") {
                    NSWorkspace.shared.open(tab.currentURL)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .onAppear {
            tab.status = .ready
            model.load(url: tab.currentURL)
            registerRouter()
        }
        .onDisappear {
            services.router.unregister(tab.id)
        }
        .onChange(of: tab.reloadToken) { _ in
            zoom = 1
            model.load(url: tab.currentURL)
        }
        .onChange(of: isActive) { active in
            if active { model.load(url: tab.currentURL) }
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

/// Word-like formats can be imported by AppKit, which gives users real text
/// selection and copying instead of a bitmap-like Quick Look preview.
@MainActor
private final class OfficePreviewModel: ObservableObject {

    @Published var attributed: NSAttributedString?
    private var generation = 0

    func load(url: URL) {
        generation += 1
        let currentGeneration = generation
        guard Self.supportsSelectableText(url) else {
            attributed = nil
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let value = try? NSAttributedString(url: url, options: [:], documentAttributes: nil)
            DispatchQueue.main.async {
                guard let self, self.generation == currentGeneration else { return }
                self.attributed = value
            }
        }
    }

    private static func supportsSelectableText(_ url: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "doc", "docx", "docm", "odt", "pages": return true
        default: return false
        }
    }
}

/// A4-sized document surface. NSScrollView magnification scales the page
/// itself, so zooming grows the paper and its text instead of stretching a
/// narrow preview column.
private struct OfficeTextPreviewView: NSViewRepresentable {

    let attributed: NSAttributedString
    let magnification: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.windowBackgroundColor
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.5
        scrollView.maxMagnification = 3

        let textView = makeTextView()
        textView.textStorage?.setAttributedString(attributed)
        let pageWidth: CGFloat = 794 // A4 at 96 DPI.
        textView.setFrameSize(NSSize(width: pageWidth, height: pageHeight(for: textView, width: pageWidth)))
        scrollView.documentView = textView
        scrollView.magnification = magnification
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != attributed.string {
            textView.textStorage?.setAttributedString(attributed)
            textView.setFrameSize(NSSize(width: textView.frame.width, height: pageHeight(for: textView, width: textView.frame.width)))
        }
        if abs(scrollView.magnification - magnification) > 0.001 {
            scrollView.magnification = magnification
        }
    }

    private func makeTextView() -> NSTextView {
        let textView = NSTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.usesFindBar = false
        textView.drawsBackground = true
        textView.backgroundColor = .white
        textView.textContainerInset = NSSize(width: 54, height: 54)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        return textView
    }

    private func pageHeight(for textView: NSTextView, width: CGFloat) -> CGFloat {
        guard let container = textView.textContainer, let layoutManager = textView.layoutManager else { return 1123 }
        container.widthTracksTextView = false
        container.containerSize = NSSize(width: width - 108, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: container)
        let usedHeight = layoutManager.usedRect(for: container).height
        return max(1123, usedHeight + 108)
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
