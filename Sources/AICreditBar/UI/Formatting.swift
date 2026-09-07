import Foundation

// MARK: - 金额 / 数字 / 时间 的展示格式化

enum Money {
    static func symbol(for currency: String?) -> String {
        switch currency?.uppercased() {
        case "CNY": return "¥"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case nil: return ""
        default: return (currency ?? "") + " "
        }
    }

    /// 保留最多两位小数并去掉多余的尾零："110.00" → "110"，"49.58894" → "49.59"。
    static func plain(_ v: Decimal) -> String {
        let d = NSDecimalNumber(decimal: v).doubleValue
        var s = String(format: "%.2f", d)
        if s.hasSuffix(".00") {
            s = String(s.dropLast(3))
        } else if s.hasSuffix("0") {
            s = String(s.dropLast())
        }
        return s
    }

    /// 简短金额："¥110"、"$49.59"。
    static func short(_ v: Decimal, currency: String?) -> String {
        symbol(for: currency) + plain(v)
    }

    /// 固定两位金额："¥110.00"。
    static func two(_ v: Decimal, currency: String?) -> String {
        symbol(for: currency) + String(format: "%.2f", NSDecimalNumber(decimal: v).doubleValue)
    }
}

enum Fmt {
    static func grouped(_ v: Int64) -> String {
        NumberFormatter.groupingFormatter.string(from: NSNumber(value: v)) ?? String(v)
    }

    static func groupedTokens(_ v: Int64) -> String {
        if v >= 1_000_000 {
            let m = Double(v) / 1_000_000.0
            return String(format: "%.1fM", m)
        }
        if v >= 10_000 {
            let k = Double(v) / 1_000.0
            return String(format: "%.1fk", k)
        }
        return grouped(v)
    }

    static func relative(_ date: Date, to now: Date = Date()) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 10 { return L10n.str("fmt.just_now") }
        if seconds < 60 { return L10n.plural("fmt.seconds_ago", count: seconds) }
        let minutes = seconds / 60
        if minutes < 60 { return L10n.plural("fmt.minutes_ago", count: minutes) }
        let hours = minutes / 60
        if hours < 24 { return L10n.plural("fmt.hours_ago", count: hours) }
        return L10n.plural("fmt.days_ago", count: hours / 24)
    }

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}

private extension NumberFormatter {
    static let groupingFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}

private let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f
}()
