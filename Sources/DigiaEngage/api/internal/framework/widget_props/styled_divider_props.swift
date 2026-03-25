import Foundation

struct DividerSizeProps: Equatable, Sendable {
    let height: ExprOr<Double>?
    let width: ExprOr<Double>?

    init(
        height: ExprOr<Double>? = nil,
        width: ExprOr<Double>? = nil
    ) {
        self.height = height
        self.width = width
    }
}

struct DividerGradientProps: Decodable, Equatable, Sendable {
    let type: String?
    let begin: String?
    let end: String?
    let center: String?
    let radius: Double?
    let colorList: [DividerGradientStop]?
}

struct DividerGradientStop: Decodable, Equatable, Sendable {
    let color: String?
    let stop: Double?
}

private struct DividerColorTypeProps: Decodable, Equatable, Sendable {
    let color: ExprOr<String>?
    let gradiant: DividerGradientProps?
}

struct DividerBorderPatternProps: Decodable, Equatable, Sendable {
    let value: String?
    let strokeCap: String?
    let dashPattern: [Double]?

    private enum CodingKeys: String, CodingKey {
        case value
        case strokeCap
        case dashPattern
    }

    init(
        value: String? = nil,
        strokeCap: String? = nil,
        dashPattern: [Double]? = nil
    ) {
        self.value = value
        self.strokeCap = strokeCap
        self.dashPattern = dashPattern
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        strokeCap = try container.decodeIfPresent(String.self, forKey: .strokeCap)
        dashPattern = decodeDashPattern(from: container, forKey: .dashPattern)
    }
}

struct StyledDividerProps: Decodable, Equatable, Sendable {
    let size: DividerSizeProps
    let thickness: ExprOr<Double>?
    let lineStyle: String?
    let indent: ExprOr<Double>?
    let endIndent: ExprOr<Double>?
    let strokeCap: String?
    let dashPattern: [Double]?
    let color: ExprOr<String>?
    let gradient: DividerGradientProps?
    let borderPattern: String?

    private enum CodingKeys: String, CodingKey {
        case height
        case width
        case thickness
        case lineStyle
        case indent
        case endIndent
        case color
        case colorType
        case borderPattern
    }

    init(
        size: DividerSizeProps = DividerSizeProps(),
        thickness: ExprOr<Double>? = nil,
        lineStyle: String? = nil,
        indent: ExprOr<Double>? = nil,
        endIndent: ExprOr<Double>? = nil,
        strokeCap: String? = nil,
        dashPattern: [Double]? = nil,
        color: ExprOr<String>? = nil,
        gradient: DividerGradientProps? = nil,
        borderPattern: String? = nil
    ) {
        self.size = size
        self.thickness = thickness
        self.lineStyle = lineStyle
        self.indent = indent
        self.endIndent = endIndent
        self.strokeCap = strokeCap
        self.dashPattern = dashPattern
        self.color = color
        self.gradient = gradient
        self.borderPattern = borderPattern
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let colorType = try container.decodeIfPresent(DividerColorTypeProps.self, forKey: .colorType)
        let borderPatternProps = try? container.decode(DividerBorderPatternProps.self, forKey: .borderPattern)
        let rawBorderPattern = try? container.decode(String.self, forKey: .borderPattern)

        size = DividerSizeProps(
            height: try container.decodeIfPresent(ExprOr<Double>.self, forKey: .height),
            width: try container.decodeIfPresent(ExprOr<Double>.self, forKey: .width)
        )
        thickness = try container.decodeIfPresent(ExprOr<Double>.self, forKey: .thickness)
        lineStyle = try container.decodeIfPresent(String.self, forKey: .lineStyle)
        indent = try container.decodeIfPresent(ExprOr<Double>.self, forKey: .indent)
        endIndent = try container.decodeIfPresent(ExprOr<Double>.self, forKey: .endIndent)
        strokeCap = borderPatternProps?.strokeCap
        dashPattern = borderPatternProps?.dashPattern
        if let decodedColor = colorType?.color {
            color = decodedColor
        } else {
            color = try container.decodeIfPresent(ExprOr<String>.self, forKey: .color)
        }
        gradient = colorType?.gradiant
        borderPattern = borderPatternProps?.value ?? rawBorderPattern
    }
}
