import SwiftUI

/// 空状态：未打开任何文件时的引导页。
struct EmptyStateView: View {

    @EnvironmentObject private var services: AppServices

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [SakuraTheme.accent.opacity(0.22), SakuraTheme.accent.opacity(0.08)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 108, height: 108)
                Image(systemName: "camera.aperture")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(SakuraTheme.accent)
            }
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Sakura Viewer")
                    .font(.system(size: 24, weight: .semibold))
                Text("一个原生、优雅的 macOS 统一文件查看器")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    if let urls = FilePicker.pickFiles() {
                        services.open(urls: urls)
                    }
                } label: {
                    Label("打开文件", systemImage: "doc")
                        .frame(minWidth: 110)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("o")
                .accessibilityLabel("打开文件")

                Button {
                    if let url = FilePicker.pickFolder() {
                        services.open(urls: [url])
                    }
                } label: {
                    Label("打开文件夹", systemImage: "folder")
                        .frame(minWidth: 110)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("打开文件夹")
            }

            VStack(spacing: 4) {
                Text("将文件拖入窗口即可打开 · 支持图片、视频、音频、PDF、代码、文本与 Markdown")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("⌘O 打开文件 · ⌘⇧O 打开文件夹 · 空格播放/暂停")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 加载状态。
struct LoadingStateView: View {
    var text = "加载中…"

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text(text)
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

/// 错误状态卡片。
struct ErrorStateView: View {
    let title: String
    let message: String
    var retryAction: (() -> Void)? = nil
    var extraActions: AnyView? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.orange)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                if let retryAction {
                    Button("重试", action: retryAction)
                        .buttonStyle(.borderedProminent)
                }
                if let extraActions {
                    extraActions
                }
            }
        }
        .padding(32)
        .frame(maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: SakuraTheme.cornerRadius)
                .fill(Color.primary.opacity(0.04))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 不支持的二进制文件：友好提示 + 头部十六进制预览。
struct UnsupportedStateView: View {
    let url: URL
    var hexPreview: String
    var openAsText: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "questionmark.square.dashed")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("暂不支持预览此文件")
                    .font(.headline)
                Text("\"\(url.lastPathComponent)\" 看起来是二进制文件，或使用了未注册的格式。")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !hexPreview.isEmpty {
                ScrollView([.horizontal, .vertical]) {
                    Text(hexPreview)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .padding(10)
                }
                .frame(width: 480, height: 120)
                .background(
                    RoundedRectangle(cornerRadius: SakuraTheme.smallCornerRadius)
                        .fill(Color.primary.opacity(0.04))
                )
                .accessibilityLabel("文件头部十六进制预览")
            }

            Button {
                openAsText()
            } label: {
                Label("尝试以文本方式打开", systemImage: "doc.plaintext")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("尝试以文本方式打开")
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
