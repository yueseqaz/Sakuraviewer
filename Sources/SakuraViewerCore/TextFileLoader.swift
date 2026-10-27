import Foundation

/// 文本文件加载结果。
public struct TextLoadResult: Sendable {
    public let text: String
    public let encoding: TextEncodingInfo
    public let fileSize: Int
    /// 超过安全阈值被截断展示时为 true。
    public let truncated: Bool
    /// 截断提示说明。
    public let notice: String?
}

/// 文本加载器：带大文件保护，任何异常都以结果形式返回，不抛出崩溃。
public enum TextFileLoader {

    /// 超过该大小（字节）拒绝加载，给出友好提示。
    public static let hardLimit: Int = 32 * 1_048_576 // 32 MB
    /// 超过该大小加载但关闭高亮、提示性能降级。
    public static let highlightLimit: Int = 2 * 1_048_576 // 2 MB

    public enum LoadError: Error, Equatable {
        case fileNotFound
        case noPermission
        case tooLarge(size: Int)
        case readFailed(String)
    }

    /// 读取文本文件。
    /// - Parameter maxBytes: 允许读取的最大字节数（默认 hardLimit）。
    public static func load(url: URL, maxBytes: Int = TextFileLoader.hardLimit) -> Result<TextLoadResult, LoadError> {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return .failure(.fileNotFound)
        }
        if isDir.boolValue {
            return .failure(.readFailed("这是一个文件夹，请选择文件"))
        }
        guard fm.isReadableFile(atPath: url.path) else {
            return .failure(.noPermission)
        }

        let attrs = try? fm.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? NSNumber)?.intValue ?? url.fileSize
        if size > maxBytes {
            return .failure(.tooLarge(size: size))
        }

        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let (text, encoding) = TextEncodingDetector.decode(data)
            let truncatedNotice: String?
            if size > highlightLimit {
                truncatedNotice = "文件较大，已关闭语法高亮以保证流畅"
            } else {
                truncatedNotice = nil
            }
            return .success(TextLoadResult(
                text: text,
                encoding: encoding,
                fileSize: size,
                truncated: false,
                notice: truncatedNotice
            ))
        } catch {
            return .failure(.readFailed(error.localizedDescription))
        }
    }
}

extension URL {
    /// 文件大小（字节），读取失败返回 0。
    public var fileSize: Int {
        (try? resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
    }
}
