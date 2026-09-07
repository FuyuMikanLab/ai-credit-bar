import Foundation

/// DeepSeek 官方余额接口。
/// GET https://api.deepseek.com/user/balance （Authorization: Bearer <key>）
/// 文档：https://api-docs.deepseek.com/api/get-user-balance/
struct DeepSeekAdapter: ProviderFetching {
    let kind = ProviderKind.deepseek
    private let path = "user/balance"

    func fetch(apiKey: String, baseURL: URL, now: Date) async throws -> ProviderMetrics {
        let url = try HTTP.makeURL(base: baseURL.absoluteString, path: path)
        let raw = try await HTTPClient.json(url: url, headers: HTTP.bearerHeaders(apiKey))
        return try Self.parse(raw, now: now)
    }

    static func parse(_ raw: Any, now: Date) throws -> ProviderMetrics {
        guard let root = JSONBox.dictionary(raw) else { throw NetworkError.unparseable }
        guard let infos = root.arr("balance_infos"), !infos.isEmpty else {
            throw AdapterError.emptyData(L10n.str("adapter.no_balance_infos"))
        }
        let dicts = infos.compactMap(JSONBox.dictionary)
        // 优先展示人民币账户
        let chosen = dicts.first { $0.str("currency") == "CNY" } ?? dicts.first
        guard let info = chosen else {
            throw AdapterError.emptyData(L10n.str("adapter.balance_infos_invalid"))
        }

        var metrics = ProviderMetrics(kind: .deepseek, fetchedAt: now)
        metrics.currency = info.str("currency") ?? "CNY"
        metrics.availableBalance = JSONBox.decimal(info["total_balance"])

        var parts: [String] = []
        if let granted = JSONBox.decimal(info["granted_balance"]) {
            parts.append(L10n.str("detail.granted", Money.short(granted, currency: metrics.currency)))
        }
        if let topped = JSONBox.decimal(info["topped_up_balance"]) {
            parts.append(L10n.str("detail.topped_up", Money.short(topped, currency: metrics.currency)))
        }
        if !parts.isEmpty { metrics.detailLines = [parts.joined(separator: " · ")] }
        return metrics
    }
}
