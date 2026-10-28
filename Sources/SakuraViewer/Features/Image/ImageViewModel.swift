import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers
import SakuraViewerCore

/// 图片缩放模式。
enum ImageZoomMode: Equatable {
    case fit
    case actual
    case custom
}

/// 图片查看器模型：加载、缩放、旋转、同类切换。
@MainActor
final class ImageViewModel: ObservableObject {

    @Published var image: NSImage?
    @Published var zoom: Double = 1
    @Published var mode: ImageZoomMode = .fit
    @Published var rotation: Double = 0 // 度数，顺时针
    @Published var pixelSize: CGSize = .zero
    @Published var formatName: String = ""
    @Published var isAnimated = false
    @Published var loadingError: String?
    @Published var siblings: [URL] = []
    @Published var siblingIndex: Int = -1
    /// 由画布回报的适应窗口比例（用于状态栏显示）。
    @Published var fitScale: Double = 1
    /// 文件元信息（信息面板用）。
    @Published var fileSize: Int = 0
    @Published var modifiedDate: Date?

    let tab: TabDocument
    private var loadedRotation: Double = -1
    private var loadedSource: NSImage?

    init(tab: TabDocument, preference: ZoomPreference) {
        self.tab = tab
        self.mode = preference == .actual ? .actual : .fit
    }

    // MARK: 加载

    func load() {
        tab.status = .loading
        let url = tab.currentURL
        Task.detached(priority: .userInitiated) { [weak self] in
            let result = Self.loadImage(at: url)
            await MainActor.run { [weak self] in
                guard let self, self.tab.currentURL == url else { return }
                switch result {
                case .failure(let failure):
                    self.loadingError = failure.message
                    self.tab.status = .failed(failure.message)
                case .success(let payload):
                    self.loadingError = nil
                    self.loadedSource = payload.image
                    self.loadedRotation = -1
                    self.image = payload.image
                    self.pixelSize = payload.pixelSize
                    self.formatName = payload.formatName
                    self.isAnimated = payload.isAnimated
                    self.rotation = 0
                    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                    self.fileSize = (attrs?[.size] as? NSNumber)?.intValue ?? 0
                    self.modifiedDate = attrs?[.modificationDate] as? Date
                    self.loadSiblings(around: url)
                    self.tab.status = .ready
                    self.updateStatus()
                }
            }
        }
    }

    struct ImageLoadFailure: Error {
        let message: String
    }

    nonisolated private static func loadImage(at url: URL) -> Result<(image: NSImage, pixelSize: CGSize, formatName: String, isAnimated: Bool), ImageLoadFailure> {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(ImageLoadFailure(message: "文件不存在或已被移动"))
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return .failure(ImageLoadFailure(message: "无法读取图像数据"))
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: true] as CFDictionary) else {
            return .failure(ImageLoadFailure(message: "图像数据损坏或格式不受支持"))
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let pixelWidth = (properties[kCGImagePropertyPixelWidth] as? Int) ?? cgImage.width
        let pixelHeight = (properties[kCGImagePropertyPixelHeight] as? Int) ?? cgImage.height

        // 格式名
        var formatName = "图片"
        if let utType = CGImageSourceGetType(source) as String? {
            formatName = (UTType(utType)?.preferredFilenameExtension?.uppercased()) ?? utType.uppercased()
        }

        // 动图帧数
        var isAnimated = false
        if CGImageSourceGetCount(source) > 1 {
            if let container = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
               let frames = container[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                isAnimated = (frames[kCGImagePropertyGIFLoopCount] as? Int) != nil || CGImageSourceGetCount(source) > 1
            } else {
                isAnimated = true
            }
        }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: pixelWidth, height: pixelHeight))
        return .success((nsImage, CGSize(width: pixelWidth, height: pixelHeight), formatName, isAnimated))
    }

    private func loadSiblings(around url: URL) {
        let directory = url.deletingLastPathComponent()
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
        siblings = contents
            .filter { FileKind.detect(url: $0) == .image }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        siblingIndex = siblings.firstIndex(of: url) ?? -1
    }

    // MARK: 缩放

    var effectiveZoom: Double {
        mode == .fit ? fitScale : zoom
    }

    func zoomIn() {
        setCustomZoom(effectiveZoom * 1.25)
    }

    func zoomOut() {
        setCustomZoom(effectiveZoom / 1.25)
    }

    func setCustomZoom(_ value: Double) {
        zoom = min(max(value, 0.02), 40)
        mode = .custom
        updateStatus()
    }

    func fitToWindow() {
        mode = .fit
        updateStatus()
    }

    func actualSize() {
        mode = .actual
        zoom = 1
        updateStatus()
    }

    func rotate() {
        rotation = (rotation + 90).truncatingRemainder(dividingBy: 360)
        updateStatus()
    }

    // MARK: 同类切换

    var canGoNext: Bool { siblingIndex >= 0 && siblingIndex < siblings.count - 1 }
    var canGoPrev: Bool { siblingIndex > 0 }

    func goNext() {
        guard canGoNext else { return }
        switchTo(siblings[siblingIndex + 1])
    }

    func goPrevious() {
        guard canGoPrev else { return }
        switchTo(siblings[siblingIndex - 1])
    }

    private func switchTo(_ url: URL) {
        tab.currentURL = url
        siblingIndex = siblings.firstIndex(of: url) ?? -1
        load()
    }

    func updateStatus() {
        let sizeText = "\(Int(pixelSize.width)) × \(Int(pixelSize.height))"
        let rotationText = rotation == 0 ? "" : " · 旋转 \(Int(rotation))°"
        let position = siblings.isEmpty ? "" : " · \(siblingIndex + 1)/\(siblings.count)"
        tab.statusDetail = "\(sizeText) · \(Int((effectiveZoom * 100).rounded()))% · \(formatName)\(rotationText)\(position)"
    }

    /// 旋转后的展示图（GIF 动图仅在 0° 时保持动画）。
    var displayImage: NSImage? {
        if rotation == 0 { return image }
        return image
    }

    func rotatedImageIfNeeded() -> NSImage? {
        guard rotation != 0 else { return loadedSource }
        guard let source = loadedSource, let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return loadedSource }
        guard let rotated = Self.rotatedCGImage(cgImage, degrees: rotation) else { return loadedSource }
        // 交换宽高
        let swap = rotation.truncatingRemainder(dividingBy: 180) != 0
        let w = swap ? pixelSize.height : pixelSize.width
        let h = swap ? pixelSize.width : pixelSize.height
        return NSImage(cgImage: rotated, size: NSSize(width: w, height: h))
    }

    nonisolated static func rotatedCGImage(_ image: CGImage, degrees: Double) -> CGImage? {
        let radians = degrees * .pi / 180
        let swap = degrees.truncatingRemainder(dividingBy: 180) != 0
        let width = swap ? image.height : image.width
        let height = swap ? image.width : image.height
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: image.bitsPerComponent, bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: image.bitmapInfo.rawValue
        ) else { return nil }
        context.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        context.rotate(by: CGFloat(radians))
        context.draw(image, in: CGRect(x: -CGFloat(image.width) / 2, y: -CGFloat(image.height) / 2, width: CGFloat(image.width), height: CGFloat(image.height)))
        return context.makeImage()
    }
}
