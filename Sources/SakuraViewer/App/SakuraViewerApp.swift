import SwiftUI
import AppKit

@main
struct SakuraViewerApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Sakura Viewer", id: "main") {
            MainWindowView()
                .environmentObject(AppServices.shared)
                .environmentObject(AppServices.shared.workspace)
                .environmentObject(AppServices.shared.router)
                .environmentObject(AppServices.shared.settings)
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowResizability(.contentMinSize)
        .commands { SakuraCommands() }

        Settings {
            SettingsView()
                .environmentObject(AppServices.shared.settings)
                .environmentObject(AppServices.shared)
        }
    }
}

// MARK: - 菜单与快捷键

struct SakuraCommands: Commands {

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("打开文件…") {
                if let urls = FilePicker.pickFiles() {
                    AppServices.shared.open(urls: urls)
                }
            }
            .keyboardShortcut("o")
            .accessibilityLabel("打开文件")

            Button("打开文件夹…") {
                if let url = FilePicker.pickFolder() {
                    AppServices.shared.open(urls: [url])
                }
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .accessibilityLabel("打开文件夹")
        }

        CommandGroup(after: .newItem) {
            Divider()
            Button("刷新当前文件") {
                AppServices.shared.router.send(.refresh)
            }
            .keyboardShortcut("r")
            .accessibilityLabel("刷新")

            Button("在 Finder 中显示") {
                guard let url = AppServices.shared.workspace.selectedTab?.currentURL else { return }
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            .accessibilityLabel("在 Finder 中显示")
        }

        CommandMenu("标签页") {
            Button("关闭标签") {
                AppServices.shared.workspace.closeCurrent()
            }
            .keyboardShortcut("w")
            .accessibilityLabel("关闭标签")

            Button("关闭其他标签") {
                guard let id = AppServices.shared.workspace.selectedTabId else { return }
                AppServices.shared.workspace.closeOthers(except: id)
            }
            .accessibilityLabel("关闭其他标签")

            Divider()
            Button("下一个标签") {
                AppServices.shared.workspace.selectNext()
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])
            .accessibilityLabel("下一个标签")

            Button("上一个标签") {
                AppServices.shared.workspace.selectPrevious()
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])
            .accessibilityLabel("上一个标签")

            Divider()
            Button("关闭窗口") {
                NSApp.keyWindow?.performClose(nil)
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])
        }

        CommandMenu("查看") {
            Button("放大") {
                AppServices.shared.router.send(.zoomIn)
            }
            .keyboardShortcut("+")
            .accessibilityLabel("放大")

            Button("缩小") {
                AppServices.shared.router.send(.zoomOut)
            }
            .keyboardShortcut("-")
            .accessibilityLabel("缩小")

            Button("适应窗口") {
                AppServices.shared.router.send(.zoomFit)
            }
            .keyboardShortcut("0", modifiers: [.command, .shift])
            .accessibilityLabel("适应窗口")

            Button("实际大小") {
                AppServices.shared.router.send(.zoomActual)
            }
            .keyboardShortcut("0")
            .accessibilityLabel("实际大小")

            Divider()
            Button("旋转") {
                AppServices.shared.router.send(.rotate)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .accessibilityLabel("旋转")

            Divider()
            Button("上一个") {
                AppServices.shared.router.send(.prevItem)
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .accessibilityLabel("上一张")

            Button("下一个") {
                AppServices.shared.router.send(.nextItem)
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .accessibilityLabel("下一张")

            Divider()
            Button("查找…") {
                AppServices.shared.router.send(.focusFind)
            }
            .keyboardShortcut("f")
            .accessibilityLabel("查找")

            Button("自动换行") {
                AppServices.shared.router.send(.toggleWrap)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .accessibilityLabel("自动换行")

            Divider()
            Button("显示缩略图") {
                AppServices.shared.router.send(.toggleThumbnails)
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .accessibilityLabel("显示缩略图")

            Button("显示目录") {
                AppServices.shared.router.send(.toggleTOC)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .accessibilityLabel("显示目录")

            Divider()
            Button("增大字号") {
                AppServices.shared.router.send(.increaseFont)
            }
            .keyboardShortcut("=", modifiers: [.command, .option])
            .accessibilityLabel("增大字号")

            Button("减小字号") {
                AppServices.shared.router.send(.decreaseFont)
            }
            .keyboardShortcut("-", modifiers: [.command, .option])
            .accessibilityLabel("减小字号")
        }

        CommandMenu("播放") {
            Button("播放 / 暂停") {
                AppServices.shared.router.send(.togglePlay)
            }
            .accessibilityLabel("播放或暂停")

            Button("循环播放") {
                AppServices.shared.router.send(.toggleLoop)
            }
            .accessibilityLabel("循环播放")

            Divider()
            Button("快退 10 秒") {
                AppServices.shared.router.send(.seekBack)
            }
            .accessibilityLabel("快退 10 秒")

            Button("快进 10 秒") {
                AppServices.shared.router.send(.seekForward)
            }
            .accessibilityLabel("快进 10 秒")

            Divider()
            Button("上一首") {
                AppServices.shared.router.send(.prevItem)
            }
            .accessibilityLabel("上一首")

            Button("下一首") {
                AppServices.shared.router.send(.nextItem)
            }
            .accessibilityLabel("下一首")
        }
    }
}
