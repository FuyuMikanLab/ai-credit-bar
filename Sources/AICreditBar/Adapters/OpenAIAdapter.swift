import Foundation

/// OpenAI 官方 Usage API（用量，非余额）。
/// GET https://api.openai.com/v1/organization/usage/completions
///     ?start_time=<unix>&end_time=<unix>&bucket_width=1d
/// 文档：https://developers.openai.com/api/reference/resources/admin/subresources/organization/subresources/usage
/// 注意：需要 Organization 管理员级 Key；普通项目 Key 通常返回 403/404。
struct OpenAIAdapter: ProviderFetching {
    let kind = ProviderKind.openai
    private static let path = "v1/organization/usage/completions"

    func fetch(apiKey: String, baseURL: URL, now: Date) async throws -> ProviderMetrics {
        guard let url = Self.usageURL(baseURL: baseURL, now: now) else {
            throw AdapterError.emptyData(L10n.str("adapter.bad_usage_url"))
        }
        let raw = try await HTTPClient.json(url: url, headers: HTTP.bearerHeaders(apiKey))
        return try Self.parse(raw, now: now)
    }

    /// 统计“本月（UTC）”的用量：输入/输出 token、请求次数。
    static func usageURL(baseURL: URL, now: Date) -> URL? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let comps = calendar.dateComponents([.year, .month], from: now)
        guard let monthStart = calendar.date(
            from: DateComponents(year: comps.year, month: comps.month, day: 1, hour: 0, minute: 0, second: 0)
        ) else { return nil }

        var url = baseURL
        url.appendPathComponent(Self.path)
        guard var comp = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        comp.queryItems = [
            URLQueryItem(name: "start_time", value: String(Int(monthStart.timeIntervalSince1970))),
            URLQueryItem(name: "end_time", value: String(Int(now.timeIntervalSince1970))),
            URLQueryItem(name: "bucket_width", value: "1d"),
        ]
        return comp.url
    }

    static func parse(_ raw: Any, now: Date) throws -> ProviderMetrics {
        guard let root = JSONBox.dictionary(raw) else { throw NetworkError.unparseable }
        guard let buckets = root.arr("data"), !buckets.isEmpty else {
            // 空数组 = 本月还没有任何用量，不算错误
            var empty = ProviderMetrics(kind: .openai, fetchedAt: now)
            empty.inputTokens = 0
            empty.outputTokens = 0
            empty.requests = 0
            return empty
        }

        var input: Int64 = 0
        var output: Int64 = 0
        var requests: Int64 = 0
        var sawAny = false

        for bucket in buckets {
            guard let bd = JSONBox.dictionary(bucket) else { continue }
            let results = bd.arr("results") ?? []
            for result in results {
                guard let rd = JSONBox.dictionary(result) else { continue }
                if let v = rd.int("input_tokens") { input += v; sawAny = true }
                if let v = rd.int("output_tokens") { output += v; sawAny = true }
                if let v = rd.int("num_model_requests") { requests += v; sawAny = true }
            }
        }

        var metrics = ProviderMetrics(kind: .openai, fetchedAt: now)
        metrics.inputTokens = input
        metrics.outputTokens = output
        metrics.requests = requests
        if !sawAny { metrics.detailLines = [L10n.str("adapter.no_usage_entries")] }
        return metrics
    }
}
