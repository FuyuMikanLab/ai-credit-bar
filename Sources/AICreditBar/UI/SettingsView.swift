import SwiftUI

/// 设置窗口（⌘, 或面板里的“设置”打开）。
/// 说明：macOS 分组表单每行自带分隔线，代码里不要再加 Divider()，否则会出现双线“条纹”。
struct SettingsView: View {
    @EnvironmentObject private var metrics: MetricsStore
    @EnvironmentObject private var store: SettingsStore
    @StateObject private var launchAtLogin = LaunchAtLogin()

    var body: some View {
        Form {
            Section {
                Picker(L10n.str("settings.language"), selection: store.binding(\.language)) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)

                Toggle(L10n.str("settings.launch_at_login"), isOn: launchAtLogin.binding)
                    .disabled(!launchAtLogin.canRegister)

                if launchAtLogin.needsApproval {
                    Button(L10n.str("settings.launch_at_login_open_system"), action: launchAtLogin.openSystemSettings)
                        .font(.system(size: 12))
                }
            } header: {
                Text(L10n.str("settings.section_general"))
            } footer: {
                Text(launchAtLoginFooter)
            }

            Section {
                Toggle(L10n.str("settings.auto_refresh"), isOn: store.binding(\.autoRefresh))

                Picker(L10n.str("settings.refresh_interval"), selection: store.binding(\.refreshMinutes)) {
                    ForEach([1, 3, 5, 10, 15, 30, 60], id: \.self) { minutes in
                        Text(L10n.plural("common.every_n_minutes", count: minutes)).tag(minutes)
                    }
                }
                .disabled(!store.settings.autoRefresh)
                .pickerStyle(.menu)
            } header: {
                Text(L10n.str("settings.section_refresh"))
            } footer: {
                Text(L10n.str("settings.refresh_footer"))
            }

            Section {
                Picker(L10n.str("settings.status_bar_display"), selection: store.binding(\.statusBarMode)) {
                    ForEach(StatusBarMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                if store.settings.statusBarMode == .primaryBalance {
                    Picker(L10n.str("settings.display_balance"), selection: store.binding(\.primaryProviderID)) {
                        Text(L10n.str("settings.no_text")).tag(ProviderKind?.none)
                        ForEach(eligiblePrimaryKinds) { kind in
                            Text(kind.displayName).tag(Optional(kind))
                        }
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                Text(L10n.str("settings.section_status_bar"))
            } footer: {
                Text(L10n.str("settings.status_bar_footer"))
            }

            Section {
                ForEach(ProviderKind.allCases) { kind in
                    ProviderSettingsRow(
                        store: store,
                        kind: kind,
                        onSaved: { metrics.refresh(kind) }
                    )
                }
            } header: {
                Text(L10n.str("settings.section_providers"))
            } footer: {
                Text(L10n.str("settings.providers_footer"))
            }

            Section {
                HStack(spacing: 10) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppIdentity.displayName)
                            .font(.system(size: 13, weight: .semibold))
                        Text(L10n.str("settings.tagline"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(AppIdentity.version)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .padding(.vertical, 2)

                aboutRow(L10n.str("settings.about_data_source"), L10n.str("settings.about_data_source_value"))
                aboutRow(L10n.str("settings.about_balance"), L10n.str("settings.about_balance_value"))
                aboutRow(L10n.str("settings.about_privacy"), L10n.str("settings.about_privacy_value"))
                aboutRow(L10n.str("settings.about_contact_us"), L10n.str("settings.about_contact_us_value"))
            } header: {
                Text(L10n.str("settings.section_about"))
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 640)
        .navigationTitle(L10n.str("settings.nav_title", AppIdentity.displayName))
        .onAppear { launchAtLogin.refresh() }
    }

    private var launchAtLoginFooter: String {
        if launchAtLogin.needsApproval {
            return L10n.str("settings.launch_at_login_needs_approval")
        }
        if let error = launchAtLogin.lastError {
            return L10n.str("settings.launch_at_login_failed", error)
        }
        return L10n.str("settings.launch_at_login_footer")
    }

    private var eligiblePrimaryKinds: [ProviderKind] {
        store.settings.enabledProviders
            .filter { store.hasAPIKey(for: $0.kind) }
            .map(\.kind)
    }

    private func aboutRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}
