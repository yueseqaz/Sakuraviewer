import SwiftUI
import SakuraViewerCore

/// 图片信息浮层：格式、尺寸、大小、修改时间与当前查看状态。
struct ImageInfoPanel: View {

    @ObservedObject var model: ImageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(SakuraTheme.accent)
                Text("图片信息")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            Divider()

            if let url = model.tab.currentURL as URL? {
                infoRow("文件名", url.lastPathComponent)
                infoRow("所在目录", url.deletingLastPathComponent().path)
            }
            infoRow("格式", model.formatName + (model.isAnimated ? "（动图）" : ""))
            infoRow("像素尺寸", "\(Int(model.pixelSize.width)) × \(Int(model.pixelSize.height))")
            infoRow("文件大小", SakuraFormatter.fileSize(model.fileSize))
            if let date = model.modifiedDate {
                infoRow("修改时间", date.formatted(date: .abbreviated, time: .shortened))
            }
            infoRow("当前缩放", SakuraFormatter.zoomPercent(model.effectiveZoom))
            if model.rotation != 0 {
                infoRow("旋转", "\(Int(model.rotation))°")
            }
            if !model.siblings.isEmpty, model.siblingIndex >= 0 {
                infoRow("同目录同类", "第 \(model.siblingIndex + 1) / \(model.siblings.count) 张")
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .frame(width: 74, alignment: .leading)
            Text(value)
                .font(.system(size: 11.5, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }
}
