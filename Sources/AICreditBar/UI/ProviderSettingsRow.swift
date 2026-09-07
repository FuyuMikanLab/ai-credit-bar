import SwiftUI

/// “测试连接”的即时状态。
enum ConnectionTestState: Equatable {
    case idle
    case running
    case success(ProviderMetrics)
    case failure(String)
}

/// 设置页数据源行：开关、名称、Key 管理、测试连接。
struct ProviderSettingsRow: View {
    @ObservedObject var store: SettingsStore
    let kind: ProviderKind
    var onSaved: () -> Void = {}

    @State private var keyInput = ""
    @State private var testState: ConnectionTestState = .idle

    private var isEnabled: Bool {
        store.settings.providerConfig(for: kind)?.isEnabled ?? true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow

            if isEnabled {
                fields
                statusLine
                hintText
            } else {
                Text(L10n.str("settings.provider_disabled"))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
        .onDisappear { keyInput = "" }
    }

    // MARK: 头部

    private var headerRow: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: store.providerBinding(kind, keyPath: \.isEnabled))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)

            BrandMark(kind: kind)
                .opacity(isEnabled ? 1 : 0.45)

            Text(kind.displayName)
                .font(.system(size: 13, weight: .semibold))
                .opacity(isEnabled ? 1 : 0.55)

            if let url = kind.consoleURL {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .help(L10n.str("settings.open_console", kind.displayName))
            }

            Spacer()

            if store.hasAPIKey(for: kind) {
                StatusCapsule(text: L10n.str("settings.key_saved"), color: .green)
            } else {
                StatusCapsule(text: L10n.str("settings.key_not_set"))
            }
        }
    }

    // MARK: 表单

    private var fields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                fieldLabel(L10n.str("settings.display_name"))
                TextField(L10n.str("settings.display_name_placeholder", kind.displayName), text: store.providerBinding(kind, keyPath: \.displayNameOverride))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .controlSize(.small)
            }

            HStack(spacing: 8) {
                fieldLabel(L10n.str("settings.api_key"))
                SecureField(L10n.str("settings.key_stored_in_keychain"), text: $keyInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .controlSize(.small)
                    .disabled(testState == .running)

                Button(L10n.str("common.save"), action: saveKey)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || testState == .running)

                Button(testStateLabel, action: runTest)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(testState == .running)
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(width: 56, alignment: .leading)
    }

    // MARK: 状态行

    @ViewBuilder
    private var statusLine: some View {
        switch testState {
        case .idle:
            Text(kind.capabilityText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        case .running:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text(L10n.str("settings.connecting", kind.displayName))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .success(let m):
            VStack(alignment: .leading, spacing: 4) {
                resultBanner(successMessage(m), color: .green, symbol: "checkmark.circle.fill")
                Text(kind.capabilityText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        case .failure(let message):
            VStack(alignment: .leading, spacing: 4) {
                resultBanner(L10n.str("settings.test_failed", message), color: .orange, symbol: "exclamationmark.triangle.fill")
                Text(kind.capabilityText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func resultBanner(_ text: String, color: Color, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 11))
                .textSelection(.enabled)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func successMessage(_ m: ProviderMetrics) -> String {
        var parts: [String] = []
        if let balance = m.availableBalance, let currency = m.currency {
            parts.append(L10n.str("settings.available_balance", Money.two(balance, currency: currency)))
        }
        if let input = m.inputTokens, let output = m.outputTokens {
            parts.append(L10n.str("row.tokens_io", Fmt.grouped(input), Fmt.grouped(output)))
        }
        if parts.isEmpty { parts.append(L10n.str("settings.connection_ok")) }
        return parts.joined(separator: " · ")
    }

    private var testStateLabel: String {
        testState == .running ? L10n.str("settings.testing") : L10n.str("common.test")
    }

    // MARK: 提示

    @ViewBuilder
    private var hintText: some View {
        if store.hasAPIKey(for: kind) {
            HStack(spacing: 8) {
                Text(L10n.str("settings.key_saved_hint"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 8)
                Button(L10n.str("settings.clear_key"), action: clearKey)
                    .font(.system(size: 11))
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .help(L10n.str("settings.clear_key_help", kind.displayName))
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(kind.setupHint)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                if let url = kind.consoleURL {
                    Link(L10n.str("settings.create_key"), destination: url)
                        .font(.system(size: 10.5))
                }
            }
        }
    }

    // MARK: 动作

    private func saveKey() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.saveAPIKey(trimmed, for: kind)
        keyInput = ""
        onSaved()
    }

    private func clearKey() {
        store.clearAPIKey(for: kind)
        keyInput = ""
        testState = .idle
        onSaved()
    }

    private func runTest() {
        let typed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyToTest = typed.isEmpty ? (store.apiKey(for: kind) ?? "") : typed
        guard !keyToTest.isEmpty else {
            testState = .failure(L10n.str("settings.enter_key_first"))
            return
        }
        if !typed.isEmpty {
            store.saveAPIKey(typed, for: kind)
            keyInput = ""
            onSaved()
        }
        let config = ProviderConfig(
            kind: kind,
            isEnabled: true,
            displayNameOverride: store.settings.providerConfig(for: kind)?.displayNameOverride ?? "",
            baseURLString: store.settings.providerConfig(for: kind)?.baseURLString ?? ""
        )
        testState = .running
        Task {
            do {
                let m = try await MetricsStore.fetchOnce(config: config, keyStore: store, apiKey: keyToTest)
                await MainActor.run { self.testState = .success(m) }
            } catch {
                await MainActor.run { self.testState = .failure(error.localizedDescription) }
            }
        }
    }
}
