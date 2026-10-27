# 🌸 Sakura-Viewer

**原生 macOS 统一文件查看器** —— 一个窗口查看图片、视频、音频、PDF、代码、纯文本与 Markdown。

纯 Swift + SwiftUI/AppKit/AVKit/PDFKit/ImageIO 系统框架实现，**零第三方依赖**，不使用 Electron / Tauri / WebView，无需 Xcode GUI 即可命令行构建。

![CI](https://github.com/yueseqaz/Sakuraviewer/actions/workflows/ci.yml/badge.svg)

<!-- 截图占位：功能完善后补充
![主界面](docs/screenshots/main-window.png)
![图片查看](docs/screenshots/image-viewer.png)
![PDF 查看](docs/screenshots/pdf-viewer.png)
![音频播放](docs/screenshots/audio-player.png)
-->

## 功能

| 类型 | 格式 | 查看能力 |
|------|------|----------|
| 🖼 图片 | jpg / jpeg / png / gif / webp / heic / tiff / bmp / svg / ico / avif | 适应窗口、实际大小、缩放（触控板捏合 / ⌘±）、旋转 90°、同目录上一张/下一张、GIF 动画 |
| 🎬 视频 | mp4 / mov / m4v 等 AVFoundation 可播放格式 | 播放/暂停、进度、音量、循环、同目录播放列表、快进快退、原生 AVKit 控制 |
| 🎵 音频 | mp3 / m4a / aac / wav / flac / aiff / caf | 自定义原生播放界面、频谱律动、播放列表、循环 |
| 📄 PDF | pdf | 连续滚动、页码跳转、全文搜索（高亮定位）、缩略图侧栏、缩放 |
| 💻 代码 | swift / js / ts / py / java / c / cpp / h / go / rs / html / css / json / yaml / xml / sh / sql 等 60+ 扩展名 | 自研语法高亮（亮/暗双主题）、行号、自动换行开关、字号调整、查找替换定位 |
| 📝 文本 | txt / log / csv 等 | UTF-8 / UTF-16LE/BE / GB18030 / Latin-1 编码自动检测、行号、查找 |
| 📋 Markdown | md / markdown | 原生渲染标题/列表/表格/引用/任务列表/图片/链接，代码块语法高亮，目录侧栏锚点跳转 |
| ❓ 未知 | 其他 | 尽量按文本打开；二进制显示友好提示 + 头部十六进制预览，可一键尝试以文本打开 |

**通用能力**

- 单窗口统一体验：左侧边栏（最近文件 / 收藏 / 文件夹媒体库按类型分组 / 当前标签分组）、中部多标签、底部状态栏（类型 / 大小 / 编码 / 页码 / 时长 / 缩放）
- 多标签保活：切换标签不丢失播放进度与滚动位置
- 拖拽文件 / 文件夹到窗口打开；支持 Finder「打开方式」与 `open` 命令
- 启动恢复上次会话（标签与选中状态）
- 深色 / 浅色模式自动适配（也可在设置中固定）
- SF Symbols、毛玻璃材质、克制动效、统一间距与圆角
- 主要控件均带无障碍标签；空状态 / 加载状态 / 错误状态有明确引导
- 大文件保护（文本 32 MB 上限、超 2 MB 自动关闭高亮）、损坏文件 / 无权限文件友好提示，不崩溃

## 键盘快捷键

| 快捷键 | 功能 |
|--------|------|
| ⌘O | 打开文件 |
| ⌘⇧O | 打开文件夹（加入侧边栏媒体库） |
| ⌘W / ⌘⇧W | 关闭标签 / 关闭窗口 |
| ⌘⇧[ / ⌘⇧] | 上一个 / 下一个标签 |
| ⌘F | 查找（文本 / 代码 / PDF） |
| ⌘+ / ⌘- / ⌘0 / ⌘⇧0 | 放大 / 缩小 / 实际大小 / 适应窗口 |
| 空格 | 播放 / 暂停媒体 |
| ← / → | 图片上一张/下一张；媒体快退/快进 10 秒 |
| ⌘← / ⌘→ | 上一个 / 下一个（图片、媒体曲目） |
| ⌘R | 刷新当前文件 |
| ⌘⇧R | 旋转图片 |
| ⌘⇧L | 自动换行开关 |
| ⌘⇧T / ⌘⇧D | PDF 缩略图 / Markdown 目录 |
| ⌥⌘+ / ⌥⌘- | 增大 / 减小字号 |
| ⌘, | 设置 |

## 命令行构建 / 运行 / 打包 / 测试

无需 Xcode GUI。安装 [Command Line Tools](https://developer.apple.com/download/all/)（`xcode-select --install`）后即可：

```bash
git clone https://github.com/yueseqaz/Sakuraviewer.git
cd Sakuraviewer

./scripts/build.sh            # 编译（debug，默认）
./scripts/build.sh release    # 编译（release）
./scripts/run.sh              # 构建并启动 App
./scripts/test.sh             # 运行单元测试（135+ 项断言）
./scripts/package.sh          # 生成 dist/SakuraViewer.app + zip（ad-hoc 签名，可双击运行）

# 自定义包名（如需要 OmniViewer.app）：
APP_NAME=OmniViewer ./scripts/package.sh
```

> **仅 CLT 环境说明**：macOS 26+ SDK 的 SwiftUI 将 `@State` 等实现为外部宏，其宏插件（`libSwiftUIMacros.dylib`）只随完整 Xcode 提供。`scripts/build.sh` 会自动检测仅 CLT 环境并改用 CLT 自带的 macOS 15.x SDK 编译（部署目标仍为 macOS 13）。装有完整 Xcode 时（如 CI）直接使用默认 SDK。

## GitHub Actions

CI 在 `macos-15` runner 上自动执行：编译（release）→ 测试 → 打包 `.app` → 上传 artifact。

- 状态：见顶部 badge / [Actions 页面](https://github.com/yueseqaz/Sakuraviewer/actions)
- 下载 App：进入对应 run → Artifacts → `SakuraViewer-macOS`（内含 `SakuraViewer.app` 的 zip），解压双击运行（本机首次打开需右键 → 打开，绕过 Gatekeeper 提示）

## 项目结构

```
Sakuraviewer/
├── Package.swift               # SPM：SakuraViewerCore + SakuraViewer（可执行）+ SakuraViewerTests
├── Sources/
│   ├── SakuraViewerCore/       # 纯逻辑核心（可单测）
│   │   ├── FileKind.swift          # 文件类型识别（扩展名 + 内容嗅探）
│   │   ├── TextEncodingDetector.swift  # 编码检测：BOM → UTF-8 → UTF-16 → GB18030 → Latin-1
│   │   ├── TextFileLoader.swift    # 大文件保护的文本加载
│   │   ├── SyntaxHighlighter.swift # 自研轻量语法高亮（20 语言，亮/暗主题）
│   │   ├── MarkdownParser.swift    # Markdown 块级/行内解析器
│   │   ├── RecentFilesStore.swift / FavoritesStore.swift / SessionStore.swift
│   │   ├── MediaPlaylistBuilder.swift
│   │   └── Formatters.swift
│   └── SakuraViewer/           # 应用层
│       ├── App/                    # 入口、菜单命令、工作区模型、动作路由、设置
│       ├── Core/                   # （预留）
│       ├── UI/                     # 主窗口、侧边栏、标签栏、状态栏、状态视图、查找条
│       ├── Settings/               # 设置窗口
│       └── Features/
│           ├── Image/  Video/  Audio/  PDF/
│           ├── Text/   Code/   Markdown/  Unsupported/
│           └── Media/              # 视频/音频共享播放控制器
├── Tests/SakuraViewerTests/    # 零依赖测试执行器 + 10 套测试
├── scripts/                    # build / run / package / test / make_app / make_icon / make_samples
├── Packaging/                  # AppIcon.icns（图标生成脚本输出）
├── Samples/                    # 各类型样例文件（可用脚本重新生成）
└── .github/workflows/ci.yml    # GitHub Actions
```

## 设计决策与依赖说明

- **零第三方依赖**：全部能力由系统框架提供（SwiftUI、AppKit、AVKit/AVFoundation、PDFKit、ImageIO、CoreGraphics）。没有需要锁定版本的第三方 SPM 依赖，也就没有供应链风险与版本漂移。
- **Markdown 原生渲染**：自研解析器 + SwiftUI 原生视图渲染，未使用 WKWebView；链接只放行 http/https/mailto 协议并在系统浏览器打开，行内 HTML 原样展示为文本，不执行任何脚本。
- **语法高亮**：自研单遍扫描状态机（注释/字符串/数字/关键字/类型/函数启发式），为查看器场景设计，性能优先。
- **测试执行器**：纯 CLT 环境（无完整 Xcode）不提供 XCTest 框架与 swift-testing 宏插件，因此测试为自研零依赖执行器（`Tests/SakuraViewerTests/TestKit.swift`），本地与 CI 使用同一条命令 `./scripts/test.sh`。

## 已知限制

- 图片旋转 GIF 时取静帧（0° 时保持动画）；图片缩放基于 `NSScrollView` 捏合，不响应 ⌘+滚轮。
- 标签栏不支持拖拽排序与鼠标中键关闭；标签页数量大时全部保活会占用内存。
- Markdown 表格对齐解析有限（当前统一左对齐），不渲染行内 HTML 与数学公式；GFM 之外的扩展语法（脚注、脚手架等）不支持。
- PDF 搜索上限 500 条结果 / 1500 页；PDF 表单填写与注释不受支持（只读查看器）。
- 文本查看无编辑能力（定位为查看器）；自动换行下行号按段落编号（换行续行不重复编号）。
- 视频播放列表基于同目录同级文件自动构建，不支持手动排序。
- App 未启用 App Sandbox（保证拖拽与任意路径读取体验）；未公证，分发需本机 ad-hoc 签名（脚本已处理）。
- 图标由 `scripts/make_icon.swift` 程序化生成（仓库亦附成品 `Packaging/AppIcon.icns`），非设计师手绘。

## 命名说明

任务描述中仓库名存在 `Sakuraviewer` 与 `macos-omni-viewer` 两种表述，产品名有 `Sakura-Viewer` 与 `OmniViewer` 两种表述。按作者既有仓库命名习惯（`Sakura*` 系列）采用 **Sakuraviewer / Sakura-Viewer / SakuraViewer.app**；如需改名/改包名：

```bash
gh repo rename macos-omni-viewer        # 重命名仓库
APP_NAME=OmniViewer ./scripts/package.sh # 生成 OmniViewer.app
```

## License

[MIT](LICENSE)
