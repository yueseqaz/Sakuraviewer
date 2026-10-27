// scripts/make_samples.swift — 生成验收用样例文件（图片/视频/音频/PDF/文本/代码/Markdown）
// 用法: swift scripts/make_samples.swift [输出目录，默认 Samples]
import Foundation
import AppKit
import AVFoundation
import CoreText
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

let outputDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Samples").standardizedFileURL
let fm = FileManager.default
try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

// MARK: - 图片绘制

func drawSampleImage(size: CGSize, frame: Int = 0) -> CGImage? {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil, width: Int(size.width), height: Int(size.height),
        bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let w = size.width, h = size.height

    // 渐变背景（每帧旋转色相营造动画）
    let t = Double(frame) / 10
    let colors = [
        CGColor(srgbRed: 1.0, green: 0.68 - t * 0.2, blue: 0.80, alpha: 1),
        CGColor(srgbRed: 0.65 + t * 0.15, green: 0.78, blue: 0.95, alpha: 1),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: w, y: h), options: [])

    // 樱花花瓣：五瓣环绕，随帧旋转
    let center = CGPoint(x: w / 2, y: h / 2)
    for i in 0..<5 {
        let angle = Double(i) * 72 * .pi / 180 + t * .pi * 2
        let petalRect = CGRect(x: -60, y: -140, width: 120, height: 150)
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: CGFloat(angle))
        ctx.translateBy(x: 0, y: -110)
        let path = CGPath(roundedRect: petalRect, cornerWidth: 58, cornerHeight: 58, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(CGColor(srgbRed: 1, green: 0.92, blue: 0.96, alpha: 0.92))
        ctx.fillPath()
        ctx.setStrokeColor(CGColor(srgbRed: 0.9, green: 0.5, blue: 0.68, alpha: 0.9))
        ctx.setLineWidth(4)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // 花蕊
    ctx.setFillColor(CGColor(srgbRed: 1, green: 0.85, blue: 0.35, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: center.x - 26, y: center.y - 26, width: 52, height: 52))

    // 标注文字
    let text = NSAttributedString(string: "Sakura Sample", attributes: [
        .font: NSFont.systemFont(ofSize: 30, weight: .bold),
        .foregroundColor: NSColor(srgbRed: 0.55, green: 0.1, blue: 0.3, alpha: 1),
    ])
    let nsctx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsctx
    text.draw(at: CGPoint(x: 30, y: 26))
    NSGraphicsContext.restoreGraphicsState()

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("PNG 写入失败") }
}

// 1) photo.png
let baseImage = drawSampleImage(size: CGSize(width: 900, height: 600))!
writePNG(baseImage, to: outputDir.appendingPathComponent("photo.png"))
print("✓ photo.png")

// 2) photo.jpg / photo.heic / photo.tiff —— sips 转换
for (format, name) in [("jpeg", "photo.jpg"), ("heic", "photo.heic"), ("tiff", "photo.tiff")] {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    proc.arguments = ["-s", "format", format, outputDir.appendingPathComponent("photo.png").path, "--out", outputDir.appendingPathComponent(name).path]
    try proc.run(); proc.waitUntilExit()
    guard proc.terminationStatus == 0 else { fatalError("sips 转换 \(name) 失败") }
    print("✓ \(name)")
}

// 3) animation.gif —— 10 帧旋转动画
do {
    let dest = CGImageDestinationCreateWithURL(
        outputDir.appendingPathComponent("animation.gif") as CFURL,
        UTType.gif.identifier as CFString, 10, nil
    )!
    let gifProps: CFDictionary = [
        kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: 0.08,
        ]
    ] as CFDictionary
    for frame in 0..<10 {
        guard let img = drawSampleImage(size: CGSize(width: 400, height: 400), frame: frame) else { continue }
        CGImageDestinationAddImage(dest, img, gifProps)
    }
    guard CGImageDestinationFinalize(dest) else { fatalError("GIF 写入失败") }
    print("✓ animation.gif")
}

// MARK: - PDF（3 页）

