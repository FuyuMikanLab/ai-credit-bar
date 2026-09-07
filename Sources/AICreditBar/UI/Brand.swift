import SwiftUI

extension ProviderKind {
    var brandColor: Color {
        switch self {
        case .deepseek: return Color(red: 0.30, green: 0.42, blue: 1.0)
        case .moonshot: return Color(red: 0.55, green: 0.35, blue: 0.95)
        case .openrouter: return Color(red: 0.15, green: 0.72, blue: 0.68)
        case .siliconflow: return Color(red: 0.25, green: 0.53, blue: 0.95)
        case .openai: return Color(red: 0.06, green: 0.64, blue: 0.50)
        case .zhipu: return Color(red: 0.95, green: 0.45, blue: 0.10)
        }
    }
}

/// 面板和设置页共用的品牌小圆标。有 Logo 文件时用图片，否则回退 SF Symbol。
struct BrandMark: View {
    let kind: ProviderKind
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .fill(kind.brandColor.opacity(0.16))
                .frame(width: size, height: size)
            if let logo = ProviderLogo.nsImage(for: kind) {
                Image(nsImage: logo)
                    .resizable()
                    .interpolation(.high)
                    .renderingMode(ProviderLogo.isTemplate(for: kind) ? .template : .original)
                    .scaledToFit()
                    .frame(width: size * 0.62, height: size * 0.62)
                    .foregroundStyle(kind.brandColor)
            } else {
                Image(systemName: kind.symbolName)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(kind.brandColor)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 次要状态胶囊（未配置 / 已保存 等）。
struct StatusCapsule: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.14), in: Capsule())
    }
}
