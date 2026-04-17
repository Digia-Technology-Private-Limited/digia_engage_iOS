import SwiftUI

enum ColorUtil {
    static func fromHex(_ value: String?) -> Color? {
        guard let value else { return nil }
        return Color(hex: value)
    }

    /// Parses a comma-separated "R,G,B" or "R,G,B,A" string into a Color.
    /// Alpha accepts either 0–255 (int) or 0.0–1.0 (double).
    static func fromRgba(_ value: String) -> Color? {
        let parts = value.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 3,
              let r = Int(parts[0])?.clamped(to: 0...255),
              let g = Int(parts[1])?.clamped(to: 0...255),
              let b = Int(parts[2])?.clamped(to: 0...255) else { return nil }

        var alpha: Double = 1.0
        if parts.count == 4 {
            if let intAlpha = Int(parts[3]) {
                alpha = Double(intAlpha.clamped(to: 0...255)) / 255.0
            } else if let doubleAlpha = Double(parts[3]) {
                alpha = min(max(doubleAlpha, 0.0), 1.0)
            }
        }

        return Color(.sRGB, red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0, opacity: alpha)
    }

    /// Tries hex first, then rgba. Returns nil if neither parses.
    static func fromString(_ value: String?) -> Color? {
        guard let value, !value.isEmpty else { return nil }
        return Color(hex: value) ?? fromRgba(value)
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        if self < range.lowerBound { return range.lowerBound }
        if self > range.upperBound { return range.upperBound }
        return self
    }
}
