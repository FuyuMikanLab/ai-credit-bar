import Foundation
import Combine
import ServiceManagement
import SwiftUI

/// 登录时启动：以系统「登录项」为唯一真相来源（不写入 settings.json）。
///
/// 使用 macOS 13+ 的 `SMAppService.mainApp`。必须从打包后的 `.app` 运行才能注册；
/// `swift run` / 裸二进制会得到 `.notFound`，开关会禁用。
@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var needsApproval = false
    @Published private(set) var lastError: String?

    /// 是否从 `.app` 包启动（命令行可执行文件无法登记登录项）。
    var canRegister: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    var binding: Binding<Bool> {
        Binding(
            get: { self.isEnabled },
            set: { self.setEnabled($0) }
        )
    }

    init() {
        refresh()
    }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true
            needsApproval = false
        case .requiresApproval:
            isEnabled = true
            needsApproval = true
        default:
            isEnabled = false
            needsApproval = false
        }
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        guard canRegister else {
            refresh()
            return
        }
        let status = SMAppService.mainApp.status
        do {
            if enabled {
                if status != .enabled && status != .requiresApproval {
                    try SMAppService.mainApp.register()
                }
            } else if status != .notRegistered && status != .notFound {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
