import SwiftUI

/// 设置窗口：外观、查看、媒体、通用。
struct SettingsView: View {

    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TabView {
            appearanceTab
                .tabItem { Label("外观", systemImage: "paintpalette") }

            viewerTab
                .tabItem { Label("查看", systemImage: "eye") }

            mediaTab
                .tabItem { Label("媒体", systemImage: "play.circle") }

            generalTab
                .tabItem { Label("通用", systemImage: "gearshape") }
        }
        .frame(width: 460, height: 260)
        .onAppear {
            settings.applyAppearance()
        }
    }

    // MARK: 外观

    private var appearanceTab: some View {
        Form {
            Picker("主题", selection: $settings.appearance) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .accessibilityLabel("主题模式")

            Text("主题立即生效；跟随系统时随 macOS 外观自动切换。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
    }

    // MARK: 查看

    private var viewerTab: some View {
        Form {
            Picker("默认缩放", selection: $settings.zoomPreference) {
                ForEach(ZoomPreference.allCases) { pref in
                    Text(pref.displayName).tag(pref)
                }
            }
            .pickerStyle(.segmented)

            Stepper(value: $settings.codeFontSize, in: 9...32) {
                HStack {
                    Text("代码 / 文本字号")
                    Spacer()
                    Text("\(settings.codeFontSize) pt")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, design: .monospaced))
                }
            }
            .accessibilityLabel("代码字号")

            Toggle("显示行号", isOn: $settings.showLineNumbers)

            Text("新打开的图片与 PDF 会使用上面的默认缩放。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
    }

    // MARK: 媒体

    private var mediaTab: some View {
        Form {
            Toggle("打开媒体后自动播放", isOn: $settings.autoplayMedia)

            Text("自动播放仅对视频与音频生效；播放列表会在曲目结束后自动切换。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
    }

    // MARK: 通用

    private var generalTab: some View {
        Form {
            Stepper(value: $settings.maxRecentFiles, in: 3...50) {
                HStack {
                    Text("最近文件数量")
                    Spacer()
                    Text("\(settings.maxRecentFiles)")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, design: .monospaced))
                }
            }
            .accessibilityLabel("最近文件数量")

            Toggle("启动时恢复上次会话", isOn: $settings.restoreSession)

            Text("会话包含打开的标签页与选中的标签。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
    }
}
