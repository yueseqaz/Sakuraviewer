// swift-tools-version:5.9
// Sakura-Viewer — 原生 macOS 统一文件查看器
// 纯系统框架实现，零第三方依赖。
import PackageDescription

let package = Package(
    name: "SakuraViewer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SakuraViewer", targets: ["SakuraViewer"])
    ],
    targets: [
        // 纯逻辑核心：类型识别、编码检测、语法高亮、Markdown 解析、存储层。
        .target(
            name: "SakuraViewerCore",
            path: "Sources/SakuraViewerCore"
        ),
        // 应用层：AppKit/SwiftUI 界面与各格式查看器。
        .executableTarget(
            name: "SakuraViewer",
            dependencies: ["SakuraViewerCore"],
            path: "Sources/SakuraViewer"
        ),
        // 测试：自研零依赖测试执行器（纯 CLT 环境无 XCTest/swift-testing 宏支持）。
        // 运行方式：swift run SakuraViewerTests 或 ./scripts/test.sh
        .executableTarget(
            name: "SakuraViewerTests",
            dependencies: ["SakuraViewerCore"],
            path: "Tests/SakuraViewerTests"
        )
    ]
)
