import Foundation

struct ButtonProps: Codable, Equatable, Sendable {
    let buttonState: String?
    let isDisabled: ExprOr<Bool>?
    let disabledStyle: ButtonVisualStyle?
    let defaultStyle: ButtonVisualStyle?
    let text: ButtonTextProps?
    let leadingIcon: ButtonIconProps?
    let trailingIcon: ButtonIconProps?
    let shape: ButtonShapeProps?
    let onClick: ActionFlow?
}

struct ButtonVisualStyle: Codable, Equatable, Sendable {
    let backgroundColor: String?
    let padding: Spacing?
    let elevation: Double?
    let alignment: String?
    let height: ExprOr<Double>?
    let width: ExprOr<Double>?
    let disabledTextColor: String?
    let disabledIconColor: String?
    let shadowColor: String?
}

struct ButtonTextProps: Codable, Equatable, Sendable {
    let text: ExprOr<String>?
    let textStyle: TextStyleProps?
    let maxLines: ExprOr<Int>?
    let overflow: ExprOr<String>?
}

struct ButtonShapeProps: Codable, Equatable, Sendable {
    let value: String?
    let borderRadius: Spacing?
    let borderColor: String?
    let borderWidth: Double?
    let borderStyle: String?
}

struct ButtonIconProps: Codable, Equatable, Sendable {
    let iconData: IconDataProps?
    let iconSize: Double?
    let iconColor: String?
}

struct IconDataProps: Codable, Equatable, Sendable {
    let pack: String?
    let key: String?
}
