import AppKit

/// 行号标尺：跟随可见区域绘制行号，自动换行时正确跳过续行。
final class LineNumberRulerView: NSRulerView {

    weak var sourceTextView: NSTextView?
    /// 每一行的起始字符位置，滚动时用二分查找而不是从上一个锚点线性扫描。
    private var lineStarts: [Int] = [0]
    private var lineStartsLength = -1

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

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        var glyphIndex = visibleGlyphRange.location
        let endGlyph = NSMaxRange(visibleGlyphRange)

        while glyphIndex < endGlyph {
            var fragmentGlyphRange = NSRange()
            layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &fragmentGlyphRange)
            let fragmentCharRange = layoutManager.characterRange(forGlyphRange: fragmentGlyphRange, actualGlyphRange: nil)

            // 只为段落首行绘制（换行续行不加行号）
            let isParagraphStart = fragmentCharRange.location == 0
                || content.character(at: fragmentCharRange.location - 1) == 0x0A

            if isParagraphStart {
                let fragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
                let y = textView.textContainerInset.height + fragmentRect.minY - visibleRect.minY
                let label = String(lineNumber)
                let size = (label as NSString).size(withAttributes: attributes)
                let drawRect = NSRect(
                    x: ruleThickness - size.width - 8,
                    y: y + (fragmentRect.height - size.height) / 2,
                    width: size.width,
                    height: size.height
                )
                (label as NSString).draw(in: drawRect, withAttributes: attributes)
                lineNumber += 1
            }
            glyphIndex = NSMaxRange(fragmentGlyphRange)
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
        var searchStart = 0
        while searchStart < content.length {
            let range = NSRange(location: searchStart, length: content.length - searchStart)
            let found = content.range(of: "\n", options: [], range: range)
            guard found.location != NSNotFound else { break }
            let next = found.location + 1
            if next <= content.length { lineStarts.append(next) }
            searchStart = next
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
