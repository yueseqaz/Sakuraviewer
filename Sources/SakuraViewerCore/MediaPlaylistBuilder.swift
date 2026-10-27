import Foundation

/// 播放列表条目。
public struct MediaTrack: Identifiable, Equatable {
    public let id: URL
    public let url: URL
    public let title: String

    public init(url: URL, title: String? = nil) {
        self.url = url
        self.id = url
        self.title = title ?? url.deletingPathExtension().lastPathComponent
    }
}

/// 媒体播放列表构建：取同目录下同类型（视频 or 音频）文件，按名称排序。
public enum MediaPlaylistBuilder {

    public static let videoExtensions = FileKind.videoExtensions
    public static let audioExtensions = FileKind.audioExtensions

    /// 围绕 anchorURL 构建播放列表；返回列表与 anchor 的下标。
    public static func playlist(for anchorURL: URL) -> (tracks: [MediaTrack], index: Int) {
        let ext = anchorURL.pathExtension.lowercased()
        let isAudio = audioExtensions.contains(ext)
        let allowed = isAudio ? audioExtensions : videoExtensions

        let directory = anchorURL.deletingLastPathComponent()
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let tracks = contents
            .filter { allowed.contains($0.pathExtension.lowercased()) }
            .filter { url in
                (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { MediaTrack(url: $0) }

        guard !tracks.isEmpty else { return ([], 0) }
        let index = tracks.firstIndex { $0.url.standardizedFileURL == anchorURL.standardizedFileURL } ?? 0
        return (tracks, index)
    }
}
