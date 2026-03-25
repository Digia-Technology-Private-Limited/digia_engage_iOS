import Foundation
import SwiftUI

enum Spacing: Codable, Equatable, Sendable {
    case uniform(Double)
    case pair(horizontal: Double, vertical: Double)
    case edges(left: Double, top: Double, right: Double, bottom: Double)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let number = try? container.decode(Double.self) {
            self = .uniform(number)
            return
        }

        if let number = try? container.decode(Int.self) {
            self = .uniform(Double(number))
            return
        }

        if let string = try? container.decode(String.self) {
            let values = string
                .split(separator: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }

            switch values.count {
            case 1:
                self = .uniform(values[0])
            case 2:
                self = .pair(horizontal: values[0], vertical: values[1])
            case 4:
                self = .edges(left: values[0], top: values[1], right: values[2], bottom: values[3])
            default:
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid spacing string")
            }
            return
        }

        let object = try container.decode(SpacingObject.self)
        if let all = object.all {
            self = .uniform(all)
        } else if let horizontal = object.horizontal, let vertical = object.vertical {
            self = .pair(horizontal: horizontal, vertical: vertical)
        } else {
            self = .edges(
                left: object.left ?? 0,
                top: object.top ?? 0,
                right: object.right ?? 0,
                bottom: object.bottom ?? 0
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .uniform(value):
            try container.encode(value)
        case let .pair(horizontal, vertical):
            try container.encode("\(horizontal),\(vertical)")
        case let .edges(left, top, right, bottom):
            try container.encode("\(left),\(top),\(right),\(bottom)")
        }
    }

    var edgeInsets: EdgeInsets {
        switch self {
        case let .uniform(value):
            return EdgeInsets(top: value, leading: value, bottom: value, trailing: value)
        case let .pair(horizontal, vertical):
            return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
        case let .edges(left, top, right, bottom):
            return EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
        }
    }
}

private struct SpacingObject: Codable, Equatable, Sendable {
    let all: Double?
    let horizontal: Double?
    let vertical: Double?
    let left: Double?
    let top: Double?
    let right: Double?
    let bottom: Double?
}
