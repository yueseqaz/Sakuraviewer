# Sakura-Viewer 示例文档

这是一份 **Markdown 样例**，覆盖常用语法。标题会出现在右侧目录中。

## 文本样式

普通文字，**粗体**，*斜体*，~~删除线~~，`行内代码`，[链接](https://developer.apple.com)。
自动链接：<https://developer.apple.com>

## 列表

无序列表：

- 图片：jpg / png / gif / webp / heic
- 视频：mp4 / mov / m4v
- 音频：mp3 / m4a / wav / flac

有序列表：

1. 打开文件（⌘O）
2. 多标签浏览
3. 恢复上次会话

任务列表：

- [x] 原生 SwiftUI 界面
- [x] 零第三方依赖
- [ ] 更多格式

## 代码块

Swift 示例（带语法高亮）：

```swift
let petals = (0..<5).map { "🌸" }
print(petals.joined())
```

Python 示例：

```python
def bloom():
    return "樱花开了"
```

## 表格

| 格式 | 查看器 | 特色 |
|:-----|:------|:-----|
| 图片 | ImageIO | 缩放/旋转/切换 |
| PDF  | PDFKit | 连续滚动/搜索 |
| 音频 | AVFoundation | 播放列表 |

## 引用

> 原生、优雅、精美。
> —— Sakura-Viewer 设计目标

## 图片

![样例图片](photo.png)

---

结尾分隔线。