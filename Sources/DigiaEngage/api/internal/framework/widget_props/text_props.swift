import Foundation

struct TextProps: Codable, Equatable, Sendable {
    let text: ExprOr<String>?
    let textStyle: TextStyleProps?
    let maxLines: ExprOr<Int>?
    let alignment: ExprOr<String>?
    let overflow: ExprOr<String>?

    var fontDescriptor: FontDescriptorProps? { textStyle?.fontToken?.font }

    init(
        text: ExprOr<String>?,
        textStyle: TextStyleProps?,
        maxLines: ExprOr<Int>?,
        alignment: ExprOr<String>?,
        overflow: ExprOr<String>?
    ) {
        self.text = text
        self.textStyle = textStyle
        self.maxLines = maxLines
        self.alignment = alignment
        self.overflow = overflow
    }

    private enum CodingKeys: String, CodingKey {
        case text
        case textStyle
        case maxLines
        case alignment
        case overflow
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode through JSONValue first to avoid deep nested decoder crashes on large payloads.
        if let textScope = try container.decodeIfPresent(JSONValue.self, forKey: .text) {
            text = ExprOr<String>.fromJSONValue(textScope)
        } else {
            text = nil
        }

        if let textStyleScope = try container.decodeIfPresent(JSONValue.self, forKey: .textStyle) {
            textStyle = TextStyleProps(JSONValue: textStyleScope)
        } else {
            textStyle = nil
        }

        if let maxLinesScope = try container.decodeIfPresent(JSONValue.self, forKey: .maxLines) {
            maxLines = ExprOr<Int>.fromJSONValue(maxLinesScope)
        } else {
            maxLines = nil
        }

        if let alignmentScope = try container.decodeIfPresent(JSONValue.self, forKey: .alignment) {
            alignment = ExprOr<String>.fromJSONValue(alignmentScope)
        } else {
            alignment = nil
        }

        if let overflowScope = try container.decodeIfPresent(JSONValue.self, forKey: .overflow) {
            overflow = ExprOr<String>.fromJSONValue(overflowScope)
        } else {
            overflow = nil
        }
    }

    init(JSONValue: JSONValue?) {
        let object = JSONValue?.duiObjectValue ?? [:]
        text = ExprOr<String>.fromJSONValue(object["text"])
        textStyle = TextStyleProps(JSONValue: object["textStyle"])
        maxLines = ExprOr<Int>.fromJSONValue(object["maxLines"])
        alignment = ExprOr<String>.fromJSONValue(object["alignment"])
        overflow = ExprOr<String>.fromJSONValue(object["overflow"])
    }
}

extension TextStyleProps {
    init?(JSONValue: JSONValue?) {
        guard let object = JSONValue?.duiObjectValue else { return nil }
        self.init(
            fontToken: FontTokenProps(JSONValue: object["fontToken"]),
            textColor: object["textColor"]?.duiStringValue,
            textBackgroundColor: object["textBackgroundColor"]?.duiStringValue,
            textDecoration: object["textDecoration"]?.duiStringValue,
            textDecorationColor: object["textDecorationColor"]?.duiStringValue,
            gradient: TextGradientProps(JSONValue: object["gradient"])
        )
    }
}

extension FontTokenProps {
    init?(JSONValue: JSONValue?) {
        guard let object = JSONValue?.duiObjectValue else { return nil }
        self.init(
            value: object["value"]?.duiStringValue,
            font: FontDescriptorProps(JSONValue: object["font"])
        )
    }
}

extension FontDescriptorProps {
    init?(JSONValue: JSONValue?) {
        guard let object = JSONValue?.duiObjectValue else { return nil }

        let familyValue = Self.resolveFamily(from: object)

        self.init(
            fontFamily: familyValue,
            weight: object["weight"]?.duiStringValue,
            size: object["size"]?.duiDoubleLikeValue,
            height: object["height"]?.duiDoubleLikeValue,
            isItalic: object["isItalic"]?.duiBoolLikeValue,
            style: {
                if let boolValue = object["style"]?.duiBoolValue {
                    return boolValue
                }
                if let styleString = object["style"]?.duiStringValue {
                    let normalized = styleString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if normalized == "italic" { return true }
                    if normalized == "normal" { return false }
                }
                return nil
            }()
        )
    }

    private static func resolveFamily(from object: [String: JSONValue]) -> String? {
        if let direct = object["fontFamily"]?.duiStringValue {
            return direct
        }
        if let directKebab = object["font-family"]?.duiStringValue {
            return directKebab
        }

        let familyObject = object["fontFamily"]?.duiObjectValue
        if let primary = familyObject?["primary"]?.duiStringValue {
            return primary
        }
        if let secondary = familyObject?["secondary"]?.duiStringValue {
            return secondary
        }

        let familyKebabObject = object["font-family"]?.duiObjectValue
        if let primary = familyKebabObject?["primary"]?.duiStringValue {
            return primary
        }
        if let secondary = familyKebabObject?["secondary"]?.duiStringValue {
            return secondary
        }

        return nil
    }
}

extension TextGradientProps {
    init?(JSONValue: JSONValue?) {
        guard let object = JSONValue?.duiObjectValue else { return nil }
        self.init(
            type: object["type"]?.duiStringValue,
            begin: object["begin"]?.duiStringValue,
            end: object["end"]?.duiStringValue,
            colorList: object["colorList"]?.duiArrayValue?.compactMap(TextGradientStop.init(JSONValue:))
        )
    }
}

extension TextGradientStop {
    init?(JSONValue: JSONValue?) {
        guard let object = JSONValue?.duiObjectValue else { return nil }
        self.init(
            color: object["color"]?.duiStringValue,
            stop: object["stop"]?.duiDoubleLikeValue
        )
    }
}

extension ExprOr where Value == String {
    static func fromJSONValue(_ value: JSONValue?) -> ExprOr<String>? {
        switch value {
        case let .string(raw):
            return .value(raw)
        case let .object(object):
            if let expr = object["expr"]?.duiStringValue {
                return .expression(expr)
            }
            return nil
        case let .int(number):
            return .value(String(number))
        case let .double(number):
            return .value(String(number))
        case let .bool(flag):
            return .value(String(flag))
        default:
            return nil
        }
    }
}

extension ExprOr where Value == Int {
    static func fromJSONValue(_ value: JSONValue?) -> ExprOr<Int>? {
        switch value {
        case let .int(number):
            return .value(number)
        case let .double(number):
            return .value(Int(number))
        case let .string(raw):
            if let intValue = Int(raw) {
                return .value(intValue)
            }
            return .expression(raw)
        case let .object(object):
            if let expr = object["expr"]?.duiStringValue {
                return .expression(expr)
            }
            return nil
        default:
            return nil
        }
    }
}

extension JSONValue {
    var duiStringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    var duiBoolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }

    var duiBoolLikeValue: Bool? {
        switch self {
        case let .bool(value):
            return value
        case let .string(value):
            return Bool(value.lowercased())
        default:
            return nil
        }
    }

    var duiDoubleLikeValue: Double? {
        switch self {
        case let .double(value):
            return value
        case let .int(value):
            return Double(value)
        case let .string(value):
            return Double(value)
        default:
            return nil
        }
    }

    var duiObjectValue: [String: JSONValue]? {
        if case let .object(value) = self { return value }
        return nil
    }

    var duiArrayValue: [JSONValue]? {
        if case let .array(value) = self { return value }
        return nil
    }
}
