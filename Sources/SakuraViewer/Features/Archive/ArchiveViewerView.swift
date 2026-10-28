import SwiftUI
import AppKit

/// Read-only archive browser. It lists entries without extracting anything;
/// unsupported archive families fall back to the default macOS application.
struct ArchiveViewerView: View {

    @ObservedObject var tab: TabDocument
    let isActive: Bool
    @State private var entries: [String] = []
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "archivebox")
                    .foregroundColor(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.currentURL.lastPathComponent)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(error ?? "目录预览 · 共 \(entries.count) 项")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("用默认应用打开") { NSWorkspace.shared.open(tab.currentURL) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if let error {
                ErrorStateView(
                    title: "无法读取压缩包目录",
                    message: error,
                    retryAction: loadEntries,
                    extraActions: AnyView(Button("用默认应用打开") { NSWorkspace.shared.open(tab.currentURL) })
                )
            } else if entries.isEmpty {
                LoadingStateView(text: "正在读取压缩包目录…")
            } else {
                List(entries, id: \.self) { entry in
                    Label(entry, systemImage: entry.hasSuffix("/") ? "folder" : "doc")
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                }
                .listStyle(.inset)
            }
        }
        .onAppear {
            if isActive {
                tab.status = .loading
                loadEntries()
            }
        }
        .onChange(of: tab.reloadToken) { _ in if isActive { loadEntries() } }
        .onChange(of: isActive) { active in
            if active { loadEntries() }
        }
    }

    private func loadEntries() {
        entries = []
        error = nil
        let url = tab.currentURL
        Task.detached(priority: .utility) {
            let result = Self.readEntries(url: url)
            await MainActor.run {
                guard self.tab.currentURL == url else { return }
                switch result {
                case .success(let values):
                    self.entries = values
                    self.tab.status = .ready
                    self.tab.statusDetail = "压缩包 · \(values.count) 项"
                case .failure(let failure):
                    self.error = failure.message
                    self.tab.status = .ready
                }
            }
        }
    }

    private struct ArchiveReadError: Error {
        let message: String
    }

    nonisolated private static func readEntries(url: URL) -> Result<[String], ArchiveReadError> {
        let ext = url.pathExtension.lowercased()
        let executable: String
        let arguments: [String]
        if ext == "zip" {
            executable = "/usr/bin/unzip"
            arguments = ["-Z1", url.path]
        } else if ["tar", "tgz", "tbz", "txz"].contains(ext) {
            executable = "/usr/bin/tar"
            arguments = ["-tf", url.path]
        } else {
            return .failure(ArchiveReadError(message: "此压缩格式由系统 Quick Look 或默认应用处理。"))
        }

        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure(ArchiveReadError(message: "系统工具不可用：\(error.localizedDescription)"))
        }
        guard process.terminationStatus == 0 else {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(ArchiveReadError(message: message?.isEmpty == false ? message! : "文件可能已损坏或没有读取权限。"))
        }
        let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let values = text.split(whereSeparator: \.isNewline).map(String.init)
        return values.isEmpty
            ? .failure(ArchiveReadError(message: "压缩包为空。"))
            : .success(values)
    }
}
