import Foundation

// MARK: - Provider 种类与元信息

/// 支持的 AI API 数据源。新增厂商 = 新建一个 ProviderKind 分支 + 一个 Adapter。
enum ProviderKind: String, Codable, CaseIterable, Identifiable {
    case deepseek
    case moonshot
    case openrouter
    case siliconflow
    case openai
    case zhipu

    var id: String { rawValue }

    var displayName: String {
        L10n.str("provider.\(rawValue).name")
    }

    /// 默认 API 根地址（各 Adapter 再拼接具体路径）。
    var defaultBaseURLString: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com"
        case .moonshot: return "https://api.moonshot.cn"
        case .openrouter: return "https://openrouter.ai"
        case .siliconflow: return "https://api.siliconflow.cn"
        case .openai: return "https://api.openai.com"
        case .zhipu: return "https://open.bigmodel.cn"
        }
    }

    /// 厂商控制台（余额/用量页面），供打开查看。
    var consoleURL: URL? {
        let s: String
        switch self {
        case .deepseek: s = "https://platform.deepseek.com/usage"
        case .moonshot: s = "https://platform.moonshot.cn/console/usage-detail"
        case .openrouter: s = "https://openrouter.ai/settings/credits"
        case .siliconflow: s = "https://cloud.siliconflow.cn/account/usage"
        case .openai: s = "https://platform.openai.com/usage"
        case .zhipu: s = "https://open.bigmodel.cn/console/overview"
        }
        return URL(string: s)
    }

    /// 设置页里展示的“这个数据源能显示什么”。
    var capabilityText: String {
        L10n.str("provider.\(rawValue).capability")
    }

    /// 创建 Key 的入口提示。
    var setupHint: String {
        L10n.str("provider.\(rawValue).setup_hint")
    }

    /// 状态栏里用到的简短符。
    var symbolName: String {
        switch self {
        case .deepseek: return "chart.line.uptrend.xyaxis"
        case .moonshot: return "moon.stars.fill"
        case .openrouter: return "arrow.triangle.branch"
        case .siliconflow: return "water.waves"
        case .openai: return "hexagon.fill"
        case .zhipu: return "brain.head.profile"
        }
    }

    /// `Resources/ProviderLogos/<name>.pdf|png|svg` 的文件名（不含扩展名）。
    var logoResourceName: String { rawValue }
}

// MARK: - 单个数据源配置

struct ProviderConfig: Codable, Equatable, Identifiable {
    var kind: ProviderKind
    var isEnabled: Bool = true
    /// 自定义显示名（空则用默认名）。
    var displayNameOverride: String = ""
    /// 可选的 API 根地址覆盖（高级用法，例如切换海外站）。
    var baseURLString: String = ""

    var id: ProviderKind { kind }

    var displayName: String {
        let trimmed = displayNameOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.displayName : trimmed
    }

    func resolvedBaseURLString() -> String {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.defaultBaseURLString : trimmed
    }

    init(kind: ProviderKind,
         isEnabled: Bool = true,
         displayNameOverride: String = "",
         baseURLString: String = "") {
        self.kind = kind
        self.isEnabled = isEnabled
        self.displayNameOverride = displayNameOverride
        self.baseURLString = baseURLString
    }
}

// MARK: - 全局设置

enum StatusBarMode: String, Codable, CaseIterable, Identifiable {
    case iconOnly
    case primaryBalance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .iconOnly: return L10n.str("statusbar_mode.icon_only")
        case .primaryBalance: return L10n.str("statusbar_mode.primary_balance")
        }
    }
}

struct AppSettings: Codable, Equatable {
    /// 是否自动定时刷新。
    var autoRefresh: Bool = true
    /// 自动刷新间隔（分钟）。
    var refreshMinutes: Int = 15
    /// 状态栏显示模式。
    var statusBarMode: StatusBarMode = .iconOnly
    /// primaryBalance 模式下，状态栏文本显示哪个数据源的余额。
    var primaryProviderID: ProviderKind? = nil
    /// 界面语言（默认跟随系统）。
    var language: AppLanguage = .system
    /// 所有数据源的启用/名称配置。
    var providers: [ProviderConfig]

    static let `default` = AppSettings(
        providers: ProviderKind.allCases.map { ProviderConfig(kind: $0) }
    )

    /// 保证所有 ProviderKind 都有对应配置（新版本新增厂商后自动补齐）。
    func mergingAllProviders() -> AppSettings {
        var copy = self
        let existing = Dictionary(uniqueKeysWithValues: providers.map { ($0.kind, $0) })
        copy.providers = ProviderKind.allCases.map { existing[$0] ?? ProviderConfig(kind: $0) }
        return copy
    }

    func providerConfig(for kind: ProviderKind) -> ProviderConfig? {
        providers.first { $0.kind == kind }
    }

    var enabledProviders: [ProviderConfig] {
        providers.filter { $0.isEnabled }
    }
}

// MARK: - 兼容旧版 settings.json

extension AppSettings {
    /// 自定义解码：老版本设置文件里没有 `language` 字段，缺省时回退为“跟随系统”。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        autoRefresh = try c.decodeIfPresent(Bool.self, forKey: .autoRefresh) ?? true
        refreshMinutes = try c.decodeIfPresent(Int.self, forKey: .refreshMinutes) ?? 15
        statusBarMode = try c.decodeIfPresent(StatusBarMode.self, forKey: .statusBarMode) ?? .iconOnly
        primaryProviderID = try c.decodeIfPresent(ProviderKind.self, forKey: .primaryProviderID)
        language = try c.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
        providers = try c.decode([ProviderConfig].self, forKey: .providers)
    }
}