do {
    let url = outputDir.appendingPathComponent("sample.pdf")
    var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
    guard let pdfCtx = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
        fatalError("PDF 上下文创建失败")
    }
    let pageTitles = [
        ("Sakura-Viewer 示例 PDF", "第 1 页 · 这是 PDFKit 连续滚动查看的第一页。"),
        ("支持缩放与搜索", "第 2 页 · 在工具栏搜索「樱」试试查找功能。樱花🌸"),
        ("缩略图侧栏", "第 3 页 · 点击工具栏的缩略图按钮查看页面缩略图。"),
    ]
    for (index, (title, body)) in pageTitles.enumerated() {
        pdfCtx.beginPDFPage(nil)
        let nsctx = NSGraphicsContext(cgContext: pdfCtx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsctx

        NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 30, weight: .bold),
            .foregroundColor: NSColor.black,
        ]).draw(at: CGPoint(x: 72, y: mediaBox.height - 140))

        NSAttributedString(string: body, attributes: [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor.darkGray,
        ]).draw(at: CGPoint(x: 72, y: mediaBox.height - 190))

        // 装饰花瓣
        for i in 0..<8 {
            let angle = Double(i) / 8 * .pi * 2 + Double(index)
            let cx = mediaBox.width / 2 + cos(angle) * 130
            let cy = 380 + sin(angle) * 130
            let rect = CGRect(x: cx - 22, y: cy - 22, width: 44, height: 44)
            pdfCtx.setFillColor(CGColor(srgbRed: 0.96, green: 0.62, blue: 0.78, alpha: 0.7))
            pdfCtx.fillEllipse(in: rect)
        }

        NSAttributedString(string: "Sakura-Viewer · macOS 原生统一文件查看器 · 第 \(index + 1)/3 页", attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.gray,
        ]).draw(at: CGPoint(x: 72, y: 48))

        NSGraphicsContext.restoreGraphicsState()
        pdfCtx.endPDFPage()
    }
    pdfCtx.closePDF()
    print("✓ sample.pdf")
}

// MARK: - 视频 clip.mov（H.264，3 秒动画）

do {
    let url = outputDir.appendingPathComponent("clip.mov")
    try? fm.removeItem(at: url)
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let size = CGSize(width: 640, height: 360)
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: size.width,
        AVVideoHeightKey: size.height,
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
        ]
    )
    writer.add(input)
    guard writer.startWriting() else { fatalError("AVAssetWriter 启动失败: \(String(describing: writer.error))") }
    writer.startSession(atSourceTime: .zero)

    var pixelBuffer: CVPixelBuffer?
    let attrs = adaptor.sourcePixelBufferAttributes as? [String: Any]
    CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attrs as CFDictionary?, &pixelBuffer)

    let fps = 30, totalFrames = 90
    for frame in 0..<totalFrames {
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.02) }
        guard let buffer = pixelBuffer else { fatalError("CVPixelBuffer 创建失败") }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            let ctx = CGContext(
                data: base, width: Int(size.width), height: Int(size.height),
                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            )!
            let t = Double(frame) / Double(totalFrames)
            let colors = [
                CGColor(srgbRed: 0.98, green: 0.55 - t * 0.2, blue: 0.72, alpha: 1),
                CGColor(srgbRed: 0.35 + t * 0.2, green: 0.55, blue: 0.95, alpha: 1),
            ] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors, locations: [0, 1])!
            ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            let cx = CGFloat(t) * (size.width - 140) + 70
            ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9))
            ctx.fillEllipse(in: CGRect(x: cx - 60, y: size.height / 2 - 60, width: 120, height: 120))
            ctx.setFillColor(CGColor(srgbRed: 0.9, green: 0.3, blue: 0.55, alpha: 1))
            ctx.fillEllipse(in: CGRect(x: cx - 34, y: size.height / 2 - 34, width: 68, height: 68))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps))
        while !adaptor.append(buffer, withPresentationTime: time) {
            Thread.sleep(forTimeInterval: 0.01)
            if writer.status == .failed { fatalError("帧写入失败: \(String(describing: writer.error))") }
        }
    }
    input.markAsFinished()
    let sem = DispatchSemaphore(value: 0)
    writer.finishWriting { sem.signal() }
    sem.wait()
    guard writer.status == .completed else { fatalError("视频收尾失败: \(String(describing: writer.error))") }
    print("✓ clip.mov")
}

