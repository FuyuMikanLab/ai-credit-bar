/// 应用身份：Swift 侧只改这里。
///
/// - `name`：给机器用（SPM target、.app 文件名、设置目录）。必须是 ASCII，且与 Package.swift 一致
/// - `displayName`：给人看（面板标题、设置、菜单栏提示）。跟语言走，改 `Locales/*.json` 的 `app.display_name`
/// - `id`：短标识。Bundle ID / 钥匙串走 `bundleIdentifier`，改展示名也不动
/// - `version`：唯一版本号。Info.plist 不能引用 Swift 变量，由 `scripts/build-app.sh` 写入 .app
enum AppIdentity {
    static let name = "AICreditBar"
    static let version = "0.1.1"

    /// 稳定短标识。不要从 `name` 推导。
    static let id = "aicreditbar"

    /// 反向域名，与 GitHub 组织 `fuyumikanlab` 对齐；打包脚本和 Info.plist 都读这里。
    static let bundleIdentifier = "com.fuyumikanlab.aicreditbar"

    static var displayName: String { L10n.str("app.display_name") }

    static var keychainService: String { bundleIdentifier }
    static var supportDirectoryName: String { name }
}
