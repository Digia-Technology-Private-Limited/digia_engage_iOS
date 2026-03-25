import Foundation

struct AvatarProps: Decodable, Equatable, Sendable {
    let bgColor: ExprOr<String>?
    let image: ImageProps?
    let text: TextProps?
    let shape: AvatarShapeProps?
}

struct AvatarShapeProps: Decodable, Equatable, Sendable {
    let value: String?
    let radius: Double?
    let side: Double?
    let cornerRadius: Spacing?
}
