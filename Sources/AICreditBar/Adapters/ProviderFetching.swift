import Foundation

/// 一个数据源的“处理器”：负责调用某家厂商的接口，
/// 并把原始响应归一化成统一的 ProviderMetrics。
///
/// 新增厂商的步骤：
/// 1. ProviderKind 增加一个 case（含默认地址/名称等元信息）；
/// 2. 新建一个实现本协议的结构体，实现 fetch/parse；
/// 3. 在 ProviderRegistry.all 里登记一行。
protocol ProviderFetching {
    var kind: ProviderKind { get }
    func fetch(apiKey: String, baseURL: URL, now: Date) async throws -> ProviderMetrics
}

enum AdapterError: LocalizedError {
    case emptyData(String)

    var errorDescription: String? {
        switch self {
        case .emptyData(let reason): return reason
        }
    }
}
