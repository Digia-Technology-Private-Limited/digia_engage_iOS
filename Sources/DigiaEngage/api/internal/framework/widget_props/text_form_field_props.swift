import Foundation

struct TextFormFieldProps: Decodable, Equatable, Sendable {
    let controller: JSONValue?
    let initialValue: ExprOr<String>?
    let autoFocus: ExprOr<Bool>?
    let enabled: ExprOr<Bool>?
    let keyboardType: ExprOr<String>?
    let textInputAction: ExprOr<String>?
    let textStyle: TextStyleProps?
    let textAlign: ExprOr<String>?
    let readOnly: ExprOr<Bool>?
    let obscureText: ExprOr<Bool>?
    let maxLines: ExprOr<Int>?
    let minLines: ExprOr<Int>?
    let maxLength: ExprOr<Int>?
    let debounceValue: ExprOr<Int>?
    let textCapitalization: ExprOr<String>?
    let inputFormatters: [TextInputFormatterRule]?
    let fillColor: ExprOr<String>?
    let labelText: ExprOr<String>?
    let labelStyle: TextStyleProps?
    let hintText: ExprOr<String>?
    let hintStyle: TextStyleProps?
    let contentPadding: Spacing?
    let focusColor: ExprOr<String>?
    let cursorColor: ExprOr<String>?
    let prefixIconConstraints: TextFieldIconConstraints?
    let suffixIconConstraints: TextFieldIconConstraints?
    let validationRules: [TextFieldValidationRule]?
    let errorStyle: TextStyleProps?
    let enabledBorder: TextFieldBorderProps?
    let disabledBorder: TextFieldBorderProps?
    let focusedBorder: TextFieldBorderProps?
    let focusedErrorBorder: TextFieldBorderProps?
    let errorBorder: TextFieldBorderProps?
    let onChanged: ActionFlow?
    let onSubmit: ActionFlow?
}

struct TextInputFormatterRule: Decodable, Equatable, Sendable {
    let type: String?
    let regex: String?
}

struct TextFieldValidationRule: Decodable, Equatable, Sendable {
    let type: String?
    let errorMessage: ExprOr<String>?
    let data: JSONValue?
}

struct TextFieldIconConstraints: Decodable, Equatable, Sendable {
    let minWidth: ExprOr<Double>?
    let minHeight: ExprOr<Double>?
    let maxWidth: ExprOr<Double>?
    let maxHeight: ExprOr<Double>?
}

struct TextFieldBorderProps: Decodable, Equatable, Sendable {
    let borderRadius: CornerRadiusProps?
    let borderStyle: String?
    let borderWidth: ExprOr<Double>?
    let borderColor: ExprOr<String>?
    let borderType: TextFieldBorderTypeProps?
}

struct TextFieldBorderTypeProps: Decodable, Equatable, Sendable {
    let value: String?
    let strokeCap: String?
    let dashPattern: [Double]?

    private enum CodingKeys: String, CodingKey {
        case value
        case strokeCap
        case dashPattern
    }

    init(value: String?, strokeCap: String?, dashPattern: [Double]?) {
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

struct CornerRadiusProps: Decodable, Equatable, Sendable {
    let topLeft: Double
    let topRight: Double
    let bottomRight: Double
    let bottomLeft: Double

    init(topLeft: Double, topRight: Double, bottomRight: Double, bottomLeft: Double) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    init(uniform value: Double) {
        self.init(topLeft: value, topRight: value, bottomRight: value, bottomLeft: value)
    }

    var isUniform: Bool {
        topLeft == topRight && topRight == bottomRight && bottomRight == bottomLeft
    }

    var uniformValue: Double { topLeft }

    init(from decoder: Decoder) throws {
        let singleValue = try decoder.singleValueContainer()

        if let value = try? singleValue.decode(Double.self) {
            self.init(topLeft: value, topRight: value, bottomRight: value, bottomLeft: value)
            return
        }

        if let value = try? singleValue.decode(Int.self) {
            let resolved = Double(value)
            self.init(topLeft: resolved, topRight: resolved, bottomRight: resolved, bottomLeft: resolved)
            return
        }

        if let values = try? singleValue.decode([Double].self) {
            try self.init(values: values)
            return
        }

        if let stringValue = try? singleValue.decode(String.self) {
            let values = stringValue
                .split(separator: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            try self.init(values: values)
            return
        }

        let object = try singleValue.decode(CornerRadiusObject.self)
        self.init(
            topLeft: object.topLeft?.resolved ?? 0,
            topRight: object.topRight?.resolved ?? 0,
            bottomRight: object.bottomRight?.resolved ?? 0,
            bottomLeft: object.bottomLeft?.resolved ?? 0
        )
    }

    private init(values: [Double]) throws {
        switch values.count {
        case 1:
            self.init(topLeft: values[0], topRight: values[0], bottomRight: values[0], bottomLeft: values[0])
        case 4:
            self.init(topLeft: values[0], topRight: values[1], bottomRight: values[2], bottomLeft: values[3])
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Corner radius expects 1 or 4 values")
            )
        }
    }
}

private struct CornerRadiusObject: Decodable, Equatable, Sendable {
    let topLeft: RadiusValue?
    let topRight: RadiusValue?
    let bottomRight: RadiusValue?
    let bottomLeft: RadiusValue?
}

private struct RadiusValue: Decodable, Equatable, Sendable {
    let resolved: Double

    init(from decoder: Decoder) throws {
        let singleValue = try decoder.singleValueContainer()
        if let value = try? singleValue.decode(Double.self) {
            resolved = value
            return
        }
        if let value = try? singleValue.decode(Int.self) {
            resolved = Double(value)
            return
        }
        let object = try singleValue.decode(RadiusObject.self)
        if let radius = object.radius {
            resolved = radius
            return
        }
        resolved = object.x ?? object.y ?? 0
    }
}

private struct RadiusObject: Decodable, Equatable, Sendable {
    let radius: Double?
    let x: Double?
    let y: Double?
}
