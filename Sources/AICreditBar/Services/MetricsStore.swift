import Foundation
import Combine

/// 负责驱动所有数据源的拉取：并发请求、定时刷新、结果快照。
final class MetricsStore: ObservableObject {
    @Published private(set) var snapshots: [ProviderSnapshot] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastCompletedRefresh: Date?

    private let settingsStore: SettingsStore
    private var timer: Timer?
    private var running = false
    private var generation = 0
    private var cancellables: Set<AnyCancellable> = []
    private var didScheduleStart = false

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        rebuildSnapshots()

        settingsStore.$settings
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.settingsDidChange()
            }
            .store(in: &cancellables)

        // 等 App 完全起来后再做首次刷新。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.start()
        }
    }

    // MARK: - 生命周期

    func start() {
        guard !didScheduleStart else { return }
        didScheduleStart = true
        scheduleTimer()
        if hasAnyKeyConfigured, lastCompletedRefresh == nil {
            refreshAll()
        }
    }

    /// 弹出面板时调用：太久没更新就顺手刷一次。
    func openPanelIfNeeded() {
        let staleInterval = TimeInterval(max(settingsStore.settings.refreshMinutes * 60, 30))
        if let last = lastCompletedRefresh, Date().timeIntervalSince(last) < staleInterval {
            return
        }
        if lastCompletedRefresh == nil || Date().timeIntervalSince(lastCompletedRefresh ?? .distantPast) >= staleInterval {
            if !running {
                refreshAll()
            }
        }
    }

    // MARK: - 刷新入口

    func refreshAll() {
        refresh(providers: settingsStore.settings.enabledProviders)
    }

    func refresh(_ kind: ProviderKind) {
        guard let config = settingsStore.settings.providerConfig(for: kind), config.isEnabled else { return }
        refresh(providers: [config])
    }

    private func refresh(providers: [ProviderConfig]) {
        guard !providers.isEmpty else { return }
        guard !running else { return }
        running = true
        let gen = generation
        DispatchQueue.main.async { [weak self] in
            self?.isRefreshing = true
        }
        Task {
            await self.performFetch(providers: providers, generation: gen)
        }
    }

    /// 面板或设置页里的“测试连接”也用同一套抓取逻辑。
    /// `keyStore` 必传：自动/手动刷新从这里读取已保存的 Key；
    /// `apiKey` 仅用于“测试连接”时显式传一个临时 Key（优先于钥匙串）。
    static func fetchOnce(config: ProviderConfig, keyStore: SettingsStore, apiKey: String? = nil) async throws -> ProviderMetrics {
        let key: String?
        if let apiKey, !apiKey.isEmpty {
            key = apiKey
        } else {
            key = keyStore.apiKey(for: config.kind)
        }
        guard let key, !key.isEmpty else {
            throw AdapterError.emptyData(L10n.str("error.no_api_key"))
        }
        let baseString = config.resolvedBaseURLString()
        let withScheme = baseString.hasPrefix("http://") || baseString.hasPrefix("https://")
            ? baseString : "https://" + baseString
        guard let base = URL(string: withScheme) else {
            throw AdapterError.emptyData(L10n.str("error.invalid_base_url", baseString))
        }
        let adapter = ProviderRegistry.adapter(for: config.kind)
        return try await adapter.fetch(apiKey: key, baseURL: base, now: Date())
    }

    // MARK: - 内部实现

    private func performFetch(providers: [ProviderConfig], generation gen: Int) async {
        var updated: [ProviderKind: ProviderLoadState] = [:]

        // 这里必须把 keyStore 一起带进去：定时/手动刷新要从钥匙串读取已保存的 API Key。
        let keyStore = settingsStore
        await withTaskGroup(of: (ProviderKind, ProviderLoadState).self) { group in
            for config in providers {
                group.addTask {
                    do {
                        let metrics = try await MetricsStore.fetchOnce(config: config, keyStore: keyStore)
                        return (config.kind, .success(metrics))
                    } catch {
                        return (config.kind, .failure(error.localizedDescription))
                    }
                }
            }
            for await pair in group {
                updated[pair.0] = pair.1
            }
        }

        guard gen == self.generation else { return } // 期间设置变了，丢弃这轮结果
        let finalUpdated = updated
        await MainActor.run {
            for (kind, state) in finalUpdated {
                guard let idx = self.snapshots.firstIndex(where: { $0.config.kind == kind }) else { continue }
                self.snapshots[idx].state = state
            }
            self.isRefreshing = false
            self.running = false
            self.lastCompletedRefresh = Date()
        }
    }

    private func settingsDidChange() {
        rebuildSnapshots()
        scheduleTimer()
    }

    private func rebuildSnapshots() {
        let enabled = Set(settingsStore.settings.enabledProviders.map(\.kind))
        var existing: [ProviderKind: ProviderSnapshot] = [:]
        for snap in snapshots { existing[snap.config.kind] = snap }

        var rebuilt: [ProviderSnapshot] = []
        for kind in ProviderKind.allCases where enabled.contains(kind) {
            let config = settingsStore.settings.providerConfig(for: kind) ?? ProviderConfig(kind: kind)
            if var snap = existing[kind] {
                snap.config = config
                rebuilt.append(snap)
            } else {
                rebuilt.append(ProviderSnapshot(config: config))
            }
        }
        snapshots = rebuilt
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = nil
        guard settingsStore.settings.autoRefresh else { return }
        let interval = TimeInterval(max(settingsStore.settings.refreshMinutes, 1) * 60)
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshAll()
        }
        t.tolerance = interval * 0.1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private var hasAnyKeyConfigured: Bool {
        settingsStore.settings.enabledProviders.contains { settingsStore.hasAPIKey(for: $0.kind) }
    }
}
