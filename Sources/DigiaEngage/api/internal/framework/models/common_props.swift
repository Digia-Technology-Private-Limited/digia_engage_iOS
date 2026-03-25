import Foundation

struct CommonStyle: Decodable, Equatable, Sendable {
    let padding: Spacing?
    let margin: Spacing?
    let bgColor: ExprOr<String>?
    let borderRadius: JSONValue?
    let height: ExprOr<Double>?
    let width: ExprOr<Double>?
    let heightRaw: String?
    let widthRaw: String?
    let clipBehavior: String?
    let border: BorderStyle?

    init(
        padding: Spacing? = nil,
        margin: Spacing? = nil,
        bgColor: ExprOr<String>? = nil,
        borderRadius: JSONValue? = nil,
        height: ExprOr<Double>? = nil,
        width: ExprOr<Double>? = nil,
        heightRaw: String? = nil,
        widthRaw: String? = nil,
        clipBehavior: String? = nil,
        border: BorderStyle? = nil
    ) {
        self.padding = padding
        self.margin = margin
        self.bgColor = bgColor
        self.borderRadius = borderRadius
        self.height = height
        self.width = width
        self.heightRaw = heightRaw
        self.widthRaw = widthRaw
        self.clipBehavior = clipBehavior
        self.border = border
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        padding = try container.decodeIfPresent(Spacing.self, forKey: .padding)
        margin = try container.decodeIfPresent(Spacing.self, forKey: .margin)
        bgColor = try container.decodeIfPresent(ExprOr<String>.self, forKey: .bgColor)
            ?? container.decodeIfPresent(ExprOr<String>.self, forKey: .backgroundColor)
        border = try container.decodeIfPresent(BorderStyle.self, forKey: .border)
        borderRadius = try container.decodeIfPresent(JSONValue.self, forKey: .borderRadius)
            ?? border?.borderRadius
        height = try container.decodeIfPresent(ExprOr<Double>.self, forKey: .height)
        width = try container.decodeIfPresent(ExprOr<Double>.self, forKey: .width)
        heightRaw = try? container.decodeIfPresent(String.self, forKey: .height)
        widthRaw = try? container.decodeIfPresent(String.self, forKey: .width)
        clipBehavior = try container.decodeIfPresent(String.self, forKey: .clipBehavior)
    }

    private enum CodingKeys: String, CodingKey {
        case padding
        case margin
        case bgColor
        case backgroundColor
        case borderRadius
        case height
        case width
        case clipBehavior
        case border
    }
}

struct BorderStyle: Decodable, Equatable, Sendable {
    let borderWidth: Double?
    let borderRadius: JSONValue?
    let borderColor: ExprOr<String>?
    let strokeAlign: String?
    let borderType: BorderType?
}

struct BorderType: Decodable, Equatable, Sendable {
    let dashPattern: [Double]?
    let borderPattern: String?
    let strokeCap: String?

    private enum CodingKeys: String, CodingKey {
        case dashPattern
        case borderPattern
        case strokeCap
    }

    init(
        dashPattern: [Double]? = nil,
        borderPattern: String? = nil,
        strokeCap: String? = nil
    ) {
        self.dashPattern = dashPattern
        self.borderPattern = borderPattern
        self.strokeCap = strokeCap
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dashPattern = try container.decodeIfPresent([Double].self, forKey: .dashPattern)
        borderPattern = try container.decodeIfPresent(String.self, forKey: .borderPattern)
            ?? container.decodeIfPresent(String.self, forKey: .borderPattern)
        strokeCap = try container.decodeIfPresent(String.self, forKey: .strokeCap)
    }
}

struct CommonProps: Decodable, Equatable, Sendable {
    let visibility: ExprOr<Bool>?
    let align: String?
    let style: CommonStyle?
    let onClick: ActionFlow?

    init(
        visibility: ExprOr<Bool>? = nil,
        align: String? = nil,
        style: CommonStyle? = nil,
        onClick: ActionFlow? = nil
    ) {
        self.visibility = visibility
        self.align = align
        self.style = style
        self.onClick = onClick
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let visibility = try container.decodeIfPresent(ExprOr<Bool>.self, forKey: .visibility)
        let align = try container.decodeIfPresent(String.self, forKey: .align)
        let onClick = try container.decodeIfPresent(ActionFlow.self, forKey: .onClick)

        if let style = try container.decodeIfPresent(CommonStyle.self, forKey: .style) {
            self = CommonProps(visibility: visibility, align: align, style: style, onClick: onClick)
            return
        }

        if let style = try container.decodeIfPresent(CommonStyle.self, forKey: .styleClass) {
            self = CommonProps(visibility: visibility, align: align, style: style, onClick: onClick)
            return
        }

        let flattened = try CommonStyle(from: decoder)
        if flattened.padding != nil ||
            flattened.margin != nil ||
            flattened.bgColor != nil ||
            flattened.borderRadius != nil ||
            flattened.height != nil ||
            flattened.width != nil ||
            flattened.heightRaw != nil ||
            flattened.widthRaw != nil ||
            flattened.clipBehavior != nil ||
            flattened.border != nil {
            self = CommonProps(visibility: visibility, align: align, style: flattened, onClick: onClick)
            return
        }

        self = CommonProps(visibility: visibility, align: align, style: nil, onClick: onClick)
    }

    private enum CodingKeys: String, CodingKey {
        case visibility
        case align
        case style
        case styleClass
        case onClick
    }
}
