import Foundation
import SakuraViewerCore

// 测试入口：执行全部套件，失败时以非零码退出。
let exitCode = runAllTests(suites: [
    ("FileKindTests", FileKindTests.runAll),
    ("TextEncodingDetectorTests", TextEncodingDetectorTests.runAll),
    ("TextFileLoaderTests", TextFileLoaderTests.runAll),
    ("SyntaxHighlighterTests", SyntaxHighlighterTests.runAll),
    ("MarkdownParserTests", MarkdownParserTests.runAll),
    ("RecentFilesStoreTests", RecentFilesStoreTests.runAll),
    ("FavoritesStoreTests", FavoritesStoreTests.runAll),
    ("SessionStoreTests", SessionStoreTests.runAll),
    ("MediaPlaylistBuilderTests", MediaPlaylistBuilderTests.runAll),
    ("FormatterTests", FormatterTests.runAll),
])
exit(exitCode)
