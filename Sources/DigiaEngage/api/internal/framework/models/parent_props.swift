import Foundation

struct ParentProps: Codable, Equatable, Sendable {
    let position: PositionedProps?
    let expansion: ExpansionProps?

    init(position: PositionedProps? = nil, expansion: ExpansionProps? = nil) {
        self.position = position
        self.expansion = expansion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nestedPositioned = try container.decodeIfPresent(PositionedWrapper.self, forKey: .positioned)
        position = try container.decodeIfPresent(PositionedProps.self, forKey: .position) ?? nestedPositioned?.position
        expansion = try container.decodeIfPresent(ExpansionProps.self, forKey: .expansion)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(position, forKey: .position)
        try container.encodeIfPresent(expansion, forKey: .expansion)
    }

    private enum CodingKeys: String, CodingKey {
        case position
        case positioned
        case expansion
    }
}

struct ExpansionProps: Codable, Equatable, Sendable {
    let type: String?
    let flexValue: ExprOr<Int>?
}

private struct PositionedWrapper: Codable, Equatable, Sendable {
    let hasPosition: Bool?
    let position: PositionedProps?
}
