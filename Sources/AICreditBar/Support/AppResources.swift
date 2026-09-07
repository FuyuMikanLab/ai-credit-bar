import Foundation

/// SwiftPM 的 `Bundle.module` 在 `.app` 里会去包根目录找 `AICreditBar_AICreditBar.bundle`，找不到就直接崩溃。
/// 打包脚本把资源放在 `Contents/Resources/`，这里按实际位置查找。
enum AppResources {
    static let bundleName = "AICreditBar_AICreditBar.bundle"

    static var bundle: Bundle {
        for url in candidateURLs where FileManager.default.fileExists(atPath: url.path) {
            if let bundle = Bundle(url: url) { return bundle }
        }
        return .module
    }

    private static var candidateURLs: [URL] {
        [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent(bundleName),
        ].compactMap { $0 }
    }
}
