// hello.swift — Swift 语法高亮样例
import Foundation

struct SakuraPetal {
    let angle: Double
    let color: String

    func describe() -> String {
        return "花瓣角度 \(angle)°，颜色 \(color)"
    }
}

let petals = (0..<5).map { SakuraPetal(angle: Double($0) * 72, color: "樱粉") }
for petal in petals {
    print(petal.describe()) // 打印每一片花瓣
}

/* 块注释：
   Sakura-Viewer 使用自研轻量高亮器 */