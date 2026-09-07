import SwiftUI
import AppKit

/// 面板里单个数据源的一行卡片。
struct ProviderRowView: View {
    let snapshot: ProviderSnapshot
    let hasKey: Bool
    let onRefresh: () -> Void

    @State private var isHovering = false

    private var kind: ProviderKind { snapshot.config.kind }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            BrandMark(kind: kind)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(snapshot.config.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if !hasKey {
                        StatusCapsule(text: L10n.str("row.no_key"))
                    }
                }
                caption
                    .font(.system(size: 11))
                    .foregroundStyle(captionColor)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            HStack(alignment: .center, spacing: 8) {
                trailingMetric
                    .layoutPriority(1)

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .opacity(isHovering ? 1 : 0)
                .help(L10n.str("row.refresh_provider", snapshot.config.displayName))
                .disabled(!hasKey)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cardFill)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(L10n.str("row.refresh"), action: onRefresh)
            if let url = kind.consoleURL {
                Button(L10n.str("row.open_console")) { NSWorkspace.shared.open(url) }
            }
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }

    // MARK: - 组成

    @ViewBuilder
    private var caption: some View {
        switch snapshot.state {
        case .idle:
            Text(hasKey ? L10n.str("common.not_refreshed_yet") : L10n.str("row.fill_key_hint"))
        case .loading:
            Text(L10n.str("row.fetching"))
        case .success(let m):
            let text = successCaption(for: m)
            Text(text.isEmpty ? L10n.str("row.empty_data") : text)
        case .failure(let message):
            Text(message)
        }
    }

    private var captionColor: Color {
        if case .failure = snapshot.state { return .red }
        return .secondary
    }

    @ViewBuilder
    private var trailingMetric: some View {
        switch snapshot.state {
        case .success(let m):
            if let balance = m.availableBalance, let currency = m.currency {
                metricBlock(Money.two(balance, currency: currency), caption: L10n.str("row.available_balance"))
            } else if let total = m.totalTokens {
                metricBlock(Fmt.groupedTokens(total), caption: L10n.str("row.month_tokens"))
            }
        case .failure:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
        case .loading:
            ProgressView()
                .controlSize(.mini)
        default:
            EmptyView()
        }
    }

    private func metricBlock(_ value: String, caption: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(caption)
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
        }
    }

    private var cardFill: Color {
        if case .failure = snapshot.state {
            return Color.orange.opacity(isHovering ? 0.14 : 0.10)
        }
        return Color.primary.opacity(isHovering ? 0.07 : 0.045)
    }

    // MARK: - 文案组装

    private func successCaption(for m: ProviderMetrics) -> String {
        var parts = composeLines(for: m)
        parts.append(L10n.str("row.updated_at", Fmt.relative(m.fetchedAt)))
        return parts.joined(separator: " · ")
    }

    private func composeLines(for m: ProviderMetrics) -> [String] {
        var lines: [String] = []
        if let used = m.cycleUsed, used != 0 {
            lines.append(L10n.str("row.cycle_used", Money.two(used, currency: m.currency)))
        }
        if let input = m.inputTokens, let output = m.outputTokens {
            lines.append(L10n.str("row.tokens_io", Fmt.grouped(input), Fmt.grouped(output)))
        }
        if let requests = m.requests, requests > 0 {
            lines.append(L10n.str("row.requests", Fmt.grouped(requests)))
        }
        lines.append(contentsOf: m.detailLines)
        return lines
    }
}
