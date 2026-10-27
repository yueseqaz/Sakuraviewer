import SwiftUI

/// 浮动查找条：用于文本/代码/PDF 搜索。
struct FindBarView: View {

    @Binding var query: String
    let matchCount: Int
    let matchIndex: Int // 0-based
    let onNext: () -> Void
    let onPrev: () -> Void
    let onClose: () -> Void
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            TextField("查找", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(width: 180)
                .focused($isFocused)
                .onSubmit { onNext() }
                .accessibilityLabel("查找内容")

            Text(matchText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(matchCount == 0 && !query.isEmpty ? .red : .secondary)
                .frame(minWidth: 56, alignment: .center)

            Divider().frame(height: 14)

            findButton("chevron.up", "上一个匹配（⇧⏎）", onPrev)
            findButton("chevron.down", "下一个匹配（⏎）", onNext)
            findButton("xmark", "关闭查找（Esc）", onClose)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: SakuraTheme.cornerRadius)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SakuraTheme.cornerRadius)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .padding(.top, 6)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var matchText: String {
        guard !query.isEmpty else { return "— / —" }
        if matchCount == 0 { return "无结果" }
        return "\(matchIndex + 1) / \(matchCount)"
    }

    private func findButton(_ system: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        IconButton(systemName: system, size: 22, iconSize: 10, tint: .secondary, action: action)
            .help(help)
            .accessibilityLabel(help)
    }
}
