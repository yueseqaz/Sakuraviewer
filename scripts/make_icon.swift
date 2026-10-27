// scripts/make_icon.swift — 生成 Sakura-Viewer 应用图标
// 用法: swift scripts/make_icon.swift <输出 AppIcon.icns 路径>
// 纯 CoreGraphics 绘制：粉色渐变圆角方块 + 五瓣樱花（带花瓣缺口），导出各尺寸 PNG 后用 iconutil 合成。
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let output = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Packaging/AppIcon.icns"

let size = 1024.0

// MARK: - 绘制

func drawIcon(size: Double) -> CGImage? {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil, width: Int(size), height: Int(size),
        bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    let s = size / 1024.0 // 归一化缩放

    // 背板：macOS 风格圆角矩形（半径约 22.4%）
    let inset: CGFloat = 100 * s
    let bgRect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius: CGFloat = 185 * s
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // 底部阴影（仅落在透明画布上）
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14 * s), blur: 36 * s,
                  color: CGColor(srgbRed: 0.75, green: 0.2, blue: 0.45, alpha: 0.35))
    ctx.addPath(bgPath)
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // 主渐变：浅樱粉 → 深樱红
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let colors = [
        CGColor(srgbRed: 1.00, green: 0.62, blue: 0.78, alpha: 1),
        CGColor(srgbRed: 0.95, green: 0.42, blue: 0.65, alpha: 1),
        CGColor(srgbRed: 0.85, green: 0.25, blue: 0.52, alpha: 1),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size * 0.6, y: 0),
        options: []
    )

    // 顶部柔光
    let gloss = CGGradient(colorsSpace: colorSpace, colors: [
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.35),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        gloss,
        start: CGPoint(x: size / 2, y: size),
        end: CGPoint(x: size / 2, y: size * 0.45),
        options: []
    )
    ctx.restoreGState()

    // 五瓣樱花
    let flowerCenter = CGPoint(x: size / 2, y: size / 2)
    let petalRadius: CGFloat = 300 * s

    func petalPath(center: CGPoint, radius: CGFloat) -> CGPath {
        // 花瓣：泪滴形 + 顶端缺口（樱花特征）
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addCurve(
            to: CGPoint(x: 0, y: -radius),
            control1: CGPoint(x: radius * 0.62, y: -radius * 0.18),
            control2: CGPoint(x: radius * 0.50, y: -radius * 0.82)
        )
        // 顶端缺口
        path.addCurve(
            to: CGPoint(x: 0, y: -radius * 0.80),
            control1: CGPoint(x: radius * 0.10, y: -radius * 0.92),
            control2: CGPoint(x: radius * 0.10, y: -radius * 0.88)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: 0),
            control1: CGPoint(x: -radius * 0.10, y: -radius * 0.88),
            control2: CGPoint(x: -radius * 0.10, y: -radius * 0.92)
        )
        // 镜像左侧回到起点（用平移变换替代，路径以中轴对称绘制）
        return path
    }

    for i in 0..<5 {
        let angle = Double(i) * 72 * .pi / 180
        ctx.saveGState()
        ctx.translateBy(x: flowerCenter.x, y: flowerCenter.y)
        ctx.rotate(by: CGFloat(angle))

        // 右半瓣
        ctx.saveGState()
        ctx.setFillColor(CGColor(srgbRed: 1.0, green: 0.94, blue: 0.97, alpha: 0.97))
        ctx.addPath(petalPath(center: flowerCenter, radius: petalRadius))
        ctx.fillPath()
        ctx.restoreGState()

        // 左半瓣（镜像）
        ctx.saveGState()
        ctx.scaleBy(x: -1, y: 1)
        ctx.setFillColor(CGColor(srgbRed: 1.0, green: 0.94, blue: 0.97, alpha: 0.97))
        ctx.addPath(petalPath(center: flowerCenter, radius: petalRadius))
        ctx.fillPath()
        ctx.restoreGState()

        // 花瓣描边（淡粉）
        ctx.saveGState()
        ctx.setStrokeColor(CGColor(srgbRed: 0.92, green: 0.55, blue: 0.72, alpha: 0.8))
        ctx.setLineWidth(6 * s)
        ctx.addPath(petalPath(center: flowerCenter, radius: petalRadius))
        ctx.strokePath()
        ctx.scaleBy(x: -1, y: 1)
        ctx.addPath(petalPath(center: flowerCenter, radius: petalRadius))
        ctx.strokePath()
        ctx.restoreGState()

        ctx.restoreGState()
    }

    // 花蕊
    let centerCircle = CGRect(
        x: flowerCenter.x - 34 * s, y: flowerCenter.y - 34 * s,
        width: 68 * s, height: 68 * s
    )
    ctx.setFillColor(CGColor(srgbRed: 1.0, green: 0.85, blue: 0.35, alpha: 1))
    ctx.fillEllipse(in: centerCircle)

    // 雄蕊：五根短线 + 圆点
    for i in 0..<10 {
        let angle = Double(i) * 36 * .pi / 180 + 0.3
        let inner: CGFloat = 55 * s
        let outer: CGFloat = 105 * s
        let p1 = CGPoint(x: flowerCenter.x + cos(angle) * inner, y: flowerCenter.y + sin(angle) * inner)
        let p2 = CGPoint(x: flowerCenter.x + cos(angle) * outer, y: flowerCenter.y + sin(angle) * outer)
        ctx.setStrokeColor(CGColor(srgbRed: 1.0, green: 0.9, blue: 0.55, alpha: 0.95))
        ctx.setLineWidth(7 * s)
        ctx.move(to: p1)
        ctx.addLine(to: p2)
        ctx.strokePath()
        let dot = CGRect(x: p2.x - 9 * s, y: p2.y - 9 * s, width: 18 * s, height: 18 * s)
        ctx.setFillColor(CGColor(srgbRed: 1.0, green: 0.82, blue: 0.30, alpha: 1))
        ctx.fillEllipse(in: dot)
    }

    return ctx.makeImage()
}

// MARK: - 导出

func writePNG(_ image: CGImage, to url: URL) throws {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw NSError(domain: "icon", code: 1)
    }
}

let fm = FileManager.default
let workDir = fm.temporaryDirectory.appendingPathComponent("sakura-icon-\(UUID().uuidString)")
let iconset = workDir.appendingPathComponent("AppIcon.iconset")
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

guard let base = drawIcon(size: size) else {
    print("绘制失败"); exit(1)
}

let entries: [(Int, Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2),
    (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]
for (point, scale) in entries {
    let px = point * scale
    let scaled = px == 1024
        ? base
        : base.resized(to: px)
    guard let scaled else { print("缩放失败 \(px)"); exit(1) }
    let name = scale == 1 ? "icon_\(point)x\(point).png" : "icon_\(point)x\(point)@2x.png"
    try writePNG(scaled, to: iconset.appendingPathComponent(name))
}

// iconutil 合成 icns
let icnsURL = URL(fileURLWithPath: output).standardizedFileURL
try? fm.createDirectory(at: icnsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try? fm.removeItem(at: icnsURL)

let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconset.path, "-o", icnsURL.path]
try proc.run()
proc.waitUntilExit()

guard proc.terminationStatus == 0 else {
    print("iconutil 失败"); exit(1)
}

try? fm.removeItem(at: workDir)
print("✅ 图标已生成: \(icnsURL.path)")

extension CGImage {
    func resized(to pixels: Int) -> CGImage? {
        let aspect = Double(height) / Double(width)
        let width = pixels
        let height = Int((Double(pixels) * aspect).rounded())
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }
}
