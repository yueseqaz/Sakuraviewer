import AppKit

/// 行号标尺：跟随可见区域绘制行号，自动换行时正确跳过续行。
final class LineNumberRulerView: NSRulerView {

    weak var sourceTextView: NSTextView?
    /// charIndex -> lineNumber 缓存锚点。
    private var lineCache: [Int: Int] = [0: 1]
    /// 全文行数缓存（以字符串长度为失效键）。
    private var totalCache: (length: Int, count: Int)?

    func invalidateCaches() {
        lineCache = [0: 1]
        totalCache = nil
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
        var lineNumber = lineNumber(forCharacterIndex: firstCharIndex, in: content)

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
        let totalLines = totalLineNumber(in: content)
        let desiredWidth = 24 + CGFloat(String(totalLines).count) * 8
        if abs(ruleThickness - desiredWidth) > 2 {
            ruleThickness = desiredWidth
        }
    }

    /// 计算字符索引所在行号（1-based），带增量缓存。
    private func lineNumber(forCharacterIndex index: Int, in content: NSString) -> Int {
        if let cached = lineCache[index] { return cached }
        // 找到最近的缓存锚点
        let anchors = lineCache.keys.filter { $0 <= index }
        let anchor = anchors.max() ?? 0
        var count = lineCache[anchor] ?? 1
        var position = anchor
        let searchLength = min(index, content.length) - position
        if searchLength > 0 {
            var searchRange = NSRange(location: position, length: searchLength)
            while position < index {
                let newlineRange = content.range(of: "\n", options: [], range: searchRange)
                guard newlineRange.location != NSNotFound, newlineRange.location < index else { break }
                count += 1
                position = newlineRange.location + 1
                searchRange = NSRange(location: position, length: index - position)
            }
        }
        // 控制缓存规模
        if lineCache.count > 512 {
            lineCache.removeAll(keepingCapacity: true)
            lineCache[0] = 1
        }
        lineCache[index] = count
        return count
    }

    /// 全文总行数（缓存）。
    private func totalLineNumber(in content: NSString) -> Int {
        if let totalCache, totalCache.length == content.length {
            return totalCache.count
        }
        var count = 1
        var searchRange = NSRange(location: 0, length: content.length)
        while true {
            let found = content.range(of: "\n", options: [], range: searchRange)
            guard found.location != NSNotFound else { break }
            count += 1
            let next = found.location + 1
            if next >= content.length { break }
            searchRange = NSRange(location: next, length: content.length - next)
        }
        totalCache = (content.length, count)
        return count
    }
}
