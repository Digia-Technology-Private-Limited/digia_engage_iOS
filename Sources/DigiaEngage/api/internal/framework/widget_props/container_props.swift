import Foundation

struct ContainerProps: Decodable, Equatable, Sendable {
    var color: ExprOr<String>? = nil
    var padding: Spacing? = nil
    var margin: Spacing? = nil
    var width: ExprOr<Double>? = nil
    var height: ExprOr<Double>? = nil
    var minWidth: ExprOr<Double>? = nil
    var minHeight: ExprOr<Double>? = nil
    var maxWidth: ExprOr<Double>? = nil
    var maxHeight: ExprOr<Double>? = nil
    var childAlignment: String? = nil
    var borderRadius: CornerRadiusProps? = nil
    var border: BorderStyle? = nil
    var shape: String? = nil
    var elevation: Double? = nil
    var shadow: [ShadowStyle]? = nil
    var gradiant: GradientStyle? = nil
}

struct ShadowStyle: Decodable, Equatable, Sendable {
    let color: ExprOr<String>?
    let blur: ExprOr<Double>?
    let spreadRadius: ExprOr<Double>?
    let offset: ShadowOffset?
    let blurStyle: String?
}

struct ShadowOffset: Decodable, Equatable, Sendable {
    let x: ExprOr<Double>?
    let y: ExprOr<Double>?
}

struct GradientStyle: Decodable, Equatable, Sendable {
    let colors: [String]?
    let begin: String?
    let end: String?
    let colorList: [GradientColorStop]?

    var resolvedColors: [String]? {
        if let colors, !colors.isEmpty { return colors }
        let fromStops = colorList?.compactMap(\.color)
        return (fromStops?.isEmpty ?? true) ? nil : fromStops
    }
}

struct GradientColorStop: Decodable, Equatable, Sendable {
    let color: String?
    let stop: Double?
}
