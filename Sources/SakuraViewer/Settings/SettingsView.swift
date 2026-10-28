import SwiftUI

/// 设置窗口：外观、查看、媒体、通用。
/// 使用固定行布局（label 左对齐 + 控件右对齐），避免 Form 在 macOS 上的两列自适应排版问题。
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
        .frame(width: 520, height: 340)
        .onAppear {
            settings.applyAppearance()
        }
    }

    // MARK: 通用构件

    /// 设置行：左侧标签，右侧控件。
    private func settingRow<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13))
            Spacer(minLength: 0)
            control()
        }
        .padding(.vertical, 6)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.bottom, 2)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func content<Items: View>(@ViewBuilder _ items: () -> Items) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                items()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: 外观

    private var appearanceTab: some View {
        content {
            sectionTitle("主题模式")
            Picker("", selection: $settings.appearance) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("主题模式")

            hint("主题立即生效；「跟随系统」时随 macOS 外观自动切换浅色 / 深色。")

            Divider().padding(.vertical, 8)

            settingRow("界面语言") {
                Text("跟随系统（简体中文）")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: 查看

    private var viewerTab: some View {
        content {
            sectionTitle("图片与 PDF")
            settingRow("默认缩放") {
                Picker("", selection: $settings.zoomPreference) {
                    ForEach(ZoomPreference.allCases) { pref in
                        Text(pref.displayName).tag(pref)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                .labelsHidden()
                .accessibilityLabel("默认缩放")
            }
            hint("新打开的图片与 PDF 使用该缩放；切换标签不会改变已打开文件的状态。")

            Divider().padding(.vertical, 8)

            sectionTitle("文本与代码")
            settingRow("代码 / 文本字号") {
                Stepper {
                    Text("\(settings.codeFontSize) pt")
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minWidth: 44)
                } onIncrement: {
                    settings.codeFontSize = min(settings.codeFontSize + 1, 32)
                } onDecrement: {
                    settings.codeFontSize = max(settings.codeFontSize - 1, 9)
                }
                .frame(width: 160)
            }
            settingRow("显示行号") {
                Toggle("", isOn: $settings.showLineNumbers)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityLabel("显示行号")
            }
            hint("文本超过 2 MB 时自动关闭语法高亮；超过 32 MB 拒绝打开以保护性能。")
        }
    }

    // MARK: 媒体

    private var mediaTab: some View {
        content {
            sectionTitle("播放")
            settingRow("打开后自动播放") {
                Toggle("", isOn: $settings.autoplayMedia)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityLabel("自动播放")
            }
            hint("仅对视频与音频生效；播放列表会在曲目结束后自动切换下一首。")
        }
    }

    // MARK: 通用

    private var generalTab: some View {
        content {
            sectionTitle("会话与历史")
            settingRow("最近文件数量") {
                Stepper {
                    Text("\(settings.maxRecentFiles) 条")
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minWidth: 44)
                } onIncrement: {
                    settings.maxRecentFiles = min(settings.maxRecentFiles + 1, 50)
                } onDecrement: {
                    settings.maxRecentFiles = max(settings.maxRecentFiles - 1, 3)
                }
                .frame(width: 140)
            }
            settingRow("启动时恢复上次会话") {
                Toggle("", isOn: $settings.restoreSession)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityLabel("恢复上次会话")
            }
            hint("会话包含打开的标签页与选中的标签；关闭窗口时自动保存。")
        }
    }
}
