import SwiftUI
import PDFKit
import SakuraViewerCore

/// PDF 查看器模型。
@MainActor
final class PDFViewerModel: ObservableObject {

    @Published var currentPage: Int = 1
    @Published var pageCount: Int = 0
    @Published var zoom: Double = 1
    @Published var searchQuery: String = ""
    @Published var matchCount: Int = 0
    @Published var matchIndex: Int = 0
    @Published var isFindVisible: Bool = false
    @Published var findTick = 0
    @Published var findBackTick = 0
    @Published var thumbnailsVisible: Bool = false
    @Published var isLoading: Bool = true
    @Published var errorText: String?
    /// 页码输入框草稿。
    @Published var pageInput: String = ""

    weak var pdfView: PDFView?
    let tab: TabDocument
    private var selections: [PDFSelection] = []

    init(tab: TabDocument) {
        self.tab = tab
    }

    // MARK: 文档加载

    func loadDocument() {
        isLoading = true
        errorText = nil
        tab.status = .loading
        let url = tab.currentURL
        Task.detached(priority: .userInitiated) { [weak self] in
            let document = PDFDocument(url: url)
            await MainActor.run { [weak self] in
                guard let self, self.tab.currentURL == url else { return }
                guard let document else {
                    self.errorText = "无法读取 PDF：文件损坏或加密"
                    self.tab.status = .failed(self.errorText ?? "无法读取")
                    self.isLoading = false
                    return
                }
                self.pdfView?.document = document
                self.pageCount = document.pageCount
                self.currentPage = 1
                self.pageInput = "1"
                self.isLoading = false
                self.tab.status = .ready
                self.applyZoomPreference()
                self.updateStatus()
            }
        }
    }

    private func applyZoomPreference() {
        switch AppServices.shared.settings.zoomPreference {
        case .fit: fitToWindow()
        case .actual: pdfView?.scaleFactor = 1.0
        }
    }

    // MARK: 页面与缩放

    func goToPage(_ number: Int) {
        guard let pdfView, let document = pdfView.document else { return }
        let index = min(max(number, 1), document.pageCount) - 1
        guard index >= 0, let page = document.page(at: index) else { return }
        pdfView.go(to: PDFDestination(page: page, at: .zero))
        currentPage = index + 1
        pageInput = String(currentPage)
        updateStatus()
    }

    func nextPage() {
        goToPage(currentPage + 1)
    }

    func previousPage() {
        goToPage(currentPage - 1)
    }

    func syncFromView() {
        guard let pdfView else { return }
        if let page = pdfView.currentPage, let document = pdfView.document,
           let index = document.index(for: page) as Int? {
            if index >= 0 {
                currentPage = index + 1
                pageInput = String(currentPage)
            }
        }
        zoom = pdfView.scaleFactor
        updateStatus()
    }

    func zoomIn() {
        guard let pdfView else { return }
        pdfView.scaleFactor = min(pdfView.scaleFactor * 1.2, 16)
        zoom = pdfView.scaleFactor
        updateStatus()
    }

    func zoomOut() {
        guard let pdfView else { return }
        pdfView.scaleFactor = max(pdfView.scaleFactor / 1.2, 0.1)
        zoom = pdfView.scaleFactor
        updateStatus()
    }

    func fitToWindow() {
        guard let pdfView else { return }
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        zoom = pdfView.scaleFactor
        updateStatus()
    }

    func actualSize() {
        guard let pdfView else { return }
        pdfView.scaleFactor = 1.0
        zoom = 1.0
        updateStatus()
    }

    func updateStatus() {
        tab.statusDetail = "第 \(currentPage) / \(max(pageCount, 1)) 页 · \(SakuraFormatter.zoomPercent(zoom))"
    }

    // MARK: 搜索

    func performSearch() {
        guard let pdfView, let document = pdfView.document else { return }
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        // 清除旧高亮
        pdfView.highlightedSelections = []
        selections = []
        matchCount = 0
        matchIndex = 0

        guard !query.isEmpty else {
            updateStatus()
            return
        }

        var results: [PDFSelection] = []
        let limit = min(document.pageCount, 1500)
        for pageIndex in 0..<limit {
            guard let page = document.page(at: pageIndex), let pageString = page.string else { continue }
            let nsString = pageString as NSString
            var searchRange = NSRange(location: 0, length: nsString.length)
            while searchRange.length > 0, results.count < 500 {
                let found = nsString.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange)
                guard found.location != NSNotFound else { break }
                if let selection = page.selection(for: found) {
                    selection.color = SakuraTheme.accentNS
                    results.append(selection)
                }
                let next = found.location + max(found.length, 1)
                searchRange = NSRange(location: next, length: nsString.length - next)
            }
            if results.count >= 500 { break }
        }

        selections = results
        matchCount = results.count
        if !results.isEmpty {
            pdfView.highlightedSelections = results
            pdfView.go(to: results[0])
            matchIndex = 0
        }
        updateStatus()
    }

    func gotoNextMatch() {
        guard !selections.isEmpty, let pdfView else { return }
        matchIndex = (matchIndex + 1) % selections.count
        pdfView.go(to: selections[matchIndex])
        updateStatus()
    }

    func gotoPrevMatch() {
        guard !selections.isEmpty, let pdfView else { return }
        matchIndex = (matchIndex - 1 + selections.count) % selections.count
        pdfView.go(to: selections[matchIndex])
        updateStatus()
    }
}

extension SakuraTheme {
    static let accentNS = NSColor(srgbRed: 0.906, green: 0.325, blue: 0.573, alpha: 0.9)
}
