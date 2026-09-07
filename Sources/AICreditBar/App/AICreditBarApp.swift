import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 纯菜单栏工具：不占 Dock。
        NSApp.setActivationPolicy(.accessory)
    }
}

/// 命令行入口：`AICreditBar --selftest` 走离线自测，否则正常启动 GUI。
@main
enum AICreditBarMain {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--selftest") {
            SelfTest.run()
            exit(0)
        }
        AICreditBarApp.main()
    }
}

@MainActor
struct AICreditBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var metricsStore: MetricsStore

    init() {
        let settings = SettingsStore()
        _settingsStore = StateObject(wrappedValue: settings)
        _metricsStore = StateObject(wrappedValue: MetricsStore(settingsStore: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView()
                .environmentObject(metricsStore)
                .environmentObject(settingsStore)
        } label: {
            StatusBarView()
                .environmentObject(metricsStore)
                .environmentObject(settingsStore)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(metricsStore)
                .environmentObject(settingsStore)
        }
    }
}
