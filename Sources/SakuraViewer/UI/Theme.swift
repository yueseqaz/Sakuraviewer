import SwiftUI
import SakuraViewerCore

/// Sakura 视觉主题：强调色、间距、圆角与通用控件样式。
enum SakuraTheme {

    /// 樱花主色。
    static let accent = Color(red: 0.906, green: 0.325, blue: 0.573)
    static let accentSoft = Color(red: 0.906, green: 0.325, blue: 0.573).opacity(0.14)

    static let cornerRadius: CGFloat = 10
    static let smallCornerRadius: CGFloat = 6
    static let padding: CGFloat = 14
    static let compactPadding: CGFloat = 8

    /// 按文件类型的图标配色（使用系统色，自动适配深浅模式）。
    static func kindColor(_ kind: FileKind) -> Color {
        switch kind {
        case .image: return .pink
        case .video: return .purple
        case .audio: return .blue
        case .pdf: return .red
        case .markdown: return .orange
        case .code: return .indigo
        case .plainText: return .gray
        case .unsupported: return .secondary
        }
    }
}

// MARK: - 图标按钮

/// 工具栏/内嵌图标按钮：悬停浅色圆底、克制动效。
struct IconButton: View {

    let systemName: String
    var size: CGFloat = 28
    var iconSize: CGFloat = 13
    var tint: Color = .primary
    var isActive = false
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(isActive ? SakuraTheme.accent : tint)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isActive ? SakuraTheme.accentSoft : Color.primary.opacity(hovered ? 0.08 : 0))
                )
                .scaleEffect(hovered ? 1.04 : 1)
                .animation(.easeOut(duration: 0.12), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            self.hovered = hovered
        }
    }
}

// MARK: - 文本 Chip

/// 小圆角标签（语言名、编码等）。
struct Chip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
            .foregroundColor(.secondary)
            .help(text)
    }
}

// MARK: - 侧边栏行

struct SidebarRowStyle: ViewModifier {
    @State private var hovered = false
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: SakuraTheme.smallCornerRadius)
                    .fill(isSelected ? SakuraTheme.accentSoft : Color.primary.opacity(hovered ? 0.05 : 0))
            )
            .contentShape(Rectangle())
            .onHover { hovered = $0 }
    }
}

extension View {
    func sidebarRowStyle(selected: Bool) -> some View {
        modifier(SidebarRowStyle(isSelected: selected))
    }
}
