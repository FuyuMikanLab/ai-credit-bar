import Foundation

/// OpenRouter 额度接口。
/// GET https://openrouter.ai/api/v1/credits
/// 返回 { data: { total_credits(总充值), total_usage(本周期已用) } }
/// 可用额度 = total_credits − total_usage（美元）。
struct OpenRouterAdapter: ProviderFetching {
    let kind = ProviderKind.openrouter
    private let path = "api/v1/credits"

    func fetch(apiKey: String, baseURL: URL, now: Date) async throws -> ProviderMetrics {
        let url = try HTTP.makeURL(base: baseURL.absoluteString, path: path)
        let raw = try await HTTPClient.json(url: url, headers: HTTP.bearerHeaders(apiKey))
        return try Self.parse(raw, now: now)
    }

    static func parse(_ raw: Any, now: Date) throws -> ProviderMetrics {
        guard let root = JSONBox.dictionary(raw) else { throw NetworkError.unparseable }
        // 新版包在 data 里；老版字段在根上，都兼容。
        let container = root.dict("data") ?? root

        var metrics = ProviderMetrics(kind: .openrouter, fetchedAt: now)
        metrics.currency = "USD"
        let purchased = container.dec("total_credits") ?? container.dec("total_credit")
        let used = container.dec("total_usage")

        if let purchased {
            metrics.totalCredits = purchased
            if let used {
                metrics.cycleUsed = used
                metrics.availableBalance = max(purchased - used, 0)
            } else {
                metrics.availableBalance = purchased
            }
        } else if let used {
            metrics.cycleUsed = used
            // 只剩 used 时至少给出一个可展示的数值
            metrics.availableBalance = nil
            metrics.detailLines = [L10n.str("detail.month_used", Money.short(used, currency: "USD"))]
        } else {
            throw AdapterError.emptyData(L10n.str("adapter.no_credits"))
        }
        return metrics
    }
}
