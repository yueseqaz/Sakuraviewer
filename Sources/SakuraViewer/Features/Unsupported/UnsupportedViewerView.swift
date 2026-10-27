import SwiftUI
import SakuraViewerCore

/// 不支持的二进制文件查看器：友好提示 + 头部十六进制预览，可尝试按文本打开。
struct UnsupportedViewerView: View {

    @EnvironmentObject private var services: AppServices
    @ObservedObject var tab: TabDocument
    let isActive: Bool

    @State private var hexPreview = ""

    var body: some View {
        UnsupportedStateView(
            url: tab.currentURL,
            hexPreview: hexPreview,
            openAsText: {
                services.workspace.open(url: tab.currentURL, kindOverride: .plainText)
                services.recents.add(tab.currentURL)
            }
        )
        .onAppear {
            if hexPreview.isEmpty {
                loadHexPreview()
            }
            registerRouter()
        }
        .onDisappear {
            services.router.unregister(tab.id)
        }
        .onChange(of: tab.reloadToken) { _ in
            loadHexPreview()
        }
    }

    private func loadHexPreview() {
        tab.status = .ready
        let url = tab.currentURL
        Task.detached(priority: .utility) {
            let preview = Self.makeHexPreview(url: url)
            await MainActor.run {
                if self.tab.currentURL == url {
                    self.hexPreview = preview
                    let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
                    self.tab.statusDetail = "二进制 · \(SakuraFormatter.fileSize(size))"
                }
            }
        }
    }

    nonisolated private static func makeHexPreview(url: URL, maxBytes: Int = 256) -> String {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe).prefix(maxBytes), !data.isEmpty else {
            return ""
        }
        var lines: [String] = []
        let bytes = Array(data)
        for offset in stride(from: 0, to: bytes.count, by: 16) {
            let chunk = bytes[offset..<min(offset + 16, bytes.count)]
            let hex = chunk.map { String(format: "%02X", $0) }.joined(separator: " ")
            let ascii = chunk.map { b in (0x20..<0x7F).contains(b) ? Character(UnicodeScalar(b)) : "." }
            lines.append(String(format: "%08X  %@  %@", offset, hex.padding(toLength: 47, withPad: " ", startingAt: 0), String(ascii)))
        }
        return lines.joined(separator: "\n")
    }

    private func registerRouter() {
        services.router.register(ViewerRegistration(
            tabId: tab.id,
            capabilities: [],
            perform: { _ in }
        ))
    }
}
