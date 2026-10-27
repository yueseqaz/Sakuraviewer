import SwiftUI
import AppKit
import SakuraViewerCore

/// Markdown 行内节点 → AttributedString（链接走系统外部打开，保证安全）。
enum MarkdownInlineRenderer {

    static func attributed(_ nodes: [MarkdownInline], baseURL: URL?) -> AttributedString {
        var result = AttributedString()
        for node in nodes {
            result.append(render(node, baseURL: baseURL))
        }
        return result
    }

    private static func render(_ node: MarkdownInline, baseURL: URL?) -> AttributedString {
        switch node {
        case .text(let text):
            return AttributedString(text)

        case .literal(let text):
            var attr = AttributedString(text)
            attr.foregroundColor = Color.secondary
            return attr

        case .code(let code):
            var attr = AttributedString(code)
            attr.font = .system(size: 13, weight: .regular, design: .monospaced)
            attr.foregroundColor = Color(nsColor: NSColor(srgbRed: 0.78, green: 0.27, blue: 0.5, alpha: 1))
            attr.backgroundColor = Color(nsColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.35))
            return attr

        case .bold(let children):
            var attr = attributed(children, baseURL: baseURL)
            attr.inlinePresentationIntent = merge(attr.inlinePresentationIntent, .stronglyEmphasized)
            return attr

        case .italic(let children):
            var attr = attributed(children, baseURL: baseURL)
            attr.inlinePresentationIntent = merge(attr.inlinePresentationIntent, .emphasized)
            return attr

        case .boldItalic(let children):
            var attr = attributed(children, baseURL: baseURL)
            attr.inlinePresentationIntent = merge(attr.inlinePresentationIntent, [.stronglyEmphasized, .emphasized])
            return attr

        case .strikethrough(let children):
            var attr = attributed(children, baseURL: baseURL)
            attr.strikethroughStyle = .single
            return attr

        case .link(let children, let url):
            let displayText = children.isEmpty ? url : children.map(MarkdownParser.inlineText).joined()
            var attr = AttributedString(displayText)
            attr.foregroundColor = SakuraTheme.accent
            attr.underlineStyle = .single
            if let safeURL = safeURL(for: url) {
                attr.link = safeURL
            }
            return attr

        case .image(let alt, let url):
            // 行内图片降级为占位（独立图片段落由块级渲染处理）
            var attr = AttributedString("🖼 \(alt.isEmpty ? url : alt)")
            attr.foregroundColor = Color.secondary
            return attr
        }
    }

    private static func merge(_ base: InlinePresentationIntent?, _ addition: InlinePresentationIntent) -> InlinePresentationIntent {
        if let base {
            return base.union(addition)
        }
        return addition
    }

    /// 安全链接：仅放行 http/https/mailto，其它 scheme 原样展示不可点击。
    static func safeURL(for raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            return nil
        }
        return ["http", "https", "mailto"].contains(scheme) ? url : nil
    }
}

// MARK: - 块级视图

struct MarkdownBlockView: View {

    let block: MarkdownBlock
    let baseURL: URL?

