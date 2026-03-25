import Foundation

enum NumUtil {
    static func toDouble(_ value: Any?) -> Double? {
        switch value {
        case let v as Double:
            return v
        case let v as Int:
            return Double(v)
        case let v as Bool:
            return v ? 1.0 : 0.0
        case let v as String:
            let lower = v.lowercased()
            if lower == "inf" || lower == "infinity" { return .infinity }
            if lower.hasPrefix("0x") { return Int(lower.dropFirst(2), radix: 16).map(Double.init) }
            return Double(v)
        default:
            return nil
        }
    }

    static func toInt(_ value: Any?) -> Int? {
        switch value {
        case let v as Int:
            return v
        case let v as Double:
            return Int(v)
        case let v as Bool:
            return v ? 1 : 0
        case let v as String:
            let lower = v.lowercased()
            if lower.hasPrefix("0x") { return Int(lower.dropFirst(2), radix: 16) }
            return Int(v) ?? Double(v).map(Int.init)
        default:
            return nil
        }
    }

    static func toBool(_ value: Any?) -> Bool? {
        switch value {
        case let v as Bool:
            return v
        case let v as String:
            return Bool(v.lowercased())
        default:
            return nil
        }
    }

    /// Converts a 0–100 percentage progress value to a 0–1 fraction, clamped.
    static func normalizeProgress(_ value: Double) -> Double {
        min(max(value / 100.0, 0), 1)
    }
}
