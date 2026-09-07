import Foundation

/// 适配器注册表：所有可用数据源处理器都登记在这里。
/// 新增厂商时在这里补一行即可。
enum ProviderRegistry {
    static let all: [any ProviderFetching] = [
        DeepSeekAdapter(),
        MoonshotAdapter(),
        OpenRouterAdapter(),
        SiliconFlowAdapter(),
        OpenAIAdapter(),
        ZhipuAdapter(),
    ]

    static func adapter(for kind: ProviderKind) -> any ProviderFetching {
        all.first { $0.kind == kind } ?? all[0]
    }

    static var allKinds: [ProviderKind] { all.map(\.kind) }
}