// MARK: - 音频 melody.wav（正弦和弦）+ melody.m4a

do {
    let sampleRate = 44100.0
    let duration = 3.0
    let frames = Int(sampleRate * duration)
    let url = outputDir.appendingPathComponent("melody.wav")

    var samples = [Double](repeating: 0, count: frames)
    // 和弦：C 大三度（523.25 / 659.25 / 783.99 Hz）+ 简单包络
    let freqs = [523.25, 659.25, 783.99]
    for f in 0..<frames {
        let t = Double(f) / sampleRate
        let envelope = min(t / 0.3, 1.0) * max(0, 1 - t / duration) * 0.9
        var value = 0.0
        for (i, freq) in freqs.enumerated() {
            value += sin(2 * .pi * freq * t) * (i == 0 ? 0.5 : 0.3) * (0.7 + 0.3 * sin(2 * .pi * 2 * t))
        }
        samples[f] = value * envelope
    }

    var data = Data()
    func append<T>(_ value: T) { withUnsafeBytes(of: value) { data.append(contentsOf: $0) } }
    data.append("RIFF".data(using: .ascii)!)
    append(UInt32(36 + frames * 2))
    data.append("WAVE".data(using: .ascii)!)
    data.append("fmt ".data(using: .ascii)!)
    append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
    append(UInt32(sampleRate)); append(UInt32(sampleRate * 2))
    append(UInt16(2)); append(UInt16(16))
    data.append("data".data(using: .ascii)!)
    append(UInt32(frames * 2))
    for f in 0..<frames {
        let clamped = max(-1, min(1, samples[f]))
        append(Int16(clamped * 32767))
    }
    try data.write(to: url)
    print("✓ melody.wav")

    // m4a 转码
    let m4aURL = outputDir.appendingPathComponent("melody.m4a")
    try? fm.removeItem(at: m4aURL)
    let asset = AVURLAsset(url: url)
    guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
        fatalError("导出会话创建失败")
    }
    session.outputURL = m4aURL
    session.outputFileType = .m4a
    let sem = DispatchSemaphore(value: 0)
    session.exportAsynchronously { sem.signal() }
    sem.wait()
    guard session.status == .completed else { fatalError("m4a 导出失败: \(String(describing: session.error))") }
    print("✓ melody.m4a")
}

// MARK: - 文本类样例

let gb18030Encoding = String.Encoding(
    rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
)

func write(_ name: String, _ content: String, encoding: String.Encoding = .utf8) throws {
    try content.data(using: encoding)!.write(to: outputDir.appendingPathComponent(name))
    print("✓ \(name)")
}

try write("notes.txt", """
Sakura-Viewer 说明
==================

这是一个纯文本样例文件，用于验证 TXT 查看器。

特性验证点：
1. 行号显示
2. 编码自动检测（本文件为 UTF-8）
3. 查找功能（试试查找「樱花」）

春日散步
去年今日此门中，人面樱花相映红。
代码千行如落英，一窗阅尽四时风。
""")

try write("gb18030.txt", """
这是一个 GB18030 编码的文件。
Sakura-Viewer 应能自动检测编码并正确显示中文。
如果看到这行字是正常中文，说明编码检测工作正常。
""", encoding: gb18030Encoding)

try write("hello.swift", """
// hello.swift — Swift 语法高亮样例
import Foundation

struct SakuraPetal {
    let angle: Double
    let color: String

    func describe() -> String {
        return "花瓣角度 \\(angle)°，颜色 \\(color)"
    }
}

let petals = (0..<5).map { SakuraPetal(angle: Double($0) * 72, color: "樱粉") }
for petal in petals {
    print(petal.describe()) // 打印每一片花瓣
}

/* 块注释：
   Sakura-Viewer 使用自研轻量高亮器 */
""")

