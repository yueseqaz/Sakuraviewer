import SwiftUI
import AppKit
import SakuraViewerCore

/// 文本/代码查看器共享模型。
@MainActor
final class TextViewModel: ObservableObject {

    @Published var attributed: NSAttributedString = NSAttributedString(string: "")
    @Published var query: String = ""
    @Published var matchCount: Int = 0
    @Published var matchIndex: Int = 0
    @Published var isFindVisible: Bool = false
    @Published var findFocused: Bool = false
    /// 查找跳转计数器：下一个/上一个各一个。
    @Published var findTick: Int = 0
    @Published var findBackTick: Int = 0
    @Published var wrapEnabled: Bool = true
    @Published var fontSize: CGFloat
    @Published var lineCount: Int = 0

    let tab: TabDocument
    let language: CodeLanguage
    let highlightEnabled: Bool

    init(tab: TabDocument, language: CodeLanguage, highlightEnabled: Bool) {
        self.tab = tab
        self.language = language
        self.highlightEnabled = highlightEnabled
        self.fontSize = CGFloat(AppServices.shared.settings.codeFontSize)
    }

    // MARK: 加载

    func load() {
        tab.status = .loading
        let url = tab.currentURL
        let maxBytes = TextFileLoader.hardLimit
        Task.detached(priority: .userInitiated) { [weak self] in
            let result = TextFileLoader.load(url: url, maxBytes: maxBytes)
            await MainActor.run { [weak self] in
                guard let self, self.tab.currentURL == url else { return }
                switch result {
                case .failure(let error):
                    let message: String
                    switch error {
                    case .fileNotFound: message = "文件不存在或已被移动"
                    case .noPermission: message = "没有读取该文件的权限"
                    case .tooLarge(let size): message = "文件过大（\(SakuraFormatter.fileSize(size))），超过 32 MB 安全上限"
                    case .readFailed(let reason): message = reason
                    }
                    self.tab.status = .failed(message)
                case .success(let payload):
                    self.rebuildAttributed(text: payload.text, encodingName: payload.encoding.displayName, fileSize: payload.fileSize)
                    self.tab.status = .ready
                }
            }
        }
    }

    private func rebuildAttributed(text: String, encodingName: String, fileSize: Int) {
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let lineCount = text.isEmpty ? 0 : text.components(separatedBy: "\n").count
        self.lineCount = lineCount

        if highlightEnabled, fileSize <= TextFileLoader.highlightLimit {
            self.attributed = SyntaxHighlighter.attributed(text, language: language, font: font)
        } else {
            let attributed = NSMutableAttributedString(string: text)
            attributed.addAttributes([
                .font: font,
                .foregroundColor: NSColor.labelColor,
            ], range: NSRange(location: 0, length: (text as NSString).length))
            self.attributed = attributed
        }

        let highlightNote = (highlightEnabled && fileSize > TextFileLoader.highlightLimit) ? " · 大文件已关闭高亮" : ""
        tab.statusDetail = "\(lineCount.formatted()) 行 · \(encodingName) · \(SakuraFormatter.fileSize(fileSize))\(highlightNote)"
    }

    // MARK: 字号

    func increaseFont() {
        fontSize = min(fontSize + 1, 40)
        reapplyFont()
    }

    func decreaseFont() {
        fontSize = max(fontSize - 1, 8)
        reapplyFont()
    }

    private func reapplyFont() {
        guard attributed.length > 0 else { return }
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        mutable.addAttribute(.font, value: font, range: NSRange(location: 0, length: mutable.length))
        attributed = mutable
    }

    // MARK: 查找结果写回

    func reportSearch(count: Int, index: Int) {
        matchCount = count
        matchIndex = index
    }
}
