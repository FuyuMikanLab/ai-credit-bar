import Foundation

/// SiliconFlow（硅基流动）用户信息接口，含余额。
/// GET {base}/v1/user/info （Authorization: Bearer <key>）
/// 文档：https://docs.siliconflow.com/en/api-reference/userinfo/get-user-info
/// CN 站默认 base=https://api.siliconflow.cn（人民币）；海外站 api.siliconflow.com 为美元。
struct SiliconFlowAdapter: ProviderFetching {
    let kind = ProviderKind.siliconflow
    private let path = "v1/user/info"

    func fetch(apiKey: String, baseURL: URL, now: Date) async throws -> ProviderMetrics {
        let url = try HTTP.makeURL(base: baseURL.absoluteString, path: path)
        let raw = try await HTTPClient.json(url: url, headers: HTTP.bearerHeaders(apiKey))
        return try Self.parse(raw, baseURL: baseURL, now: now)
    }

    static func parse(_ raw: Any, baseURL: URL, now: Date) throws -> ProviderMetrics {
        guard let root = JSONBox.dictionary(raw) else { throw NetworkError.unparseable }

        let host = baseURL.host?.lowercased() ?? ""
        let currency = host.contains("siliconflow.com") && !host.contains("siliconflow.cn") ? "USD" : "CNY"

        var metrics = ProviderMetrics(kind: .siliconflow, fetchedAt: now)
        metrics.currency = currency

        // 新版 data.totalBalance / 旧版顶层 balance（个别字段为字符串）
        let balance = root.dict("data")?.dec("totalBalance")
            ?? root.dec("totalBalance")
            ?? root.dict("data")?.dec("balance")
            ?? root.dec("balance")
        guard let balance else {
            throw AdapterError.emptyData(L10n.str("adapter.no_balance_field"))
        }
        metrics.availableBalance = balance
        return metrics
    }
}
