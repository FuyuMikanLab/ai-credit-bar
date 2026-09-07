import AppKit
import CoreText
import SwiftUI

/// 状态栏（菜单栏图标 + 可选文本）。
struct StatusBarView: View {
    @EnvironmentObject private var metrics: MetricsStore
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Image(nsImage: StatusBarArtwork.image(
            icon: artworkIcon,
            text: text
        ))
        .foregroundStyle(iconColor)
        .help(helpText)
    }

    private var artworkIcon: NSImage? {
        if let kind = selectedProvider {
            if let image = ProviderLogo.menuBarImage(for: kind) {
                return image
            }
            return StatusBarArtwork.symbolImage(named: kind.symbolName)
        }
        return StatusBarArtwork.symbolImage(named: genericIconName)
    }

    /// 选了“显示主数据源余额”且指定了厂商时，状态栏改用该厂商图标。
    private var selectedProvider: ProviderKind? {
        guard settings.settings.statusBarMode == .primaryBalance else { return nil }
        return settings.settings.primaryProviderID
    }

    private var failingCount: Int {
        metrics.snapshots.filter { snapshot in
            if case .failure = snapshot.state { return true }
            return false
        }.count
    }

    private var genericIconName: String {
        if failingCount > 0 { return "exclamationmark.triangle.fill" }
        return "chart.bar.fill"
    }

    private var iconColor: Color {
        failingCount > 0 ? .orange : Color.primary
    }

    private var helpText: String {
        if failingCount > 0 {
            return "\(AppIdentity.displayName) · " + L10n.plural("statusbar.failing_count", count: failingCount)
        }
        if let text {
            return "\(AppIdentity.displayName) · \(text)"
        }
        return AppIdentity.displayName
    }

    /// primaryBalance 模式下返回主数据源的余额文本。
    private var text: String? {
        guard settings.settings.statusBarMode == .primaryBalance,
              let kind = settings.settings.primaryProviderID,
              settings.hasAPIKey(for: kind),
              let snapshot = metrics.snapshots.first(where: { $0.config.kind == kind }),
              case .success(let m) = snapshot.state,
              let balance = m.availableBalance
        else { return nil }
        return Money.short(balance, currency: m.currency)
    }
}

/// 按菜单栏实际高度（约 22pt）绘制，图标与金额都在画布里垂直居中。
private enum StatusBarArtwork {
    private static let iconSide: CGFloat = ProviderLogo.menuBarPointSize
    private static let spacing: CGFloat = 6
    private static let fontSize: CGFloat = 12

    static func symbolImage(named name: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }

    static func image(icon: NSImage?, text: String?) -> NSImage {
        let font = statusBarFont()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let textWidth = text.map { ceil(($0 as NSString).size(withAttributes: attrs).width) } ?? 0
        let height = NSStatusBar.system.thickness
        let width = iconSide + (text == nil ? 0 : spacing + textWidth)
        let size = NSSize(width: max(width, iconSide), height: height)
        let scale: CGFloat = 2

        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int((size.width * scale).rounded()),
            pixelsHigh: Int((size.height * scale).rounded()),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high

        let iconRect = NSRect(
            x: 0,
            y: (height - iconSide) / 2,
            width: iconSide,
            height: iconSide
        )
        icon?.draw(
            in: iconRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )

        if let text, let ctx = NSGraphicsContext.current?.cgContext {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
            // 位图上下文原点在左下：让 cap-height 的中线落在画布中线。
            ctx.textMatrix = .identity
            ctx.textPosition = CGPoint(x: iconSide + spacing, y: (height - font.capHeight) / 2)
            CTLineDraw(line, ctx)
        }

        NSGraphicsContext.restoreGraphicsState()

        let output = NSImage(size: size)
        output.addRepresentation(rep)
        output.isTemplate = true
        return output
    }

    private static func statusBarFont() -> NSFont {
        let mono = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold)
        if let rounded = mono.fontDescriptor.withDesign(.rounded),
           let font = NSFont(descriptor: rounded, size: fontSize) {
            return font
        }
        return mono
    }
}
