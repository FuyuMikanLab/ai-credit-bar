import Foundation

/// 语言选择：跟随系统，或显式指定。
enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system
    case zhHans = "zh-Hans"
    case en

    var id: String { rawValue }

    /// 实际生效的语言代码（system 会按系统首选语言解析）。
    var resolvedCode: String {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("zh") ? "zh-Hans" : "en"
        case .zhHans: return "zh-Hans"
        case .en: return "en"
        }
    }

    /// 设置页语言选项的显示名（各语言下都保留“简体中文”这一母语写法）。
    var displayName: String {
        switch self {
        case .system: return L10n.str("language.system")
        case .zhHans: return L10n.str("language.zh_hans")
        case .en: return L10n.str("language.en")
        }
    }
}

/// 轻量本地化：从 `Resources/Locales/<code>.json` 语言包读取文案。
/// 支持 `%@` / `%d` 插值与 `.one` / `.other` 单复数。
///
/// 用法：
///   L10n.str("common.settings")                 // 无参数
///   L10n.str("panel.last_refresh", "12:00")     // 带参数
///   L10n.plural("panel.failing_count", count: n) // 单复数
enum L10n {
    private static var table: [String: String] = [:]
    private static var didLoad = false

    /// 当前生效的语言选择（与 settings.json 中的 language 保持一致）。
    private(set) static var language: AppLanguage = .system

    /// 应用某个语言并（重新）加载对应语言包。
    static func apply(_ lang: AppLanguage) {
        language = lang
        didLoad = true
        table = loadTable(lang.resolvedCode) ?? loadTable("en") ?? [:]
    }

    /// 无参数文案。
    static func str(_ key: String) -> String {
        ensureLoaded()
        return table[key] ?? key
    }

    /// 带参数文案（语言包里用 %@ / %d / %f 占位）。
    static func str(_ key: String, _ args: CVarArg...) -> String {
        ensureLoaded()
        let format = table[key] ?? key
        return String(format: format, locale: Locale(identifier: language.resolvedCode), arguments: args)
    }

    /// 单复数文案：count == 1 时取 `<key>.one`，否则取 `<key>.other`。
    static func plural(_ key: String, count: Int) -> String {
        str(count == 1 ? "\(key).one" : "\(key).other", count)
    }

    // MARK: 内部

    private static func ensureLoaded() {
        guard !didLoad else { return }
        apply(.system)
    }

    private static func loadTable(_ code: String) -> [String: String]? {
        guard let url = localeFileURL(code),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: String] else { return nil }
        return dict
    }

    /// 依次在 SPM 资源 bundle（swift run）与 .app 的 Resources（脚本打包）里找语言包。
    private static func localeFileURL(_ code: String) -> URL? {
        let bundle = AppResources.bundle
        let candidates: [URL] = [
            bundle.url(forResource: code, withExtension: "json", subdirectory: "Locales"),
            bundle.url(forResource: code, withExtension: "json", subdirectory: "Resources/Locales"),
            Bundle.main.url(forResource: code, withExtension: "json", subdirectory: "Locales"),
            Bundle.main.resourceURL.map { $0.appendingPathComponent("Locales/\(code).json") },
        ].compactMap { $0 }
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
