import Foundation

/// Moonshot / Kimi 余额接口。
/// GET {base}/v1/users/me/balance （Authorization: Bearer <key>）
/// 文档：https://platform.kimi.ai/docs/api/balance.md
/// CN 站默认 base=https://api.moonshot.cn（人民币）；海外站 api.moonshot.ai 为美元。
struct MoonshotAdapter: ProviderFetching {
    let kind = ProviderKind.moonshot
    private let path = "v1/users/me/balance"

    func fetch(apiKey: String, baseURL: URL, now: Date) async throws -> ProviderMetrics {
        let url = try HTTP.makeURL(base: baseURL.absoluteString, path: path)
        let raw = try await HTTPClient.json(url: url, headers: HTTP.bearerHeaders(apiKey))
        return try Self.parse(raw, baseURL: baseURL, now: now)
    }

    static func parse(_ raw: Any, baseURL: URL, now: Date) throws -> ProviderMetrics {
        guard let root = JSONBox.dictionary(raw) else { throw NetworkError.unparseable }
        guard let data = root.dict("data") else {
            throw AdapterError.emptyData(L10n.str("adapter.no_data"))
        }

        let host = baseURL.host?.lowercased() ?? ""
        let currency = host.contains("moonshot.ai") ? "USD" : "CNY"

        var metrics = ProviderMetrics(kind: .moonshot, fetchedAt: now)
        metrics.currency = currency
        metrics.availableBalance = JSONBox.decimal(data["available_balance"])

        var parts: [String] = []
        if let voucher = JSONBox.decimal(data["voucher_balance"]) {
            parts.append(L10n.str("detail.granted", Money.short(voucher, currency: currency)))
        }
        if let cash = JSONBox.decimal(data["cash_balance"]) {
            parts.append(L10n.str("detail.cash", Money.short(cash, currency: currency)))
        }
        if !parts.isEmpty { metrics.detailLines = [parts.joined(separator: " · ")] }
        return metrics
    }
}
