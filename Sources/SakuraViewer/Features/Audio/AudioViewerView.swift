import SwiftUI
import SakuraViewerCore

/// 音频查看器：原生自定义播放界面（封面占位、进度、音量、循环、播放列表）。
struct AudioViewerView: View {

    @EnvironmentObject private var services: AppServices
    @ObservedObject var tab: TabDocument
    let isActive: Bool

    @StateObject private var controller: MediaPlayerController
    @State private var showPlaylist = false
    @State private var isScrubbing = false

    init(tab: TabDocument, isActive: Bool) {
        self.tab = tab
        self.isActive = isActive
        _controller = StateObject(wrappedValue: MediaPlayerController(
            tab: tab,
            autoplay: AppServices.shared.settings.autoplayMedia
        ))
    }

    var body: some View {
        content
            .toolbar { toolbar }
            .onAppear {
                if controller.player.currentItem == nil {
                    controller.loadPlaylist(for: tab.currentURL)
                }
                registerRouter()
            }
            .onDisappear {
                services.router.unregister(tab.id)
            }
            .onChange(of: tab.reloadToken) { _ in
                controller.loadPlaylist(for: tab.currentURL)
            }
    }

    // MARK: 内容

    @ViewBuilder
    private var content: some View {
        if let error = controller.loadError {
            ErrorStateView(
                title: "无法播放音频",
                message: "\(tab.currentURL.lastPathComponent)：\(error)",
                retryAction: { controller.loadPlaylist(for: tab.currentURL) }
            )
        } else {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 26) {
                    Spacer()

                    artwork

                    VStack(spacing: 5) {
                        Text(controller.currentTrack?.title ?? tab.title)
                            .font(.system(size: 18, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(tab.currentURL.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    .padding(.horizontal, 40)

                    EqualizerBarsView(isPlaying: controller.isPlaying)
                        .frame(height: 22)

                    progressSection

                    transportControls

                    volumeSection

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)

                if showPlaylist, !controller.tracks.isEmpty {
                    PlaylistPanelView(controller: controller)
                        .frame(width: 260, height: 320)
                        .padding(12)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.18), value: showPlaylist)
            .background(
                LinearGradient(
                    colors: [SakuraTheme.accent.opacity(0.06), Color.clear],
                    startPoint: .top, endPoint: .center
                )
            )
            .accessibilityLabel("音频播放器：\(tab.title)")
        }
    }

    private var artwork: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [SakuraTheme.accent.opacity(0.25), SakuraTheme.accent.opacity(0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 150, height: 150)
            Image(systemName: "music.note")
                .font(.system(size: 52, weight: .light))
                .foregroundColor(SakuraTheme.accent)
                .scaleEffect(controller.isPlaying ? 1.03 : 1)
                .animation(.easeInOut(duration: 0.6), value: controller.isPlaying)
        }
        .shadow(color: SakuraTheme.accent.opacity(0.18), radius: 24, y: 8)
        .accessibilityHidden(true)
    }

    private var progressSection: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? controller.currentTime : min(controller.currentTime, max(controller.duration, 0.001)) },
                    set: { newValue in
                        isScrubbing = true
                        controller.currentTime = newValue
                    }
                ),
                in: 0...max(controller.duration, 0.001)
            ) { editing in
                if !editing {
                    controller.seek(to: controller.currentTime)
                    isScrubbing = false
                }
            }
            .frame(maxWidth: 460)
            .accessibilityLabel("播放进度")

            HStack {
                Text(SakuraFormatter.duration(controller.currentTime))
                Spacer()
                Text(SakuraFormatter.duration(controller.duration))
            }
            .font(.system(size: 10.5, design: .monospaced))
            .foregroundColor(.secondary)
            .frame(maxWidth: 460)
        }
        .padding(.horizontal, 40)
    }

    private var transportControls: some View {
        HStack(spacing: 26) {
            IconButton(systemName: "backward.end.fill", size: 38, iconSize: 15, tint: .primary) {
                controller.previous()
            }
            .help("上一首")
            .accessibilityLabel("上一首")
            .disabled(!controller.canGoPrev)

            Button {
                controller.togglePlay()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 62, weight: .ultraLight))
                    .foregroundColor(SakuraTheme.accent)
                    .scaleEffect(controller.isPlaying ? 1.0 : 0.98)
            }
            .buttonStyle(.plain)
            .help("播放/暂停（空格）")
            .accessibilityLabel("播放或暂停")

            IconButton(systemName: "forward.end.fill", size: 38, iconSize: 15, tint: .primary) {
                controller.next()
            }
            .help("下一首")
            .accessibilityLabel("下一首")
            .disabled(!controller.canGoNext)
        }
    }

    private var volumeSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.wave.1")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Slider(value: Binding(
                get: { Double(controller.volume) },
                set: { controller.volume = Float($0) }
            ), in: 0...1)
            .frame(width: 160)
            .accessibilityLabel("音量")
            Image(systemName: "speaker.wave.3")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: 工具栏

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isActive {
            ToolbarItemGroup(placement: .primaryAction) {
                IconButton(
                    systemName: controller.isLooping ? "repeat.1" : "repeat",
                    size: 26, iconSize: 12,
                    isActive: controller.isLooping
                ) {
                    controller.toggleLoop()
                }
                .help("循环播放")
                .accessibilityLabel("循环播放")

                IconButton(systemName: "list.bullet", size: 26, iconSize: 12, isActive: showPlaylist) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        showPlaylist.toggle()
                    }
                }
                .help("播放列表")
                .accessibilityLabel("播放列表")
                .disabled(controller.tracks.isEmpty)

                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { value in
                        Button(controller.rateLabel(for: Float(value))) {
                            controller.setRate(Float(value))
                        }
                        .disabled(Float(value) == controller.rate)
                    }
                } label: {
                    Text(controller.rateLabel)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .help("播放速度")
                .accessibilityLabel("播放速度")
            }
        }
    }

    private func registerRouter() {
        services.router.register(ViewerRegistration(
            tabId: tab.id,
            capabilities: [.media],
            perform: { action in
                switch action {
                case .togglePlay: controller.togglePlay()
                case .toggleLoop: controller.toggleLoop()
                case .seekBack: controller.seek(by: -10)
                case .seekForward: controller.seek(by: 10)
                case .nextItem: controller.next()
                case .prevItem: controller.previous()
                default: break
                }
            }
        ))
    }
}

/// 播放时轻微律动的频谱条动画。
struct EqualizerBarsView: View {
    let isPlaying: Bool

    private let barCount = 24

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: !isPlaying)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    let wave = isPlaying
                        ? (sin(phase * 2.4 + Double(index) * 0.7) * 0.5 + 0.5) * 0.7 + 0.15
                        : 0.08
                    Capsule()
                        .fill(SakuraTheme.accent.opacity(0.55))
                        .frame(width: 3, height: max(2, 22 * wave))
                        .animation(.easeInOut(duration: 0.12), value: wave)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
