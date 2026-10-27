import Foundation
import SwiftUI
import AppKit

/// 主题模式。
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// 图片/PDF 的默认缩放偏好。
enum ZoomPreference: String, CaseIterable, Identifiable {
    case fit, actual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fit: return "适应窗口"
        case .actual: return "实际大小"
        }
    }
}

/// 应用设置：UserDefaults 持久化。
@MainActor
final class AppSettings: ObservableObject {

    private let defaults: UserDefaults

    @Published var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance); applyAppearance() }
    }
    @Published var zoomPreference: ZoomPreference {
        didSet { defaults.set(zoomPreference.rawValue, forKey: Keys.zoom) }
    }
    @Published var codeFontSize: Int {
        didSet { defaults.set(codeFontSize, forKey: Keys.fontSize) }
    }
    @Published var autoplayMedia: Bool {
        didSet { defaults.set(autoplayMedia, forKey: Keys.autoplay) }
    }
    @Published var maxRecentFiles: Int {
        didSet {
            defaults.set(maxRecentFiles, forKey: Keys.maxRecents)
            onRecentLimitChange?(maxRecentFiles)
        }
    }
    @Published var restoreSession: Bool {
        didSet { defaults.set(restoreSession, forKey: Keys.restoreSession) }
    }
    @Published var showLineNumbers: Bool {
        didSet { defaults.set(showLineNumbers, forKey: Keys.lineNumbers) }
    }

    /// 最近文件上限变化时由服务层注入回调。
    var onRecentLimitChange: ((Int) -> Void)?

    enum Keys {
        static let appearance = "sakura.appearance"
        static let zoom = "sakura.zoom.preference"
        static let fontSize = "sakura.code.font.size"
        static let autoplay = "sakura.media.autoplay"
        static let maxRecents = "sakura.recent.limit"
        static let restoreSession = "sakura.session.restore"
        static let lineNumbers = "sakura.text.line.numbers"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = AppearanceMode(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        zoomPreference = ZoomPreference(rawValue: defaults.string(forKey: Keys.zoom) ?? "") ?? .fit
        let storedSize = defaults.integer(forKey: Keys.fontSize)
        codeFontSize = storedSize == 0 ? 13 : storedSize
        autoplayMedia = defaults.object(forKey: Keys.autoplay) as? Bool ?? true
        let storedLimit = defaults.integer(forKey: Keys.maxRecents)
        maxRecentFiles = storedLimit == 0 ? 10 : storedLimit
        restoreSession = defaults.object(forKey: Keys.restoreSession) as? Bool ?? true
        showLineNumbers = defaults.object(forKey: Keys.lineNumbers) as? Bool ?? true
    }

    func applyAppearance() {
        NSApp.appearance = appearance.nsAppearance
    }

    /// 代码/文本字号对应字体。
    var codeFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: CGFloat(codeFontSize), weight: .regular)
    }
}
