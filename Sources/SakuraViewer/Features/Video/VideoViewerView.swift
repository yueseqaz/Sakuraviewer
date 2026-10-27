import SwiftUI
import AVKit

/// AVPlayerView 封装。
struct VideoPlayerCanvas: NSViewRepresentable {

    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        view.showsFrameSteppingButtons = true
        view.allowsPictureInPicturePlayback = false
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player {
            view.player = player
        }
    }
}

/// 视频查看器。
struct VideoViewerView: View {

    @EnvironmentObject private var services: AppServices
    @ObservedObject var tab: TabDocument
    let isActive: Bool

    @StateObject private var controller: MediaPlayerController
    @State private var showPlaylist = false

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

    @ViewBuilder
    private var content: some View {
        if let error = controller.loadError {
            ErrorStateView(
                title: "无法播放视频",
                message: "\(tab.currentURL.lastPathComponent)：\(error)",
                retryAction: { controller.loadPlaylist(for: tab.currentURL) }
            )
        } else {
            ZStack(alignment: .topTrailing) {
                VideoPlayerCanvas(player: controller.player)
                    .background(Color.black)
                    .accessibilityLabel("视频播放器：\(tab.title)")

                if showPlaylist, !controller.tracks.isEmpty {
                    PlaylistPanelView(controller: controller)
                        .frame(width: 260, height: 320)
                        .padding(12)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.18), value: showPlaylist)
        }
    }

    // MARK: 工具栏

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isActive {
            ToolbarItemGroup(placement: .primaryAction) {
                IconButton(systemName: "backward.end.fill", size: 26, iconSize: 11) { controller.previous() }
                    .help("上一首")
                    .accessibilityLabel("上一首")
                    .disabled(!controller.canGoPrev)

                IconButton(systemName: controller.isPlaying ? "pause.fill" : "play.fill", size: 26, iconSize: 12) {
                    controller.togglePlay()
                }
                .help("播放/暂停（空格）")
                .accessibilityLabel("播放或暂停")

                IconButton(systemName: "forward.end.fill", size: 26, iconSize: 11) { controller.next() }
                    .help("下一首")
                    .accessibilityLabel("下一首")
                    .disabled(!controller.canGoNext)

                Divider()

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

/// 播放列表浮层（视频/音频共用）。
struct PlaylistPanelView: View {

    @ObservedObject var controller: MediaPlayerController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("播放列表 · \(controller.tracks.count) 项")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(10)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(controller.tracks.enumerated()), id: \.element.id) { index, track in
                            HStack(spacing: 8) {
                                if index == controller.currentIndex {
                                    Image(systemName: controller.isPlaying ? "waveform" : "speaker.wave.1.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(SakuraTheme.accent)
                                } else {
                                    Text("\(index + 1)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 18)
                                }
                                Text(track.title)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(index == controller.currentIndex ? SakuraTheme.accentSoft : Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                controller.load(trackIndex: index)
                            }
                            .id(index)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("播放列表第\(index + 1)项：\(track.title)")
                            .accessibilityAddTraits(index == controller.currentIndex ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onAppear {
                    proxy.scrollTo(controller.currentIndex, anchor: .center)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: SakuraTheme.cornerRadius)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SakuraTheme.cornerRadius)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
