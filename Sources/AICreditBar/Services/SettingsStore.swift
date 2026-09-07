import Foundation
import Combine
import SwiftUI

/// 全局设置 + 各数据源 API Key（Key 在钥匙串，其余设置存 JSON 文件）。
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet { L10n.apply(settings.language) }
    }
    @Published private(set) var apiKeys: [ProviderKind: String] = [:]

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(AppIdentity.supportDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }

    init() {
        self.settings = Self.load()
        L10n.apply(settings.language) // didSet 在初始化时不触发，这里显式同步一次
        for kind in ProviderKind.allCases {
            if let key = KeychainStore.read(for: kind), !key.isEmpty {
                apiKeys[kind] = key
            }
        }
    }

    // MARK: API Key

    func apiKey(for kind: ProviderKind) -> String? { apiKeys[kind] }

    func hasAPIKey(for kind: ProviderKind) -> Bool {
        !(apiKeys[kind] ?? "").isEmpty
    }

    func saveAPIKey(_ key: String, for kind: ProviderKind) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainStore.save(trimmed, for: kind)
        apiKeys[kind] = trimmed
    }

    func clearAPIKey(for kind: ProviderKind) {
        KeychainStore.delete(for: kind)
        apiKeys[kind] = nil
    }

    // MARK: 设置读写

    func update(_ block: (inout AppSettings) -> Void) {
        var copy = settings
        block(&copy)
        settings = copy.mergingAllProviders()
        persist()
    }

    func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { newValue in
                var copy = self.settings
                copy[keyPath: keyPath] = newValue
                self.settings = copy.mergingAllProviders()
                self.persist()
            }
        )
    }

    func providerBinding(_ kind: ProviderKind, keyPath: WritableKeyPath<ProviderConfig, Bool>) -> Binding<Bool> {
        Binding(
            get: { self.settings.providerConfig(for: kind)?[keyPath: keyPath] ?? false },
            set: { newValue in
                self.update { settings in
                    guard let idx = settings.providers.firstIndex(where: { $0.kind == kind }) else { return }
                    settings.providers[idx][keyPath: keyPath] = newValue
                }
            }
        )
    }

    func providerBinding(_ kind: ProviderKind, keyPath: WritableKeyPath<ProviderConfig, String>) -> Binding<String> {
        Binding(
            get: { self.settings.providerConfig(for: kind)?[keyPath: keyPath] ?? "" },
            set: { newValue in
                self.update { settings in
                    guard let idx = settings.providers.firstIndex(where: { $0.kind == kind }) else { return }
                    settings.providers[idx][keyPath: keyPath] = newValue
                }
            }
        )
    }

    // MARK: 持久化

    private static func load() -> AppSettings {
        guard let data = try? Data(contentsOf: fileURL) else { return .default }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data).mergingAllProviders()
        } catch {
            NSLog("%@: 设置解析失败，使用默认值: %@", AppIdentity.name, error.localizedDescription)
            return .default
        }
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            NSLog("%@: 设置保存失败: %@", AppIdentity.name, error.localizedDescription)
        }
    }
}
