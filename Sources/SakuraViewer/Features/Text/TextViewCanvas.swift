import SwiftUI
import AppKit

/// 文本/代码画布：NSScrollView + NSTextView（TextKit 1）+ 行号标尺 + 搜索高亮。
struct TextViewCanvas: NSViewRepresentable {

    @ObservedObject var model: TextViewModel

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        // TextKit 1：行号标尺需要稳定的 layout manager
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: scrollView.contentSize)
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let textView = NSTextView(frame: .zero, textContainer: container)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.autoresizingMask = [.width]
        textView.smartInsertDeleteEnabled = false
        textView.usesFindBar = false
        textView.isIncrementalSearchingEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 12)
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor]
        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasHorizontalRuler = false
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        scrollView.documentView = textView

        let coordinator = context.coordinator
        coordinator.scrollView = scrollView
        coordinator.textView = textView
        coordinator.model = model
        coordinator.ruler = ruler
        coordinator.applyText(force: true)
        coordinator.applyWrap()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.model = model
        coordinator.applyText(force: false)
        coordinator.applyWrap()

        if coordinator.appliedFontSize != model.fontSize {
            coordinator.appliedFontSize = model.fontSize
            coordinator.applyText(force: true)
        }

        // 查询变化 → 重新搜索
        if coordinator.appliedQuery != model.query {
            coordinator.appliedQuery = model.query
            coordinator.runSearch(fromStart: true)
        }
        // 查找跳转 tick
        if coordinator.appliedFindTick != model.findTick {
            coordinator.appliedFindTick = model.findTick
            coordinator.gotoMatch(direction: 1)
        }
        if coordinator.appliedFindBackTick != model.findBackTick {
            coordinator.appliedFindBackTick = model.findBackTick
            coordinator.gotoMatch(direction: -1)
        }
        // 等宽字体同步
        if !model.wrapEnabled, coordinator.lastContainerWidth != scrollView.contentSize.width {
            coordinator.lastContainerWidth = scrollView.contentSize.width
            coordinator.applyWrap()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {

        weak var scrollView: NSScrollView?
        weak var textView: NSTextView?
        weak var ruler: LineNumberRulerView?
        var model: TextViewModel?

        var appliedTextHash: Int?
        var appliedQuery: String?
        var appliedFontSize: CGFloat?
        var appliedWrap: Bool?
        var appliedFindTick = 0
        var appliedFindBackTick = 0
        var lastContainerWidth: CGFloat = 0

        private var matches: [NSRange] = []

        // MARK: 文本

        func applyText(force: Bool) {
            guard let textView, let model else { return }
            let hash = model.attributed.hashValue
            if !force, hash == appliedTextHash, textView.textStorage?.length == model.attributed.length { return }
            appliedTextHash = hash
            textView.textStorage?.setAttributedString(model.attributed)
            // 文本内容变化后重算 documentView 尺寸（否则初始 frame 为 0，滚动区域为空）
            if model.wrapEnabled {
                textView.isVerticallyResizable = true
                textView.isHorizontallyResizable = false
                textView.autoresizingMask = [.width]
            } else {
                textView.isVerticallyResizable = true
                textView.isHorizontallyResizable = true
                textView.autoresizingMask = []
            }
            textView.sizeToFit()
            matches = []
            ruler?.invalidateCaches()
            if let appliedQuery, !appliedQuery.isEmpty {
                runSearch(fromStart: true)
            }
        }

        // MARK: 换行

        func applyWrap() {
            guard let textView, let scrollView, let model else { return }
            let wrap = model.wrapEnabled
            guard appliedWrap != wrap || wrap == false else { return }
            appliedWrap = wrap
            guard let container = textView.textContainer else { return }
            if wrap {
                container.widthTracksTextView = true
                container.size = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
                container.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
                textView.isHorizontallyResizable = false
                textView.autoresizingMask = [.width]
            } else {
                container.widthTracksTextView = false
                let infinite = CGFloat.greatestFiniteMagnitude
                container.size = NSSize(width: infinite, height: infinite)
                container.containerSize = NSSize(width: infinite, height: infinite)
                textView.isHorizontallyResizable = true
                textView.autoresizingMask = []
            }
            textView.isVerticallyResizable = true
            textView.needsLayout = true
            textView.layoutManager?.ensureLayout(for: container)
            textView.sizeToFit()
            textView.scrollToVisible(NSRect(x: 0, y: 0, width: 1, height: 1))
        }

        // MARK: 搜索

        func runSearch(fromStart: Bool) {
            guard let textView, let model else { return }
            let storage = textView.textStorage
            let content = storage?.string ?? ""
            let query = model.query

            // 清除旧高亮
            if matches.count > 0, let storage {
                for range in matches {
                    storage.removeAttribute(.backgroundColor, range: range)
                    storage.removeAttribute(.foregroundColor, range: range)
                }
            }
            matches = []
            model.matchIndex = 0

            if !query.isEmpty {
                let nsContent = content as NSString
                var searchRange = NSRange(location: 0, length: nsContent.length)
                while searchRange.length > 0, matches.count < 2000 {
                    let found = nsContent.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange)
                    guard found.location != NSNotFound else { break }
                    matches.append(found)
                    if let storage {
                        storage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.45), range: found)
                    }
                    let next = found.location + max(found.length, 1)
                    searchRange = NSRange(location: next, length: nsContent.length - next)
                }
            }
            model.reportSearch(count: matches.count, index: 0)
            if !matches.isEmpty, fromStart {
                highlightCurrent()
                scrollToMatch(0)
                model.matchIndex = 0
                model.reportSearch(count: matches.count, index: 0)
            }
        }

        func gotoMatch(direction: Int) {
            guard let model, !matches.isEmpty else { return }
            var index = model.matchIndex + direction
            if index >= matches.count { index = 0 }
            if index < 0 { index = matches.count - 1 }
            model.matchIndex = index
            highlightCurrent()
            scrollToMatch(index)
            model.reportSearch(count: matches.count, index: index)
        }

        private func highlightCurrent() {
            guard let textView, let model, let storage = textView.textStorage else { return }
            guard model.matchIndex >= 0, model.matchIndex < matches.count else { return }
            // 全部恢复普通黄色，当前项强调为橙色
            for range in matches {
                storage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.45), range: range)
            }
            let current = matches[model.matchIndex]
            storage.addAttribute(.backgroundColor, value: NSColor.systemOrange.withAlphaComponent(0.85), range: current)
        }

        private func scrollToMatch(_ index: Int) {
            guard let textView, index < matches.count else { return }
            textView.scrollRangeToVisible(matches[index])
        }
    }
}
