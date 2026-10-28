import SwiftUI
import SakuraViewerCore

/// 文本/代码查看器共享核心：加载、查找条、工具栏、路由注册。
struct TextViewerCoreView: View {

    @EnvironmentObject private var services: AppServices
    @ObservedObject var tab: TabDocument
    let isActive: Bool
    let language: CodeLanguage
    let highlightEnabled: Bool

    @StateObject private var model: TextViewModel
    @FocusState private var findFocused: Bool
    @State private var showGotoAlert = false
    @State private var gotoText = ""

    init(tab: TabDocument, isActive: Bool, language: CodeLanguage, highlightEnabled: Bool) {
        self.tab = tab
        self.isActive = isActive
        self.language = language
        self.highlightEnabled = highlightEnabled
        _model = StateObject(wrappedValue: TextViewModel(
            tab: tab,
            language: language,
            highlightEnabled: highlightEnabled
        ))
    }

    var body: some View {
        content
            .toolbar { toolbar }
            .alert("跳转到行", isPresented: $showGotoAlert) {
                TextField("行号（1 – \(max(model.lineCount, 1))）", text: $gotoText)
                    .frame(width: 160)
                Button("跳转") {
                    if let line = Int(gotoText.trimmingCharacters(in: .whitespaces)) {
                        model.requestGotoLine(line)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("共 \(max(model.lineCount, 1)) 行，输入目标行号后回车。")
            }
            .onAppear {
                // TabDocument 初始状态即 .loading，此处以内容为依据触发首次加载
                if model.attributed.length == 0 {
                    model.load()
                }
                registerRouter()
            }
            .onDisappear {
                services.router.unregister(tab.id)
            }
            .onChange(of: tab.reloadToken) { _ in
                model.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch tab.status {
        case .loading:
            LoadingStateView(text: "正在读取文本…")
        case .failed(let message):
            ErrorStateView(
                title: "无法打开文件",
                message: "\(tab.currentURL.lastPathComponent)：\(message)",
                retryAction: { model.load() }
            )
        case .ready:
            ZStack(alignment: .topTrailing) {
                TextViewCanvas(model: model)
                    .accessibilityLabel("文本内容：\(tab.title)")

                if model.isFindVisible {
                    FindBarView(
                        query: $model.query,
                        matchCount: model.matchCount,
                        matchIndex: model.matchIndex,
                        onNext: {
                            model.findTick += 1
                        },
                        onPrev: {
                            model.findBackTick += 1
                        },
                        onClose: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                model.isFindVisible = false
                                findFocused = false
                            }
                        },
                        isFocused: $findFocused
                    )
                    .padding(.trailing, 16)
                }
            }
        }
    }

    // MARK: 工具栏

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isActive {
            ToolbarItemGroup(placement: .primaryAction) {
                if highlightEnabled {
                    Chip(text: language.displayName)
                }

                IconButton(systemName: "arrow.down.to.line.compact", size: 26, iconSize: 12) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        model.wrapEnabled.toggle()
                    }
                }
                .help("自动换行（⇧⌘L）")
                .accessibilityLabel("自动换行")
                .opacity(model.wrapEnabled ? 1 : 0.45)

                Divider()

                IconButton(systemName: "textformat.size.larger", size: 26, iconSize: 12) { model.increaseFont() }
                    .help("增大字号（⌥⌘+）")
                    .accessibilityLabel("增大字号")

                IconButton(systemName: "textformat.size.smaller", size: 26, iconSize: 12) { model.decreaseFont() }
                    .help("减小字号（⌥⌘-）")
                    .accessibilityLabel("减小字号")

                Divider()

                IconButton(systemName: "number", size: 26, iconSize: 12) {
                    gotoText = ""
                    showGotoAlert = true
                }
                .help("跳转到行（⌘L）")
                .accessibilityLabel("跳转到行")

                IconButton(systemName: "magnifyingglass", size: 26, iconSize: 12) {
                    showFind()
                }
                .help("查找（⌘F）")
                .accessibilityLabel("查找")
            }
        }
    }

    private func showFind() {
        withAnimation(.easeOut(duration: 0.15)) {
            model.isFindVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            findFocused = true
        }
    }

    // MARK: 路由

    private func registerRouter() {
        services.router.register(ViewerRegistration(
            tabId: tab.id,
            capabilities: [.find, .wrap, .font, .gotoLine],
            perform: { action in
                switch action {
                case .focusFind: showFind()
                case .findNext: model.findTick += 1
                case .findPrev: model.findBackTick += 1
                case .toggleWrap: model.wrapEnabled.toggle()
                case .increaseFont: model.increaseFont()
                case .decreaseFont: model.decreaseFont()
                case .gotoLine:
                    gotoText = ""
                    showGotoAlert = true
                case .refresh: model.load()
                default: break
                }
            }
        ))
    }
}

/// 纯文本查看器。
struct TextViewerView: View {
    @ObservedObject var tab: TabDocument
    let isActive: Bool

    var body: some View {
        TextViewerCoreView(tab: tab, isActive: isActive, language: .plain, highlightEnabled: false)
    }
}

/// 代码查看器：按扩展名选择语言高亮。
struct CodeViewerView: View {
    @ObservedObject var tab: TabDocument
    let isActive: Bool

    var body: some View {
        TextViewerCoreView(
            tab: tab,
            isActive: isActive,
            language: CodeLanguage(fileExtension: tab.fileExtension),
            highlightEnabled: true
        )
    }
}
