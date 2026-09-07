import AppKit
import SwiftUI

/// 从 `Resources/ProviderLogos/` 读取厂商 Logo。
/// 文件名 = `ProviderKind.rawValue`；扩展名按 `.pdf` → `.png` / `@2x.png` → `.svg` 查找。
enum ProviderLogo {
    static let menuBarPointSize: CGFloat = 18

    private static let directory = "ProviderLogos"
    private static var imageCache: [String: NSImage] = [:]
    private static var menuBarCache: [String: NSImage] = [:]
    private static var templateKeys: Set<String> = []

    static func nsImage(for kind: ProviderKind) -> NSImage? {
        let name = kind.logoResourceName
        if let cached = imageCache[name] { return cached }
        guard let loaded = loadImage(named: name) else { return nil }
        imageCache[name] = loaded
        return loaded
    }

    static func isTemplate(for kind: ProviderKind) -> Bool {
        _ = nsImage(for: kind)
        return templateKeys.contains(kind.logoResourceName)
    }

    /// 菜单栏用：裁掉透明边后居中铺进 18pt 方框，避免比系统图标更小或偏上。
    static func menuBarImage(for kind: ProviderKind) -> NSImage? {
        let name = kind.logoResourceName
        if let cached = menuBarCache[name] { return cached }
        guard let source = nsImage(for: kind) else { return nil }
        let rendered = renderMenuBarImage(from: source, template: isTemplate(for: kind))
        menuBarCache[name] = rendered
        return rendered
    }

    private static func loadImage(named name: String) -> NSImage? {
        if let url = url(name: name, ext: "pdf"), let image = validImage(at: url) {
            return image
        }
        if let url = url(name: "\(name)@2x", ext: "png"), let image = validImage(at: url) {
            return image
        }
        if let url = url(name: name, ext: "png"), let image = validImage(at: url) {
            return image
        }
        if let url = url(name: name, ext: "svg"), let image = validImage(at: url) {
            templateKeys.insert(name)
            return image
        }
        return nil
    }

    private static func validImage(at url: URL) -> NSImage? {
        guard let image = NSImage(contentsOf: url), image.isValid, image.size != .zero else { return nil }
        return image
    }

    private static func url(name: String, ext: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext, subdirectory: directory)
            ?? Bundle.module.url(forResource: name, withExtension: ext)
    }

    // MARK: - 菜单栏光栅化

    private static func renderMenuBarImage(from source: NSImage, template: Bool) -> NSImage {
        let point = menuBarPointSize
        let scale: CGFloat = 2
        let pixels = Int((point * scale).rounded())
        let raster = rasterizedCGImage(from: source, pixelSize: 128) ?? source.cgImage(
            forProposedRect: nil, context: nil, hints: nil
        )
        let content = raster.flatMap(trimmedCGImage) ?? raster

        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = NSSize(width: point, height: point)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        // 位图上下文原点在左下。CGContext.draw + 手动 Y 翻转会把 SVG（尤其是 DeepSeek）画颠倒；
        // 交给 NSImage.draw(respectFlipped:) 对齐 AppKit 坐标系。
        if let content {
            let cropped = NSImage(
                cgImage: content,
                size: NSSize(width: content.width, height: content.height)
            )
            cropped.draw(
                in: aspectFit(
                    NSSize(width: content.width, height: content.height),
                    in: NSSize(width: point, height: point)
                ),
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        } else {
            source.draw(
                in: NSRect(origin: .zero, size: NSSize(width: point, height: point)),
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        }
        NSGraphicsContext.restoreGraphicsState()

        let output = NSImage(size: NSSize(width: point, height: point))
        output.addRepresentation(rep)
        output.isTemplate = template
        return output
    }

    private static func rasterizedCGImage(from image: NSImage, pixelSize: Int) -> CGImage? {
        var rect = NSRect(origin: .zero, size: NSSize(width: pixelSize, height: pixelSize))
        return image.cgImage(
            forProposedRect: &rect,
            context: nil,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private static func trimmedCGImage(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        guard let data = image.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else { return nil }

        let bytesPerPixel = max(image.bitsPerPixel / 8, 1)
        let bytesPerRow = image.bytesPerRow
        let alphaOffset: Int
        switch image.alphaInfo {
        case .premultipliedLast, .last, .noneSkipLast: alphaOffset = 3
        case .premultipliedFirst, .first, .noneSkipFirst: alphaOffset = 0
        default: return image
        }

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        let threshold: UInt8 = 12
        for y in 0..<height {
            for x in 0..<width {
                if ptr[y * bytesPerRow + x * bytesPerPixel + alphaOffset] > threshold {
                    if x < minX { minX = x }
                    if y < minY { minY = y }
                    if x > maxX { maxX = x }
                    if y > maxY { maxY = y }
                }
            }
        }
        guard minX <= maxX, minY <= maxY else { return image }

        let pad = 1
        let originX = max(minX - pad, 0)
        let originY = max(minY - pad, 0)
        let crop = CGRect(
            x: originX,
            y: originY,
            width: min(maxX + pad + 1, width) - originX,
            height: min(maxY + pad + 1, height) - originY
        )
        return image.cropping(to: crop)
    }

    private static func aspectFit(_ size: NSSize, in bounds: NSSize) -> NSRect {
        guard size.width > 0, size.height > 0 else {
            return NSRect(origin: .zero, size: bounds)
        }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fitted = NSSize(width: size.width * scale, height: size.height * scale)
        return NSRect(
            x: (bounds.width - fitted.width) / 2,
            y: (bounds.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
    }
}