    /// 段落仅由一张图片构成时解析其 URL（相对路径基于 Markdown 文件所在目录）。
    private func imageOnlyURL(in inline: [MarkdownInline]) -> URL? {
        let meaningful = inline.filter {
            if case .text(let t) = $0 { return !t.trimmingCharacters(in: .whitespaces).isEmpty }
            return true
        }
        guard meaningful.count == 1, let node = meaningful.first,
              case .image(_, let rawURL) = node else { return nil }
        let trimmed = rawURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return ["http", "https", "file"].contains(url.scheme!.lowercased()) ? url : nil
        }
        // 相对路径
        guard let base = baseURL else { return nil }
        return URL(fileURLWithPath: trimmed, relativeTo: base)
    }

    var body: some View {
        switch block {
        case .heading(let level, let inline):
            headingView(level: level, inline: inline)

        case .paragraph(let inline):
            if let imageURL = imageOnlyURL(in: inline) {
                MarkdownRemoteImage(url: imageURL)
            } else {
                Text(MarkdownInlineRenderer.attributed(inline, baseURL: baseURL))
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .lineSpacing(5)
                    .textSelection(.enabled)
            }

        case .codeBlock(let language, let code):
            CodeBlockView(language: language, code: code)

        case .quote(let children):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(SakuraTheme.accent.opacity(0.6))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                        MarkdownBlockView(block: child, baseURL: baseURL)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: SakuraTheme.smallCornerRadius)
                    .fill(Color.primary.opacity(0.04))
            )

        case .list(let ordered, _, let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        if let taskDone = item.taskDone {
                            Image(systemName: taskDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 13))
                                .foregroundColor(taskDone ? SakuraTheme.accent : .secondary)
                        } else if ordered {
                            Text("\(index + 1).")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(SakuraTheme.accent)
                        } else {
                            Circle()
                                .fill(SakuraTheme.accent.opacity(0.75))
                                .frame(width: 5, height: 5)
                                .padding(.top, 7)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(item.blocks.enumerated()), id: \.offset) { _, child in
                                MarkdownBlockView(block: child, baseURL: baseURL)
                            }
                        }
                    }
                }
            }
            .padding(.leading, 4)

        case .table(let table):
            MarkdownTableView(table: table, baseURL: baseURL)

        case .divider:
            Divider()
                .padding(.vertical, 4)

        case .html(let source):
            Text(source)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .background(
                    RoundedRectangle(cornerRadius: SakuraTheme.smallCornerRadius)
                        .fill(Color.primary.opacity(0.04))
                )
        }
    }

    @ViewBuilder
    private func headingView(level: Int, inline: [MarkdownInline]) -> some View {
        let plain = inline.map(MarkdownParser.inlineText).joined()
        let anchor = MarkdownParser.headingAnchor(level: level, text: plain)
        let content = MarkdownInlineRenderer.attributed(inline, baseURL: baseURL)

        Group {
            switch level {
            case 1:
                VStack(alignment: .leading, spacing: 8) {
                    Text(content).font(.system(size: 26, weight: .bold))
                    Divider()
                }
            case 2:
                Text(content).font(.system(size: 21, weight: .bold))
            case 3:
                Text(content).font(.system(size: 17.5, weight: .semibold))
            case 4:
                Text(content).font(.system(size: 15.5, weight: .semibold))
            default:
                Text(content).font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
            }
        }
        .padding(.top, level <= 2 ? 12 : 8)
        .padding(.bottom, 2)
        .id(anchor)
        .accessibilityLabel("标题 H\(level)：\(plain)")
    }
}

// MARK: - 代码块

/// 代码块：语法高亮 + 横向滚动 + 一键复制。
struct CodeBlockView: View {

    let language: String?
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text((language?.isEmpty == false ? language! : "code").lowercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                IconButton(systemName: "doc.on.doc", size: 20, iconSize: 9, tint: .secondary) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                }
                .help("复制代码")
                .accessibilityLabel("复制代码")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ScrollView(.horizontal, showsIndicators: true) {
                Text(highlighted)
                    .font(.system(size: 12.5, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: SakuraTheme.cornerRadius)
                .fill(Color(nsColor: NSColor.textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SakuraTheme.cornerRadius)
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
        )
    }

    private var highlighted: AttributedString {
        let lang = CodeLanguage(fence: language)
        guard lang != .plain else {
            var plain = AttributedString(code)
            plain.foregroundColor = Color.primary
            return plain
        }
        let tokens = SyntaxHighlighter.tokenize(code, language: lang)
        var result = AttributedString(code)
        result.foregroundColor = Color.primary
        let theme = HighlightTheme.sakura
        for token in tokens {
            let nsRange = NSRange(token.range, in: code)
            if let range = Range(nsRange, in: result) {
                result[range].foregroundColor = Color(nsColor: theme.color(for: token.kind))
            }
        }
        return result
    }
}

// MARK: - 表格

struct MarkdownTableView: View {

    let table: MarkdownTable
    let baseURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(table.header.enumerated()), id: \.offset) { _, cell in
                    cellContent(cell)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .background(Color.primary.opacity(0.05))

            Divider()

            ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        cellContent(cell)
                            .font(.system(size: 13))
                    }
                }
                .background(rowIndex.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.025))
                Divider()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: SakuraTheme.smallCornerRadius)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: SakuraTheme.smallCornerRadius))
    }

    private func cellContent(_ cells: [MarkdownInline]) -> some View {
        Text(MarkdownInlineRenderer.attributed(cells, baseURL: baseURL))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 独立图片块

/// 仅含一张图片的段落渲染为大图。
struct MarkdownRemoteImage: View {

    let url: URL

    var body: some View {
        Group {
            if url.isFileURL {
                if let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    brokenImage(url.lastPathComponent)
                }
            } else {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit)
                    case .failure:
                        brokenImage(url.lastPathComponent)
                    default:
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.04))
                            ProgressView()
                        }
                        .frame(height: 160)
                    }
                }
            }
        }
        .frame(maxWidth: 640)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityLabel("图片：\(url.lastPathComponent)")
    }

    private func brokenImage(_ name: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "photo.badge.exclamationmark")
            Text("无法加载图片 \(name)")
                .font(.caption)
        }
        .foregroundColor(.secondary)
        .padding(12)
        .frame(maxWidth: 480)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
        )
    }
}
