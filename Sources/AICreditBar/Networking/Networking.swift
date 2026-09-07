import Foundation

// MARK: - 网络错误

enum NetworkError: LocalizedError {
    case transport(String)
    case badStatus(Int, String?)
    case badResponse
    case unparseable

    var errorDescription: String? {
        switch self {
        case .transport(let detail):
            return L10n.str("net.error_transport", detail)
        case .badStatus(let code, let message):
            if let message, !message.isEmpty {
                return L10n.str("net.http_status_message", code, message)
            }
            return L10n.str("net.http_status", code)
        case .badResponse:
            return L10n.str("net.bad_response")
        case .unparseable:
            return L10n.str("net.unparseable")
        }
    }
}

// MARK: - 轻量 HTTP 客户端

enum HTTPClient {
    static func json(method: String = "GET",
                     url: URL,
                     headers: [String: String] = [:],
                     timeout: TimeInterval = 25) async throws -> Any {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw NetworkError.transport(urlerrorMessage(error))
        } catch {
            throw NetworkError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = Self.errorMessage(from: data)
            throw NetworkError.badStatus(http.statusCode, message)
        }

        do {
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw NetworkError.unparseable
        }
    }

    /// 从错误响应体里提取服务端给出的错误描述（尽力而为）。
    private static func errorMessage(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (text?.isEmpty == false && (text?.count ?? 0) < 300) ? text : nil
        }
        if let error = obj["error"] as? [String: Any],
           let m = error["message"] as? String, !m.isEmpty { return m }
        if let e = obj["error"] as? String, !e.isEmpty { return e }
        for key in ["message", "msg", "detail", "error_description", "reason"] {
            if let s = obj[key] as? String, !s.isEmpty { return s }
        }
        return nil
    }

    private static func urlerrorMessage(_ error: URLError) -> String {
        switch error.code {
        case .timedOut: return L10n.str("net.timeout")
        case .notConnectedToInternet: return L10n.str("net.no_internet")
        case .cannotConnectToHost: return L10n.str("net.cannot_connect")
        case .cannotFindHost, .dnsLookupFailed: return L10n.str("net.cannot_resolve")
        case .secureConnectionFailed, .serverCertificateUntrusted: return L10n.str("net.ssl_failed")
        default: return error.localizedDescription
        }
    }
}

// MARK: - 容错的 JSON 取值

/// 面对各家 API 千奇百怪的字段形态，统一用“容忍式”取数，
/// 数字可能是 number 也可能是 string，字段名可能变，都尽量兜住。
enum JSONBox {
    static func dictionary(_ v: Any?) -> [String: Any]? { v as? [String: Any] }
    static func array(_ v: Any?) -> [Any]? { v as? [Any] }

    static func string(_ v: Any?) -> String? {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return nil
    }

    static func double(_ v: Any?) -> Double? {
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String, let d = Double(s) { return d }
        return nil
    }

    static func int(_ v: Any?) -> Int64? {
        if let n = v as? NSNumber { return n.int64Value }
        if let s = v as? String, let i = Int64(s) { return i }
        return nil
    }

    /// 金额统一转成 Decimal（数字可能以字符串下发，例如 DeepSeek 的 "110.00"）。
    static func decimal(_ v: Any?) -> Decimal? {
        if let s = v as? String { return Decimal(string: s.trimmingCharacters(in: .whitespaces)) }
        if let n = v as? NSNumber {
            let str = String(format: "%.10f", n.doubleValue)
            return Decimal(string: str)
        }
        return nil
    }
}

extension Dictionary where Key == String, Value == Any {
    /// 按路径逐层取（中间只走字典），例如 value("data", "total_credits")。
    func value(_ path: String...) -> Any? { value(paths: path) }

    func value(paths: [String]) -> Any? {
        var current: Any? = self
        for key in paths {
            guard let dict = current as? [String: Any] else { return nil }
            current = dict[key]
        }
        return current
    }

    func str(_ path: String...) -> String? { JSONBox.string(value(paths: path)) }
    func dbl(_ path: String...) -> Double? { JSONBox.double(value(paths: path)) }
    func int(_ path: String...) -> Int64? { JSONBox.int(value(paths: path)) }
    func dec(_ path: String...) -> Decimal? { JSONBox.decimal(value(paths: path)) }
    func dict(_ path: String...) -> [String: Any]? { JSONBox.dictionary(value(paths: path)) }
    func arr(_ path: String...) -> [Any]? { JSONBox.array(value(paths: path)) }
}

// MARK: - URL / Header 小工具

enum HTTP {
    /// 拼接子路径并做基本清洗。
    static func makeURL(base: String, path: String) throws -> URL {
        var clean = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.hasPrefix("http://") && !clean.hasPrefix("https://") {
            clean = "https://" + clean
        }
        guard var url = URL(string: clean) else { throw NetworkError.badResponse }
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        url.appendPathComponent(trimmedPath)
        return url
    }

    static func bearerHeaders(_ key: String) -> [String: String] {
        ["Authorization": "Bearer \(key)", "Accept": "application/json"]
    }

    /// 智谱 bigmodel.cn 的某些接口要求原始 Key（不带 Bearer 前缀）。
    static func rawKeyHeaders(_ key: String) -> [String: String] {
        ["Authorization": key, "Accept": "application/json"]
    }
}
