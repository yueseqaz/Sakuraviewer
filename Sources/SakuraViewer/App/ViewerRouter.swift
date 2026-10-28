import Foundation

/// 查看器动作：由菜单、快捷键、状态栏等触发，路由到当前激活的查看器。
enum ViewerAction {
    case zoomIn
    case zoomOut
    case zoomFit
    case zoomActual
    case rotate
    case nextItem
    case prevItem
    case togglePlay
    case toggleLoop
    case seekBack
    case seekForward
    case focusFind
    case findNext
    case findPrev
    case toggleWrap
    case toggleThumbnails
    case toggleTOC
    case increaseFont
    case decreaseFont
    case gotoLine
    case refresh
}

/// 查看器能力声明：决定哪些工具栏命令可用。
enum ViewerCapability: Hashable {
    case zoom
    case rotate
    case paging      // 上一张/下一张按钮
    case arrowPaging // 左右方向键翻页（图片；PDF 保持原生滚动）
    case media       // 播放/暂停、循环
    case find        // 查找
    case wrap        // 自动换行
    case font        // 字号调整
    case gotoLine    // 跳转到行
    case thumbnails  // PDF 缩略图
    case toc         // Markdown 目录
}

struct ViewerRegistration {
    let tabId: UUID
    let capabilities: Set<ViewerCapability>
    let perform: (ViewerAction) -> Void
}

/// 动作总线：查看器注册自己的处理闭包，命令系统按当前标签分发。
@MainActor
final class ViewerRouter: ObservableObject {

    @Published private(set) var currentTabId: UUID?
    @Published private(set) var activeCapabilities: Set<ViewerCapability> = []

    private var registrations: [UUID: ViewerRegistration] = [:]

    func register(_ registration: ViewerRegistration) {
        registrations[registration.tabId] = registration
        if registration.tabId == currentTabId {
            activeCapabilities = registration.capabilities
        }
    }

    func unregister(_ tabId: UUID) {
        registrations.removeValue(forKey: tabId)
        if tabId == currentTabId {
            activeCapabilities = []
        }
    }

    func activate(tabId: UUID?) {
        currentTabId = tabId
        activeCapabilities = tabId.flatMap { registrations[$0]?.capabilities } ?? []
    }

    func send(_ action: ViewerAction) {
        guard let id = currentTabId, let registration = registrations[id] else { return }
        registration.perform(action)
    }

    func has(capability: ViewerCapability) -> Bool {
        activeCapabilities.contains(capability)
    }
}
