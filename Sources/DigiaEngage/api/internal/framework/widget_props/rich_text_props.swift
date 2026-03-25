import Foundation

struct RichTextProps: Codable, Equatable, Sendable {
    let textSpans: [RichTextSpan]
    let textStyle: TextStyleProps?
    let maxLines: ExprOr<Int>?
    let alignment: ExprOr<String>?
    let overflow: ExprOr<String>?

    private enum CodingKeys: String, CodingKey {
        case textSpans
        case textStyle
        case maxLines
        case alignment
        case overflow
    }

    init(
        textSpans: [RichTextSpan],
        textStyle: TextStyleProps?,
        maxLines: ExprOr<Int>?,
        alignment: ExprOr<String>?,
        overflow: ExprOr<String>?
    ) {
        self.textSpans = textSpans
        self.textStyle = textStyle
        self.maxLines = maxLines
        self.alignment = alignment
        self.overflow = overflow
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let spans = try? container.decode([RichTextSpan].self, forKey: .textSpans) {
            textSpans = spans
        } else if let span = try? container.decode(RichTextSpan.self, forKey: .textSpans) {
            textSpans = [span]
        } else {
            textSpans = []
        }
        textStyle = try container.decodeIfPresent(TextStyleProps.self, forKey: .textStyle)
        maxLines = try container.decodeIfPresent(ExprOr<Int>.self, forKey: .maxLines)
        alignment = try container.decodeIfPresent(ExprOr<String>.self, forKey: .alignment)
        overflow = try container.decodeIfPresent(ExprOr<String>.self, forKey: .overflow)
    }
}

struct RichTextSpan: Codable, Equatable, Sendable {
    let text: ExprOr<String>?
    let spanStyle: TextStyleProps?
    let textStyle: TextStyleProps?
    let style: TextStyleProps?
    let onClick: ActionFlow?

    var resolvedStyle: TextStyleProps? {
        spanStyle ?? textStyle ?? style
    }

    private enum CodingKeys: String, CodingKey {
        case text
        case spanStyle
        case textStyle
        case style
        case onClick
    }

    init(
        text: ExprOr<String>?,
        spanStyle: TextStyleProps? = nil,
        textStyle: TextStyleProps? = nil,
        style: TextStyleProps? = nil,
        onClick: ActionFlow? = nil
    ) {
        self.text = text
        self.spanStyle = spanStyle
        self.textStyle = textStyle
        self.style = style
        self.onClick = onClick
    }

    init(from decoder: Decoder) throws {
        let singleValue = try decoder.singleValueContainer()
        if let string = try? singleValue.decode(ExprOr<String>.self) {
            self = RichTextSpan(text: string)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(ExprOr<String>.self, forKey: .text)
        spanStyle = try container.decodeIfPresent(TextStyleProps.self, forKey: .spanStyle)
        textStyle = try container.decodeIfPresent(TextStyleProps.self, forKey: .textStyle)
        style = try container.decodeIfPresent(TextStyleProps.self, forKey: .style)
        onClick = try container.decodeIfPresent(ActionFlow.self, forKey: .onClick)
    }
}
