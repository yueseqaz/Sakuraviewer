import SwiftUI
import SakuraViewerCore

/// 顶部多标签栏：切换、关闭、右键菜单、按类型的类型图标。
struct TabBarView: View {

    @EnvironmentObject private var workspace: WorkspaceModel
    @EnvironmentObject private var services: AppServices
    @State private var wheelIndex = 0

    var body: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(workspace.tabs) { tab in
                            TabCellView(tab: tab, isSelected: tab.id == workspace.selectedTabId)
                                .id(tab.id)
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }
                    .padding(.horizontal, SakuraTheme.compactPadding)
                    .padding(.vertical, 6)
                }

                IconButton(systemName: "plus", size: 24, iconSize: 11, tint: .secondary) {
                    if let urls = FilePicker.pickFiles() {
                        services.open(urls: urls)
                    }
                }
                .help("打开新文件（⌘O）")
                .accessibilityLabel("打开新文件")
            }
            .background {
                TabBarScrollCapture { delta in
                    moveTabStrip(by: delta, proxy: proxy)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
            .onAppear { syncWheelIndex() }
            .onChange(of: workspace.selectedTabId) { _ in syncWheelIndex() }
            .onChange(of: workspace.tabs.map(\.id)) { _ in syncWheelIndex() }
        }
        .background(Color.primary.opacity(0.03))
        .overlay(alignment: .bottom) { Divider() }
        .animation(.easeOut(duration: 0.16), value: workspace.tabs.map(\.id))
    }

    private func syncWheelIndex() {
        guard !workspace.tabs.isEmpty else {
            wheelIndex = 0
            return
        }
        if let selected = workspace.selectedTabId,
           let index = workspace.tabs.firstIndex(where: { $0.id == selected }) {
            wheelIndex = index
        } else {
            wheelIndex = min(wheelIndex, workspace.tabs.count - 1)
        }
    }

    private func moveTabStrip(by delta: CGFloat, proxy: ScrollViewProxy) {
        guard !workspace.tabs.isEmpty, abs(delta) > 0.01 else { return }
        // 鼠标滚轮向下（负值）向后，向上（正值）向前。
        let step = delta < 0 ? 1 : -1
        let next = min(max(wheelIndex + step, 0), workspace.tabs.count - 1)
        guard next != wheelIndex else { return }
        wheelIndex = next
        let target = workspace.tabs[next]
        withAnimation(.easeOut(duration: 0.16)) {
            proxy.scrollTo(target.id, anchor: .center)
        }
    }
}

/// 将普通鼠标滚轮转换成标签栏的横向滚动，不影响标签点击。
private struct TabBarScrollCapture: NSViewRepresentable {

    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollCaptureView {
        let view = ScrollCaptureView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ view: ScrollCaptureView, context: Context) {
        view.onScroll = onScroll
    }
}

private final class ScrollCaptureView: NSView {

    var onScroll: ((CGFloat) -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeMonitor()
        } else if monitor == nil {
            installMonitor()
        }
    }

    deinit {
        removeMonitor()
    }

    private func installMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let window = self.window, event.window === window else { return event }
            let point = self.convert(event.locationInWindow, from: nil)
            guard self.bounds.contains(point) else { return event }

            let vertical = event.scrollingDeltaY
            let horizontal = event.scrollingDeltaX
            let delta = abs(horizontal) > abs(vertical) ? horizontal : vertical
            guard abs(delta) > 0.01 else { return event }
            self.onScroll?(delta)
            return nil
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

private struct TabCellView: View {

    @EnvironmentObject private var workspace: WorkspaceModel
    @ObservedObject var tab: TabDocument
    let isSelected: Bool

    @State private var hovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: FileKind.symbolName(for: tab.currentURL))
                .font(.system(size: 11))
                .foregroundColor(SakuraTheme.kindColor(tab.kind))
                .accessibilityHidden(true)

            Text(tab.title)
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .frame(maxWidth: 138, alignment: .leading)

            CloseButton {
                withAnimation(.easeOut(duration: 0.14)) {
                    workspace.close(id: tab.id)
                }
            }
            .opacity(isSelected || hovered ? 1 : 0)
        }
        .padding(.leading, 8)
        .padding(.trailing, 3)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(
                    isSelected
                        ? Color(nsColor: .controlBackgroundColor)
                        : Color.primary.opacity(hovered ? 0.05 : 0)
                )
                .shadow(color: .black.opacity(isSelected ? 0.08 : 0), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.primary.opacity(isSelected ? 0.07 : 0), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            workspace.selectedTabId = tab.id
        }
        .onHover { hovered = $0 }
        .contextMenu {
            Button("关闭标签") { workspace.close(id: tab.id) }
            Button("关闭其他标签") {
                guard let id = workspace.selectedTabId else { return }
                workspace.closeOthers(except: id)
            }
            Divider()
            Button("在 Finder 中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([tab.currentURL])
            }
            Button("拷贝文件路径") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(tab.currentURL.path, forType: .string)
            }
        }
        .help(tab.currentURL.path)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("标签：\(tab.title)，\(tab.kind.displayName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 关闭按钮（×）。
struct CloseButton: View {
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(hovered ? .primary : .secondary)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.primary.opacity(hovered ? 0.12 : 0)))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel("关闭标签")
    }
}
