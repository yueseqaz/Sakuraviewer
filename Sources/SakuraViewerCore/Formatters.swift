import Foundation

/// 展示格式化工具。
public enum SakuraFormatter {

    /// 文件大小人性化，如 "1.4 MB"、"328 KB"。
    public static func fileSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    /// 时长 mm:ss / h:mm:ss。
    public static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// 缩放百分比，如 "128%"。
    public static func zoomPercent(_ scale: Double) -> String {
        let value = (scale * 100).rounded()
        let clipped = min(max(value, 1), 9999)
        return String(format: "%.0f%%", clipped)
    }

    /// 日期相对/短描述。
    public static func shortDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
