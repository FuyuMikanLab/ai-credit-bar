import SwiftUI
import AppKit

/// 点击菜单栏后弹出的面板：列出所有已启用数据源的状态。
struct MenuPanelView: View {
    @EnvironmentObject private var metrics: MetricsStore
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 380)
        .onAppear {
            metrics.openPanelIfNeeded()
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppIdentity.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Text(headerSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(failingCount > 0 ? Color.orange : Color.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                metrics.refreshAll()
            } label: {
                if metrics.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 16, height: 16)
                }
            }
            .buttonStyle(.borderless)
            .disabled(metrics.isRefreshing)
            .help(L10n.str("panel.refresh_all"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var headerSubtitle: String {
        if failingCount > 0 {
            return L10n.plural("panel.failing_count", count: failingCount)
        }
        if metrics.isRefreshing, metrics.lastCompletedRefresh == nil {
            return L10n.str("panel.refreshing")
        }
        if let last = metrics.lastCompletedRefresh {
            if settings.settings.autoRefresh {
                let every = L10n.plural("common.every_n_minutes", count: settings.settings.refreshMinutes)
                return L10n.str("panel.last_refresh", Fmt.time(last)) + " · " + every
            }
            return L10n.str("panel.last_refresh", Fmt.time(last))
        }
        return L10n.str("common.not_refreshed_yet")
    }

    private var failingCount: Int {
        metrics.snapshots.filter { snapshot in
            if case .failure = snapshot.state { return true }
            return false
        }.count
    }

    // MARK: - 列表

    @ViewBuilder
    private var content: some View {
        if settings.settings.enabledProviders.isEmpty {
            emptyHint(
                symbol: "switch.2",
                title: L10n.str("panel.empty_providers_title"),
                detail: L10n.str("panel.empty_providers_detail")
            )
        } else if !hasAnyKey {
            VStack(spacing: 12) {
                emptyHint(
                    symbol: "key.fill",
                    title: L10n.str("panel.waiting_key_title"),
                    detail: L10n.str("panel.waiting_key_detail")
                )
                SettingsLink {
                    Label(L10n.str("common.open_settings"), systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.bottom, 20)
        } else if metrics.snapshots.isEmpty {
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.str("panel.fetching"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(L10n.str("panel.fetching_detail"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)
                .padding(.horizontal, 24)
                SettingsLink {
                    Label(L10n.str("common.open_settings"), systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.bottom, 20)
        } else {
            // 不用 ScrollView：MenuBarExtra .window 在本机版本下 ScrollView 内容不渲染。
            VStack(spacing: 6) {
                ForEach(metrics.snapshots) { snapshot in
                    ProviderRowView(
                        snapshot: snapshot,
                        hasKey: settings.hasAPIKey(for: snapshot.config.kind),
                        onRefresh: { metrics.refresh(snapshot.config.kind) }
                    )
                }
            }
            .padding(10)
        }
    }

    private func emptyHint(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
        .padding(.horizontal, 24)
    }

    private var hasAnyKey: Bool {
        settings.settings.enabledProviders.contains { settings.hasAPIKey(for: $0.kind) }
    }

    // MARK: - 底部

    private var footer: some View {
        HStack(spacing: 8) {
            SettingsLink {
                Label(L10n.str("common.settings"), systemImage: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)

            Spacer()

            Button(L10n.str("common.quit")) {
                NSApp.terminate(nil)
            }
            .font(.system(size: 12))
            .buttonStyle(.borderless)
            .help(L10n.str("common.quit_app", AppIdentity.displayName))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
