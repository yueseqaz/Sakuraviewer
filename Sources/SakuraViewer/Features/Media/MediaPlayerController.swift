import Foundation
import AVFoundation
import Combine
import SakuraViewerCore

/// 视频/音频共享播放控制器。
@MainActor
final class MediaPlayerController: NSObject, ObservableObject {

    let player = AVPlayer()

    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Float = 1 {
        didSet { player.volume = volume }
    }
    @Published var isLooping = false
    @Published var tracks: [MediaTrack] = []
    @Published var currentIndex: Int = 0
    @Published var loadError: String?
    @Published var rate: Float = 1

    weak var tab: TabDocument?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var errorObservation: NSKeyValueObservation?
    private var autoplay: Bool

    init(tab: TabDocument, autoplay: Bool) {
        self.tab = tab
        self.autoplay = autoplay
        super.init()
        player.actionAtItemEnd = .pause

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds.isFinite ? time.seconds : 0
            if let item = self.player.currentItem, self.duration == 0, item.duration.isNumeric, item.duration.seconds.isFinite {
                self.duration = item.duration.seconds
            }
            self.updateStatus()
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handlePlaybackEnd()
            }
        }
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    // MARK: 加载

    /// 加载播放列表并定位到当前文件。
    func loadPlaylist(for url: URL) {
        let (playlist, index) = MediaPlaylistBuilder.playlist(for: url)
        tracks = playlist
        currentIndex = index
        if playlist.indices.contains(index) {
            load(trackIndex: index)
        } else {
            loadTrack(url: url)
        }
    }

    func load(trackIndex index: Int) {
        guard tracks.indices.contains(index) else { return }
        currentIndex = index
        loadTrack(url: tracks[index].url)
    }

    private func loadTrack(url: URL) {
        loadError = nil
        duration = 0
        currentTime = 0
        let item = AVPlayerItem(url: url)
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    if item.duration.isNumeric, item.duration.seconds.isFinite {
                        self.duration = item.duration.seconds
                    }
                    if self.autoplay {
                        self.player.play()
                    }
                case .failed:
                    self.loadError = item.error?.localizedDescription ?? "无法解码此媒体文件"
                    self.tab?.status = .failed(self.loadError ?? "解码失败")
                default:
                    break
                }
            }
        }
        player.replaceCurrentItem(with: item)
        updateStatus()
    }

    // MARK: 控制

    func togglePlay() {
        if player.timeControlStatus == .playing {
            pause()
        } else {
            play()
        }
    }

    func play() {
        if loadError != nil { return }
        player.play()
        player.rate = rate
    }

    func pause() {
        player.pause()
    }

    func seek(to seconds: Double) {
        let clamped = min(max(seconds, 0), max(duration, 0))
        player.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero, toleranceAfter: .zero
        )
        currentTime = clamped
    }

    func seek(by delta: Double) {
        seek(to: currentTime + delta)
    }

    func toggleLoop() {
        isLooping.toggle()
    }

    var canGoNext: Bool { currentIndex < tracks.count - 1 }
    var canGoPrev: Bool { currentIndex > 0 }

    func next() {
        guard canGoNext else { return }
        load(trackIndex: currentIndex + 1)
    }

    func previous() {
        // 播放中超过 3 秒先回起点
        if currentTime > 3 && tracks.isEmpty {
            seek(to: 0)
            return
        }
        guard canGoPrev else {
            seek(to: 0)
            return
        }
        load(trackIndex: currentIndex - 1)
    }

    var currentTrack: MediaTrack? {
        tracks.indices.contains(currentIndex) ? tracks[currentIndex] : nil
    }

    private func handlePlaybackEnd() {
        if isLooping {
            seek(to: 0)
            play()
            return
        }
        if canGoNext {
            next()
        } else {
            isPlaying = false
        }
    }

    func updateStatus() {
        guard let tab else { return }
        let position = SakuraFormatter.duration(currentTime)
        let total = duration > 0 ? SakuraFormatter.duration(duration) : "--:--"
        let playlistPart = tracks.count > 1 ? " · 曲目 \(currentIndex + 1)/\(tracks.count)" : ""
        let loopPart = isLooping ? " · 循环" : ""
        tab.statusDetail = "\(position) / \(total)\(playlistPart)\(loopPart)"
        if player.timeControlStatus == .playing {
            isPlaying = true
        } else if player.timeControlStatus == .paused {
            isPlaying = false
        }
    }
}
