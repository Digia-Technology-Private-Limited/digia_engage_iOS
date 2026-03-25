import Foundation

struct PositionedProps: Codable, Equatable, Sendable {
    let top: ExprOr<Double>?
    let bottom: ExprOr<Double>?
    let left: ExprOr<Double>?
    let right: ExprOr<Double>?
    let width: ExprOr<Double>?
    let height: ExprOr<Double>?

    init(top: ExprOr<Double>? = nil, bottom: ExprOr<Double>? = nil, left: ExprOr<Double>? = nil, right: ExprOr<Double>? = nil, width: ExprOr<Double>? = nil, height: ExprOr<Double>? = nil) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
        self.width = width
        self.height = height
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            let parts = string.split(separator: ",").map { substring -> ExprOr<Double>? in
                let trimmed = substring.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed == "-" {
                    return nil
                }
                if let value = Double(trimmed) {
                    return .value(value)
                }
                return .expression(trimmed)
            }
            self = PositionedProps(
                top: parts.count > 1 ? parts[1] : nil,
                bottom: parts.count > 3 ? parts[3] : nil,
                left: parts.count > 0 ? parts[0] : nil,
                right: parts.count > 2 ? parts[2] : nil
            )
            return
        }

        let object = try container.decode(PositionedObject.self)
        self = PositionedProps(
            top: object.top,
            bottom: object.bottom,
            left: object.left,
            right: object.right,
            width: object.width,
            height: object.height
        )
    }
}

private struct PositionedObject: Codable, Equatable, Sendable {
    let top: ExprOr<Double>?
    let bottom: ExprOr<Double>?
    let left: ExprOr<Double>?
    let right: ExprOr<Double>?
    let width: ExprOr<Double>?
    let height: ExprOr<Double>?
}