try write("demo.py", """
#!/usr/bin/env python3
# demo.py — Python 语法高亮样例
import math


class SakuraTree:
    \"\"\"樱花树：简单的递归分形。\"\"\"

    def __init__(self, depth=5):
        self.depth = depth

    def branches(self, n=1):
        if n > self.depth:
            return []
        return [(n, math.pi * n / 8)] + self.branches(n + 1)


if __name__ == "__main__":
    tree = SakuraTree(depth=4)
    for depth, angle in tree.branches():
        print(f"层 {depth}: 偏转角 {math.degrees(angle):.1f}°")
""")

try write("style.css", """
/* style.css — CSS 语法高亮样例 */
:root {
    --sakura-pink: #e6538f;
    --petal-white: #fff0f5;
}

.sakura-card {
    display: flex;
    align-items: center;
    padding: 16px 24px;
    border-radius: 12px;
    background: linear-gradient(135deg, var(--petal-white), white);
    box-shadow: 0 4px 16px rgba(230, 83, 143, 0.18);
}

.sakura-card:hover {
    transform: translateY(-2px);
    transition: all 0.2s ease-in-out;
}

@media (prefers-color-scheme: dark) {
    .sakura-card {
        background: #2a1a22;
    }
}
""")

try write("data.json", """
{
  "name": "Sakura-Viewer",
  "version": "0.1.0",
  "supported": ["image", "video", "audio", "pdf", "code", "text", "markdown"],
  "native": true,
  "dependencies": [],
  "metadata": {
    "petals": 5,
    "bloom": "spring",
    "colors": {
      "primary": "#E6538F",
      "soft": "#FFF0F5"
    }
  }
}
""")

try write("config.yaml", """
# config.yaml — YAML 语法高亮样例
app:
  name: Sakura-Viewer
  version: 0.1.0
  appearance: system

viewer:
  default_zoom: fit
  line_numbers: true
  wrap: true
  fonts:
    code: "SF Mono"
    size: 13

media:
  autoplay: true
  loop: false
  playlist: sibling

recent_files_limit: 10
""")

try write("index.html", """
<!DOCTYPE html>
<!-- index.html — HTML 语法高亮样例 -->
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>Sakura-Viewer</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <header class="sakura-card">
        <h1>樱花查看器</h1>
        <p>统一查看图片、视频、PDF 与代码</p>
    </header>
    <script>
        console.log("petals:", 5);
    </script>
</body>
</html>
""")

try write("README.md", """
# Sakura-Viewer 示例文档

这是一份 **Markdown 样例**，覆盖常用语法。标题会出现在右侧目录中。

## 文本样式

普通文字，**粗体**，*斜体*，~~删除线~~，`行内代码`，[链接](https://developer.apple.com)。
自动链接：<https://developer.apple.com>

## 列表

无序列表：

- 图片：jpg / png / gif / webp / heic
- 视频：mp4 / mov / m4v
- 音频：mp3 / m4a / wav / flac

有序列表：

1. 打开文件（⌘O）
2. 多标签浏览
3. 恢复上次会话

任务列表：

- [x] 原生 SwiftUI 界面
- [x] 零第三方依赖
- [ ] 更多格式

## 代码块

Swift 示例（带语法高亮）：

```swift
let petals = (0..<5).map { "🌸" }
print(petals.joined())
```

Python 示例：

```python
def bloom():
    return "樱花开了"
```

## 表格

| 格式 | 查看器 | 特色 |
|:-----|:------|:-----|
| 图片 | ImageIO | 缩放/旋转/切换 |
| PDF  | PDFKit | 连续滚动/搜索 |
| 音频 | AVFoundation | 播放列表 |

## 引用

> 原生、优雅、精美。
> —— Sakura-Viewer 设计目标

## 图片

![样例图片](photo.png)

---

结尾分隔线。
""")
print("🎉 全部样例生成完成 → \\(outputDir.path)")
