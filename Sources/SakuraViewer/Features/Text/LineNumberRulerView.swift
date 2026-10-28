import AppKit

/// 行号标尺：跟随可见区域绘制行号，自动换行时正确跳过续行。
final class LineNumberRulerView: NSRulerView {

    weak var sourceTextView: NSTextView?
    /// 每一行的起始字符位置，滚动时用二分查找而不是从上一个锚点线性扫描。
    private var lineStarts: [Int] = [0]
    private var lineStartsLength = -1
    private var scrollObserver: NSObjectProtocol?

    func invalidateCaches() {
        lineStarts = [0]
        lineStartsLength = -1
    }

    init(textView: NSTextView) {
        self.sourceTextView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 40
    }

    func observeScrollView(_ scrollView: NSScrollView) {
        guard scrollObserver == nil else { return }
        let clipView = scrollView.contentView
        if clipView.postsBoundsChangedNotifications == false {
            clipView.postsBoundsChangedNotifications = true
        }
        scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            // NSRulerView 不总会因反向滚动自动失效，主动重绘可见行号。
            self?.setNeedsDisplay(self?.visibleRect ?? .zero)
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let scrollObserver {
            NotificationCenter.default.removeObserver(scrollObserver)
        }
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = sourceTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        let content = textView.string as NSString
        guard content.length > 0 else { return }

        let visibleRect = textView.visibleRect
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)

        // 首个可见字符所在的行号
        let firstCharIndex = layoutManager.characterRange(
            forGlyphRange: NSRange(location: visibleGlyphRange.location, length: 0),
            actualGlyphRange: nil
        ).location
        prepareLineStarts(in: content)
        var lineNumber = lineNumber(forCharacterIndex: firstCharIndex)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphRange) { fragmentRect, _, _, fragmentGlyphRange, _ in
            let fragmentCharRange = layoutManager.characterRange(forGlyphRange: fragmentGlyphRange, actualGlyphRange: nil)

            // 只为段落首行绘制（换行续行不加行号）
            let isParagraphStart = fragmentCharRange.location == 0
                || content.character(at: fragmentCharRange.location - 1) == 0x0A

            if isParagraphStart {
                let y = textView.textContainerInset.height + fragmentRect.minY - visibleRect.minY
                let label = String(lineNumber)
                let size = (label as NSString).size(withAttributes: attributes)
                let drawRect = NSRect(
                    x: self.ruleThickness - size.width - 8,
                    y: y + (fragmentRect.height - size.height) / 2,
                    width: size.width,
                    height: size.height
                )
                (label as NSString).draw(in: drawRect, withAttributes: attributes)
                lineNumber += 1
            }
        }

        // 标尺厚度随总行数自适应
        let totalLines = totalLineNumber()
        let desiredWidth = 24 + CGFloat(String(totalLines).count) * 8
        if abs(ruleThickness - desiredWidth) > 2 {
            ruleThickness = desiredWidth
        }
    }

    private func prepareLineStarts(in content: NSString) {
        guard lineStartsLength != content.length else { return }
        lineStarts = [0]
        lineStarts.reserveCapacity(min(content.length / 24 + 1, 1_000_000))
        var index = 0
        while index < content.length {
            if content.character(at: index) == 0x0A {
                lineStarts.append(index + 1)
            }
            index += 1
        }
        lineStartsLength = content.length
    }

    /// 计算字符索引所在行号（1-based）。
    private func lineNumber(forCharacterIndex index: Int) -> Int {
        let target = max(0, index)
        var lower = 0
        var upper = lineStarts.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if lineStarts[middle] <= target { lower = middle + 1 }
            else { upper = middle }
        }
        return max(1, lower)
    }

    private func totalLineNumber() -> Int {
        lineStarts.count
    }
}
