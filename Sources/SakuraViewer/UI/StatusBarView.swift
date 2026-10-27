import SwiftUI

/// 底部状态栏：类型、大小、编码、页码/时长、缩放比例等。
struct StatusBarView: View {

    @EnvironmentObject private var workspace: WorkspaceModel

    var body: some View {
        HStack(spacing: 10) {
            if let tab = workspace.selectedTab {
                Image(systemName: tab.kind.symbolName)
                    .font(.system(size: 10))
                    .foregroundColor(SakuraTheme.kindColor(tab.kind))
                    .accessibilityHidden(true)

                Text(tab.kind.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                separator

                Text(tab.currentURL.lastPathComponent)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.secondary)
                    .help(tab.currentURL.path)

                if !tab.statusDetail.isEmpty {
                    separator
                    Text(tab.statusDetail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if case .loading = tab.status {
                    ProgressView()
                        .controlSize(.mini)
                }
            } else {
                Text("Sakura Viewer · 就绪")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, SakuraTheme.padding)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.03))
        .overlay(alignment: .top) { Divider() }
        .animation(.easeOut(duration: 0.15), value: workspace.selectedTab?.statusDetail)
    }

    private var separator: some View {
        Capsule()
            .fill(Color.primary.opacity(0.18))
            .frame(width: 1, height: 10)
    }
}
