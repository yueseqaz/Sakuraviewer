import Foundation
import CoreFoundation

/// 文本编码自动检测结果。
public struct TextEncodingInfo: Equatable, Sendable {
    public let encoding: String.Encoding
    /// 展示名，如 "UTF-8"、"GB18030"、"UTF-16LE"。
    public let displayName: String

    public init(encoding: String.Encoding, displayName: String) {
        self.encoding = encoding
        self.displayName = displayName
    }

    public static let utf8 = TextEncodingInfo(encoding: .utf8, displayName: "UTF-8")
}

/// 纯文本编码探测：BOM → UTF-8 严格校验 → UTF-16 启发式 → GB18030 → Latin-1 兜底。
public enum TextEncodingDetector {

    /// GB18030 编码（通过 CFStringEncodings 桥接）。
    public static let gb18030: String.Encoding = {
        let cfEnc = CFStringEncodings.GB_18030_2000.rawValue
        let nsEnc = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cfEnc))
        return String.Encoding(rawValue: nsEnc)
    }()

    public static func detect(in data: Data) -> TextEncodingInfo {
        guard !data.isEmpty else { return .utf8 }

        // 1. BOM 检测
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { return .utf8 }
        if data.starts(with: [0xFF, 0xFE]) {
            return TextEncodingInfo(encoding: .utf16LittleEndian, displayName: "UTF-16LE")
        }
        if data.starts(with: [0xFE, 0xFF]) {
            return TextEncodingInfo(encoding: .utf16BigEndian, displayName: "UTF-16BE")
        }

        let sample = data.prefix(1 << 20) // 最多检查 1MB

        // 2. UTF-8 严格校验（合法即采纳；ASCII 天然通过）
        if let _ = String(data: sample, encoding: .utf8) {
            // 注意：对整份文件 UTF-8 严格校验失败的会在解码层回退
            return .utf8
        }

        // 3. UTF-16 无 BOM 启发式：统计 NUL 字节分布
        let bytes = [UInt8](sample.prefix(4096))
        if bytes.count >= 4 {
            var evenZeros = 0, oddZeros = 0
            for (i, b) in bytes.enumerated() where b == 0 {
                if i.isMultiple(of: 2) { evenZeros += 1 } else { oddZeros += 1 }
            }
            let threshold = bytes.count / 8
            if oddZeros > threshold && evenZeros <= threshold {
                return TextEncodingInfo(encoding: .utf16LittleEndian, displayName: "UTF-16LE")
            }
            if evenZeros > threshold && oddZeros <= threshold {
                return TextEncodingInfo(encoding: .utf16BigEndian, displayName: "UTF-16BE")
            }
        }

        // 4. GB18030 严格解码（中文环境常见兜底）
        if let _ = String(data: sample, encoding: gb18030) {
            return TextEncodingInfo(encoding: gb18030, displayName: "GB18030")
        }

        // 5. Latin-1 兜底：任意字节序列均可解码，绝不失败
        return TextEncodingInfo(encoding: .isoLatin1, displayName: "Latin-1")
    }

    /// 用探测到的编码解码整份数据；主编码失败时逐级回退，保证不抛错、不崩溃。
    public static func decode(_ data: Data) -> (text: String, info: TextEncodingInfo) {
        guard !data.isEmpty else { return ("", .utf8) }

        let preferred = detect(in: data)
        if let raw = String(data: data, encoding: preferred.encoding) {
            return (stripBOM(raw), preferred)
        }
        // 回退链：UTF-8 → GB18030 → UTF-16 → Latin-1（永不失败）
        let fallbacks: [(String.Encoding, String)] = [
            (.utf8, "UTF-8"),
            (gb18030, "GB18030"),
            (.utf16LittleEndian, "UTF-16LE"),
            (.utf16BigEndian, "UTF-16BE"),
            (.isoLatin1, "Latin-1"),
        ]
        for (enc, name) in fallbacks {
            if let raw = String(data: data, encoding: enc) {
                return (stripBOM(raw), TextEncodingInfo(encoding: enc, displayName: name))
            }
        }
        // 最终兜底：带替换符解码，界面提示编码异常
        let text = stripBOM(String(decoding: data, as: UTF8.self))
        return (text, TextEncodingInfo(encoding: .utf8, displayName: "UTF-8（有损）"))
    }

    /// 去除解码结果中的 BOM 字符。
    private static func stripBOM(_ text: String) -> String {
        text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
    }
}
