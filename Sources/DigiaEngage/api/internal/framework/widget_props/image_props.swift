import Foundation

struct ImageProps: Codable, Equatable, Sendable {
    let imageType: String?
    let imageSrc: ExprOr<String>?
    let src: ImageSourceProps?
    let fit: String?
    let opacity: ExprOr<Double>?
    let alignment: String?
    let aspectRatio: ExprOr<Double>?
    let placeholderSrc: String?
    let placeholder: String?
    let errorImage: ErrorImageProps?
    let type: String?
    let source: String?
    let svgColor: ExprOr<String>?

    private enum CodingKeys: String, CodingKey {
        case imageType
        case imageSrc
        case src
        case fit
        case opacity
        case alignment
        case aspectRatio
        case placeholderSrc
        case placeholder
        case errorImage
        case type
        case source
        case svgColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageType = try? container.decodeIfPresent(String.self, forKey: .imageType)
        imageSrc = try? container.decodeIfPresent(ExprOr<String>.self, forKey: .imageSrc)
        src = try? container.decodeIfPresent(ImageSourceProps.self, forKey: .src)
        fit = try? container.decodeIfPresent(String.self, forKey: .fit)
        opacity = try? container.decodeIfPresent(ExprOr<Double>.self, forKey: .opacity)
        alignment = try? container.decodeIfPresent(String.self, forKey: .alignment)
        aspectRatio = try? container.decodeIfPresent(ExprOr<Double>.self, forKey: .aspectRatio)
        placeholderSrc = try? container.decodeIfPresent(String.self, forKey: .placeholderSrc)
        placeholder = try? container.decodeIfPresent(String.self, forKey: .placeholder)
        errorImage = ImageProps.decodeErrorImage(from: container)
        type = try? container.decodeIfPresent(String.self, forKey: .type)
        source = try? container.decodeIfPresent(String.self, forKey: .source)
        svgColor = try? container.decodeIfPresent(ExprOr<String>.self, forKey: .svgColor)
    }

    private static func decodeErrorImage(from container: KeyedDecodingContainer<CodingKeys>) -> ErrorImageProps? {
        if let value = try? container.decodeIfPresent(ErrorImageProps.self, forKey: .errorImage) {
            return value
        }

        if let value = (try? container.decodeIfPresent(String.self, forKey: .errorImage)) ?? nil {
            return ErrorImageProps(errorEnabled: nil, errorSrc: value)
        }

        guard let scope = try? container.decodeIfPresent(JSONValue.self, forKey: .errorImage) else {
            return nil
        }

        switch scope {
        case let .string(src):
            return ErrorImageProps(errorEnabled: nil, errorSrc: src)
        case let .object(object):
            let enabled: Bool?
            if case let .bool(flag)? = object["errorEnabled"] {
                enabled = flag
            } else {
                enabled = nil
            }

            let src: String?
            if case let .string(value)? = object["errorSrc"] {
                src = value
            } else if case let .string(value)? = object["src"] {
                src = value
            } else if case let .string(value)? = object["imageSrc"] {
                src = value
            } else {
                src = nil
            }
            return ErrorImageProps(errorEnabled: enabled, errorSrc: src)
        default:
            return nil
        }
    }
}

struct ImageSourceProps: Codable, Equatable, Sendable {
    let imageSrc: ExprOr<String>?
}

struct ErrorImageProps: Codable, Equatable, Sendable {
    let errorEnabled: Bool?
    let errorSrc: String?

    init(errorEnabled: Bool?, errorSrc: String?) {
        self.errorEnabled = errorEnabled
        self.errorSrc = errorSrc
    }

    private enum CodingKeys: String, CodingKey {
        case errorEnabled
        case errorSrc
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            errorEnabled = try container.decodeIfPresent(Bool.self, forKey: .errorEnabled)
            errorSrc = try container.decodeIfPresent(String.self, forKey: .errorSrc)
            return
        }

        let singleValue = try decoder.singleValueContainer()
        if let src = try? singleValue.decode(String.self) {
            self = ErrorImageProps(errorEnabled: nil, errorSrc: src)
            return
        }

        self = ErrorImageProps(errorEnabled: nil, errorSrc: nil)
    }
}
