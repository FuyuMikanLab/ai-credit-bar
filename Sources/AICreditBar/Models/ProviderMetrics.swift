import Foundation

// MARK: - 归一化后的统一指标

/// 各厂商原始响应经 Adapter 处理后，统一成这个结构再交给 UI 展示。
/// 字段全部可选：某个厂商拿不到的信息就是 nil，UI 按需组合。
struct ProviderMetrics: Equatable {
    var kind: ProviderKind
    var displayName: String
    var fetchedAt: Date

    // 金额类（可用余额 / 累计充值 / 周期已消费）
    var currency: String?          // ISO 代码：CNY / USD …
    var availableBalance: Decimal? // 当前可用余额 / 剩余额度
    var totalCredits: Decimal?     // 累计充值 / 总购买额度
    var cycleUsed: Decimal?        // 本计费周期已消费金额

    // 用量类（Token / 请求数）
    var inputTokens: Int64?
    var outputTokens: Int64?
    var requests: Int64?

    // 周期范围（如 OpenAI 的“本月”）
    var cycleStart: Date?
    var cycleEnd: Date?

    /// 厂商特有的次要信息行（已本地化文案），例如“赠送 ¥x · 充值 ¥y”。
    var detailLines: [String] = []

    var totalTokens: Int64? {
        guard let i = inputTokens, let o = outputTokens else { return nil }
        return i + o
    }

    init(kind: ProviderKind, displayName: String? = nil, fetchedAt: Date = Date()) {
        self.kind = kind
        self.displayName = displayName ?? kind.displayName
        self.fetchedAt = fetchedAt
    }
}

// MARK: - 单个数据源当前加载状态

enum ProviderLoadState: Equatable {
    case idle
    case loading
    case success(ProviderMetrics)
    case failure(String)
}

struct ProviderSnapshot: Identifiable, Equatable {
    var config: ProviderConfig
    var state: ProviderLoadState = .idle

    var id: ProviderKind { config.kind }
}
