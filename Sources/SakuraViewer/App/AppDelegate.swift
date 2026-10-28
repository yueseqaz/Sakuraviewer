import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        AppServices.shared.settings.applyAppearance()
        installKeyMonitor()
        applyDefaultWindowSizeIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 首次启动把主窗口设为默认尺寸 1280×820（标签页与侧边栏在该尺寸下无需滚动）。
    /// 写入标记后不再覆盖用户的后续调整。
    private func applyDefaultWindowSizeIfNeeded() {
        let key = "sakura.window.default.applied"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
                  window.frame.width < 1100 else { return }
            let size = NSSize(width: 1280, height: 820)
            let screen = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1470, height: 923)
            let origin = NSPoint(
                x: max(screen.minX, screen.midX - size.width / 2),
                y: max(screen.minY, screen.midY - size.height / 2)
            )
            window.setFrame(NSRect(origin: origin, size: size), display: true, animate: true)
        }
    }

    /// 处理 Finder「打开方式」/ 拖到 Dock 图标 / `open` 命令。
    func application(_ application: NSApplication, open urls: [URL]) {
        AppServices.shared.open(urls: urls)
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppServices.shared.saveSession()
    }

    // MARK: 全局键盘路由

    /// 空格：播放/暂停；左右方向键：上一张/下一张、媒体跳转；⌘W：关闭标签。
    /// 文本控件获得焦点时不拦截方向键/空格。
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = NSApp.keyWindow, window.isKeyWindow else { return event }

            // ⌘W 始终解释为「关闭标签」，避免与 Window scene 自带的
            // 「关闭窗口」快捷键冲突导致最后一个标签关闭时整个应用退出。
            if event.keyCode == 13, // W
               event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
                AppServices.shared.workspace.closeCurrent()
                return nil
            }

            guard !Self.isTextInputActive else { return event }

            let router = AppServices.shared.router
            switch event.keyCode {
            case 49: // Space
                if router.has(capability: .media) {
                    router.send(.togglePlay)
                    return nil
                }
            case 124: // →
                if router.has(capability: .media) {
                    router.send(.seekForward)
                    return nil
                }
                if router.has(capability: .arrowPaging) {
                    router.send(.nextItem)
                    return nil
                }
            case 123: // ←
                if router.has(capability: .media) {
                    router.send(.seekBack)
                    return nil
                }
                if router.has(capability: .arrowPaging) {
                    router.send(.prevItem)
                    return nil
                }
            default:
                break
            }
            return event
        }
    }

    /// 首响应者是否处于文本编辑状态。
    nonisolated static var isTextInputActive: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        if responder is NSTextView || responder is NSText { return true }
        if let field = responder as? NSTextField, field.isEditable { return true }
        return false
    }
}
