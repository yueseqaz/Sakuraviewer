import Foundation
import SakuraViewerCore

enum TextEncodingDetectorTests {

    static let name = "TextEncodingDetectorTests"

    static func runAll() {
        runCase(name, "utf8Chinese") { utf8Chinese() }
        runCase(name, "utf8BOM") { utf8BOM() }
        runCase(name, "utf16LEBOM") { utf16LEBOM() }
        runCase(name, "utf16BEBOM") { utf16BEBOM() }
        runCase(name, "gb18030Chinese") { gb18030Chinese() }
        runCase(name, "asciiPassThrough") { asciiPassThrough() }
        runCase(name, "neverFailsOnArbitraryBytes") { neverFailsOnArbitraryBytes() }
    }

    static func utf8Chinese() {
        let data = Data("你好，世界 🌸".utf8)
        let (text, info) = TextEncodingDetector.decode(data)
        checkEqual(text, "你好，世界 🌸")
        checkEqual(info.displayName, "UTF-8")
    }

    static func utf8BOM() {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("BOM content".utf8))
        checkEqual(TextEncodingDetector.detect(in: data).displayName, "UTF-8")
    }

    static func utf16LEBOM() {
        var data = Data([0xFF, 0xFE])
        data.append(contentsOf: [0x41, 0x00, 0x42, 0x00]) // "AB" UTF-16LE
        checkEqual(TextEncodingDetector.detect(in: data).displayName, "UTF-16LE")
        let (text, _) = TextEncodingDetector.decode(data)
        checkEqual(text, "AB")
    }

    static func utf16BEBOM() {
        var data = Data([0xFE, 0xFF])
        data.append(contentsOf: [0x00, 0x41, 0x00, 0x42])
        checkEqual(TextEncodingDetector.detect(in: data).displayName, "UTF-16BE")
    }

    static func gb18030Chinese() {
        // "你好" 的 GBK/GB18030 编码
        let data = Data([0xC4, 0xE3, 0xBA, 0xC3])
        let (text, info) = TextEncodingDetector.decode(data)
        checkEqual(text, "你好")
        checkEqual(info.displayName, "GB18030")
    }

    static func asciiPassThrough() {
        let data = Data("plain ascii 123".utf8)
        let (text, info) = TextEncodingDetector.decode(data)
        checkEqual(text, "plain ascii 123")
        checkEqual(info.displayName, "UTF-8")
    }

    static func neverFailsOnArbitraryBytes() {
        // 任意字节序列都不应抛错或崩溃
        for byte: UInt8 in UInt8.min...UInt8.max {
            _ = TextEncodingDetector.decode(Data([byte, byte, byte]))
        }
        check(true)
    }
}
