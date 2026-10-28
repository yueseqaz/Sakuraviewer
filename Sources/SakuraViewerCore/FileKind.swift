import Foundation
import UniformTypeIdentifiers

/// 统一文件类型分类：决定打开文件时使用哪种查看器。
public enum FileKind: String, CaseIterable, Codable, Sendable {
    case image
    case video
    case audio
    case pdf
    case html
    case markdown
    case code
    case plainText
    case office
    case richText
    case ebook
    case archive
    case font
    case design
    case unsupported

    // MARK: - 扩展名表

    public static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "tiff", "tif",
        "bmp", "svg", "ico", "icns", "avif", "jp2", "dng", "cr2", "cr3", "nef", "arw", "orf", "rw2",
    ]

    public static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "webm", "mpg", "mpeg", "3gp",
    ]

    public static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "flac", "aiff", "aif", "caf", "ogg", "opus", "wma",
    ]

    public static let pdfExtensions: Set<String> = ["pdf"]

    public static let markdownExtensions: Set<String> = [
        "md", "markdown", "mdown", "mkd", "mdtxt", "mdx",
    ]

    public static let codeExtensions: Set<String> = [
        "swift", "js", "mjs", "cjs", "ts", "jsx", "tsx", "py", "pyw", "java",
        "c", "h", "cpp", "cc", "cxx", "hpp", "hh", "go", "rs",
        "css", "scss", "less", "json", "jsonc", "yaml", "yml", "xml", "plist",
        "sh", "bash", "zsh", "fish", "sql", "rb", "php", "kt", "kts", "toml",
        "ini", "lua", "pl", "pm", "r", "m", "mm", "cs", "dart", "scala",
        "clj", "ex", "exs", "hs", "erl", "proto", "gradle", "cmake", "dockerfile",
        "bat", "ps1", "vim", "zig", "v", "nim", "jl", "svelte", "vue", "graphql", "prisma",
        "drawio", "mmd", "mermaid",
    ]

    public static let textExtensions: Set<String> = [
        "txt", "text", "log", "csv", "tsv", "cfg", "conf", "properties", "env", "gitignore", "editorconfig",
        "srt", "ass", "ssa", "vtt", "lrc", "jsonl", "ndjson",
    ]

    /// 文档类格式交给系统默认应用打开（Word / Excel / PowerPoint 或兼容软件）。
    public static let officeExtensions: Set<String> = [
        "doc", "docx", "docm", "xls", "xlsx", "xlsm", "ppt", "pptx", "pptm",
        "odt", "ods", "odp", "pages", "numbers", "key",
    ]

    /// 富文本、电子书、压缩包和设计/字体文件交给 macOS Quick Look 预览。
    public static let richTextExtensions: Set<String> = ["rtf", "rtfd"]
    public static let ebookExtensions: Set<String> = ["epub"]
    public static let archiveExtensions: Set<String> = [
        "zip", "tar", "gz", "tgz", "bz2", "tbz", "xz", "txz", "7z", "rar", "cab", "iso",
    ]
    public static let fontExtensions: Set<String> = ["ttf", "otf", "woff", "woff2"]
    public static let designExtensions: Set<String> = ["psd", "ai", "sketch", "fig"]

    public static let htmlExtensions: Set<String> = ["html", "htm", "xhtml"]

    /// 无扩展名但应按文本/代码处理的常见文件名。
    public static let specialFileNames: Set<String> = [
        "makefile", "dockerfile", "license", "licence", "readme", "changelog",
        "authors", "contributors", "notice", "todo", "brewfile", "gemfile", "rakefile", "procfile",
    ]

    // MARK: - 识别

    /// 根据扩展名与（必要时）内容嗅探判断文件类型。
    /// - 未知扩展名时读取文件头部，判断更像文本还是二进制。
    public static func detect(url: URL, peekBytes: Int = 4096) -> FileKind {
        let ext = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent.lowercased()

        if specialFileNames.contains(fileName) {
            return ext.isEmpty ? .code : (detectByExtension(ext) ?? .code)
        }
        if let byExt = detectByExtension(ext) {
            return byExt
        }
        // 未知扩展名：嗅探内容
        return sniff(url: url, peekBytes: peekBytes)
    }

    static func detectByExtension(_ ext: String) -> FileKind? {
        if imageExtensions.contains(ext) { return .image }
        if videoExtensions.contains(ext) { return .video }
        if audioExtensions.contains(ext) { return .audio }
        if pdfExtensions.contains(ext) { return .pdf }
        if htmlExtensions.contains(ext) { return .html }
        if markdownExtensions.contains(ext) { return .markdown }
        if codeExtensions.contains(ext) { return .code }
        if textExtensions.contains(ext) { return .plainText }
        if officeExtensions.contains(ext) { return .office }
        if richTextExtensions.contains(ext) { return .richText }
        if ebookExtensions.contains(ext) { return .ebook }
        if archiveExtensions.contains(ext) { return .archive }
        if fontExtensions.contains(ext) { return .font }
        if designExtensions.contains(ext) { return .design }
        return nil
    }

    /// 快速取得文件树展示用类型，不读取未知文件内容，避免滚动文件树时卡顿。
    public static func displayKind(url: URL) -> FileKind {
        let ext = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent.lowercased()
        if specialFileNames.contains(fileName) { return ext.isEmpty ? .code : (detectByExtension(ext) ?? .code) }
        return detectByExtension(ext) ?? .unsupported
    }

    public static func isOfficeDocument(_ url: URL) -> Bool {
        officeExtensions.contains(url.pathExtension.lowercased())
    }

    /// 内容嗅探：读取头部字节。含 NUL 或大量不可打印字节视为二进制；空文件与可解码内容视为文本。
    static func sniff(url: URL, peekBytes: Int) -> FileKind {
        guard FileManager.default.fileExists(atPath: url.path) else { return .unsupported }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .unsupported }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: peekBytes), !data.isEmpty else {
            return .plainText // 空文件按文本打开
        }
        return looksLikeBinary(data) ? .unsupported : .plainText
    }

    public static func looksLikeBinary(_ data: Data) -> Bool {
        if data.contains(0x00) { return true }
        // 统计不可打印字节（排除常见控制符 \t \n \r）
        let sample = data.prefix(2048)
        let suspicious = sample.reduce(0) { count, byte in
            (byte < 0x09 || (byte > 0x0D && byte < 0x20 && byte != 0x1B)) ? count + 1 : count
        }
        return Double(suspicious) / Double(max(sample.count, 1)) > 0.10
    }

    // MARK: - 展示

    public var displayName: String {
        switch self {
        case .image: return "图片"
        case .video: return "视频"
        case .audio: return "音频"
        case .pdf: return "PDF"
        case .html: return "HTML"
        case .markdown: return "Markdown"
        case .code: return "代码"
        case .plainText: return "文本"
        case .office: return "Office"
        case .richText: return "富文本"
        case .ebook: return "电子书"
        case .archive: return "压缩包"
        case .font: return "字体"
        case .design: return "设计文件"
        case .unsupported: return "不支持"
        }
    }

    /// SF Symbols 图标名。
    public var symbolName: String {
        switch self {
        case .image: return "photo"
        case .video: return "video"
        case .audio: return "music.note"
        case .pdf: return "doc.richtext"
        case .html: return "globe"
        case .markdown: return "text.below.photo"
        case .code: return "curlybraces.square"
        case .plainText: return "doc.plaintext"
        case .office: return "doc.on.doc"
        case .richText: return "doc.richtext"
        case .ebook: return "book"
        case .archive: return "archivebox"
        case .font: return "textformat"
        case .design: return "scribble"
        case .unsupported: return "questionmark.square.dashed"
        }
    }

    /// 根据具体扩展名细分文档图标，避免 Word、表格和演示文稿看起来一样。
    public static func symbolName(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "xls", "xlsx", "xlsm", "ods", "numbers": return "tablecells"
        case "ppt", "pptx", "pptm", "odp", "key": return "rectangle.split.3x1"
        case "doc", "docx", "docm", "odt", "pages", "rtf", "rtfd": return "doc.richtext"
        case "csv", "tsv": return "tablecells"
        default: return displayKind(url: url).symbolName
        }
    }

    /// 是否属于可按文本处理的类别。
    public var isTextLike: Bool {
        self == .code || self == .plainText || self == .markdown
    }

    /// 是否为媒体（视频/音频），决定空格键行为。
    public var isMedia: Bool {
        self == .video || self == .audio
    }

    /// 对应的系统 UTType（用于打开面板过滤与 Info.plist 文档注册）。
    public var utTypes: [UTType] {
        switch self {
        case .image:
            return [.image, UTType("public.webp"), UTType("public.heic")].compactMap { $0 }
        case .video: return [.movie, .mpeg4Movie, UTType("com.apple.quicktime-movie")].compactMap { $0 }
        case .audio: return [.audio, .mp3, UTType("org.xiph.flac")].compactMap { $0 }
        case .pdf: return [.pdf]
        case .html: return [UTType.html, .text, .utf8PlainText].compactMap { $0 }
        case .markdown: return [UTType("net.daringfireball.markdown")].compactMap { $0 }
        case .code: return [.sourceCode, .json, .html, .xml, .yaml].compactMap { $0 }
        case .plainText: return [.text, .plainText, .utf8PlainText, .commaSeparatedText].compactMap { $0 }
        case .office: return [.data]
        case .richText: return [UTType.rtf, .data].compactMap { $0 }
        case .ebook, .archive, .font, .design:
            // Not every macOS SDK exposes a named UTType for these formats.
            // Filename-based types keep the open panel compatible across SDKs.
            let extensions: Set<String>
            switch self {
            case .ebook: extensions = Self.ebookExtensions
            case .archive: extensions = Self.archiveExtensions
            case .font: extensions = Self.fontExtensions
            case .design: extensions = Self.designExtensions
            default: extensions = []
            }
            return extensions.compactMap { UTType(filenameExtension: $0) } + [.data]
        case .unsupported: return [.data]
        }
    }

    /// 全部支持的 UTType 汇总（打开面板使用）。
    public static var allSupportedUTTypes: [UTType] {
        var types: [UTType] = []
        for kind in allCases where kind != .unsupported {
            types.append(contentsOf: kind.utTypes)
        }
        types.append(.data) // 未知类型也允许尝试打开（嗅探）
        return types
    }

    /// 判断某文件是否为「同类预览」可切换的邻居（上一张/下一张、播放列表）。
    public static func siblingFilter(for kind: FileKind) -> (URL) -> Bool {
        { url in detect(url: url) == kind }
    }
}
