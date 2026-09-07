import Foundation

/// 智谱（open.bigmodel.cn）标准版余额查询。
///
/// 首选（历史文档化接口）：
///   GET {base}/api/paas/v4/balance
///   Authorization 头直接用原始 Key（不带 Bearer 前缀，个别情况 Bearer 也可）
///   → { code: 200, balance: [ { total, used, ... } ] }（人民币）
///
/// 兜底（当前业务网关，需要 Bearer）：
///   GET {base}/api/biz/account/query-customer-account-report
///   → { data: { availableBalance / balance, rechargeAmount, totalSpendAmount, giveAmount, frozenBalance } }
///
/// 说明：各家对 “total” 的口径不完全一致，这里同时展示总额与已用，
/// 并给出 可用 = 总额 − 已用 的推断值，最终请以智谱控制台为准。
struct ZhipuAdapter: ProviderFetching {
    let kind = ProviderKind.zhipu

    private let legacyPath = "api/paas/v4/balance"
    private let bizPath = "api/biz/account/query-customer-account-report"

    func fetch(apiKey: String, baseURL: URL, now: Date) async throws -> ProviderMetrics {
        // 首选 legacy：raw key 头。
        do {
            let url = try HTTP.makeURL(base: baseURL.absoluteString, path: legacyPath)
            let raw = try await HTTPClient.json(url: url, headers: HTTP.rawKeyHeaders(apiKey))
            return try Self.parseLegacy(raw, now: now)
        } catch let error as NetworkError {
            switch error {
            case .badStatus(let code, _) where (401...404).contains(code):
                break // 换业务网关再试
            default:
                throw error
            }
        }
        // 兜底业务网关：Bearer 头。
        let bizURL = try HTTP.makeURL(base: baseURL.absoluteString, path: bizPath)
        let raw = try await HTTPClient.json(url: bizURL, headers: HTTP.bearerHeaders(apiKey))
        return try Self.parseBiz(raw, now: now)
    }

    // MARK: 解析（供自测直接调用）

    static func parseLegacy(_ raw: Any, now: Date) throws -> ProviderMetrics {
        guard let root = JSONBox.dictionary(raw) else { throw NetworkError.unparseable }
        let container = root.dict("data") ?? root
        let list = container.arr("balance") ?? root.arr("balance")
        guard let list, let first = list.compactMap(JSONBox.dictionary).first else {
            throw AdapterError.emptyData(L10n.str("adapter.no_balance_array"))
        }

        var metrics = ProviderMetrics(kind: .zhipu, fetchedAt: now)
        metrics.currency = "CNY"
        let total = JSONBox.decimal(first["total"])
        let used = JSONBox.decimal(first["used"])
        metrics.totalCredits = total

        if let total, let used, total >= used, used >= 0 {
            metrics.cycleUsed = used
            metrics.availableBalance = total - used
        } else if let total {
            metrics.availableBalance = total
        }
        var parts: [String] = []
        if let total { parts.append(L10n.str("detail.total", Money.short(total, currency: "CNY"))) }
        if let used, used > 0 { parts.append(L10n.str("detail.used", Money.short(used, currency: "CNY"))) }
        if !parts.isEmpty { metrics.detailLines = [parts.joined(separator: " · ")] }
        return metrics
    }

    static func parseBiz(_ raw: Any, now: Date) throws -> ProviderMetrics {
        guard let root = JSONBox.dictionary(raw) else { throw NetworkError.unparseable }
        guard let data = root.dict("data") else {
            throw AdapterError.emptyData(L10n.str("adapter.no_report_data"))
        }

        var metrics = ProviderMetrics(kind: .zhipu, fetchedAt: now)
        metrics.currency = "CNY"
        metrics.availableBalance = data.dec("availableBalance") ?? data.dec("balance")
        metrics.totalCredits = data.dec("rechargeAmount")
        metrics.cycleUsed = data.dec("totalSpendAmount")

        var parts: [String] = []
        if let give = data.dec("giveAmount"), give > 0 {
            parts.append(L10n.str("detail.granted", Money.short(give, currency: "CNY")))
        }
        if let frozen = data.dec("frozenBalance"), frozen > 0 {
            parts.append(L10n.str("detail.frozen", Money.short(frozen, currency: "CNY")))
        }
        if !parts.isEmpty { metrics.detailLines = parts }
        return metrics
    }
}
