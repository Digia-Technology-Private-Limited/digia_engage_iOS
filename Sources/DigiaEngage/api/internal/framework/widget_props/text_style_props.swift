import Foundation

struct TextStyleProps: Codable, Equatable, Sendable {
    let fontToken: FontTokenProps?
    let textColor: String?
    let textBackgroundColor: String?
    let textDecoration: String?
    let textDecorationColor: String?
    let gradient: TextGradientProps?
}

struct FontTokenProps: Codable, Equatable, Sendable {
    let value: String?
    let font: FontDescriptorProps?
}

struct FontDescriptorProps: Codable, Equatable, Sendable {
    let fontFamily: String?
    let weight: String?
    let size: Double?
    let height: Double?
    let isItalic: Bool?
    let style: Bool?

    enum CodingKeys: String, CodingKey {
        case fontFamily
        case fontFamilyKebab = "font-family"
        case weight
        case size
        case height
        case isItalic
        case style
    }

    init(
        fontFamily: String?,
        weight: String?,
        size: Double?,
        height: Double?,
        isItalic: Bool?,
        style: Bool?
    ) {
        self.fontFamily = fontFamily
        self.weight = weight
        self.size = size
        self.height = height
        self.isItalic = isItalic
        self.style = style
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontFamily = Self.decodeFontFamily(from: container)
        weight = Self.decodeString(from: container, forKey: .weight)
        size = Self.decodeDouble(from: container, forKey: .size)
        height = Self.decodeDouble(from: container, forKey: .height)
        isItalic = Self.decodeBool(from: container, forKey: .isItalic)
        style = Self.decodeStyleBool(from: container, forKey: .style)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(fontFamily, forKey: .fontFamily)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(isItalic, forKey: .isItalic)
        try container.encodeIfPresent(style, forKey: .style)
    }

    private static func decodeFontFamily(from container: KeyedDecodingContainer<CodingKeys>) -> String? {
        decodeString(from: container, forKey: .fontFamily)
            ?? decodeString(from: container, forKey: .fontFamilyKebab)
            ?? decodeStringMap(from: container, forKey: .fontFamily)?["primary"]
            ?? decodeStringMap(from: container, forKey: .fontFamily)?["secondary"]
            ?? decodeStringMap(from: container, forKey: .fontFamilyKebab)?["primary"]
            ?? decodeStringMap(from: container, forKey: .fontFamilyKebab)?["secondary"]
    }

    private static func decodeString(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> String? {
        guard container.contains(key), let decoder = try? container.superDecoder(forKey: key) else {
            return nil
        }
        let singleValue = try? decoder.singleValueContainer()
        return try? singleValue?.decode(String.self)
    }

    private static func decodeStringMap(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> [String: String]? {
        guard container.contains(key), let decoder = try? container.superDecoder(forKey: key) else {
            return nil
        }
        return try? [String: String](from: decoder)
    }

    private static func decodeDouble(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Double? {
        guard container.contains(key), let decoder = try? container.superDecoder(forKey: key) else {
            return nil
        }
        guard let singleValue = try? decoder.singleValueContainer() else {
            return nil
        }
        if let value = try? singleValue.decode(Double.self) {
            return value
        }
        if let value = try? singleValue.decode(Int.self) {
            return Double(value)
        }
        if let value = try? singleValue.decode(String.self) {
            return Double(value)
        }
        return nil
    }

    private static func decodeBool(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Bool? {
        guard container.contains(key), let decoder = try? container.superDecoder(forKey: key) else {
            return nil
        }
        guard let singleValue = try? decoder.singleValueContainer() else {
            return nil
        }
        if let value = try? singleValue.decode(Bool.self) {
            return value
        }
        if let value = try? singleValue.decode(String.self) {
            return Bool(value.lowercased())
        }
        return nil
    }

    private static func decodeStyleBool(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Bool? {
        guard container.contains(key), let decoder = try? container.superDecoder(forKey: key) else {
            return nil
        }
        guard let singleValue = try? decoder.singleValueContainer() else {
            return nil
        }
        if let value = try? singleValue.decode(Bool.self) {
            return value
        }
        if let value = try? singleValue.decode(String.self) {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized == "italic" {
                return true
            }
            if normalized == "normal" {
                return false
            }
        }
        return nil
    }
}

struct TextGradientProps: Codable, Equatable, Sendable {
    let type: String?
    let begin: String?
    let end: String?
    let colorList: [TextGradientStop]?
}

struct TextGradientStop: Codable, Equatable, Sendable {
    let color: String?
    let stop: Double?
}
