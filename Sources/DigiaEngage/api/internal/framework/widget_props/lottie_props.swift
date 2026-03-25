import Foundation

struct LottieProps: Decodable, Equatable, Sendable {
    let lottiePath: ExprOr<String>?
    let height: ExprOr<Double>?
    let width: ExprOr<Double>?
    let alignment: ExprOr<String>?
    let fit: ExprOr<String>?
    let animate: ExprOr<Bool>?
    let animationType: String?
    let frameRate: ExprOr<Double>?
    let onComplete: ActionFlow?

    private enum CodingKeys: String, CodingKey {
        case src
        case lottiePath
        case height
        case width
        case alignment
        case fit
        case animate
        case animationType
        case frameRate
        case onComplete
    }

    private struct SrcProps: Codable, Equatable, Sendable {
        let lottiePath: ExprOr<String>?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let src = try container.decodeIfPresent(SrcProps.self, forKey: .src)

        if let srcPath = src?.lottiePath {
            lottiePath = srcPath
        } else {
            lottiePath = try container.decodeIfPresent(ExprOr<String>.self, forKey: .lottiePath)
        }
        height = try container.decodeIfPresent(ExprOr<Double>.self, forKey: .height)
        width = try container.decodeIfPresent(ExprOr<Double>.self, forKey: .width)
        alignment = try container.decodeIfPresent(ExprOr<String>.self, forKey: .alignment)
        fit = try container.decodeIfPresent(ExprOr<String>.self, forKey: .fit)
        animate = try container.decodeIfPresent(ExprOr<Bool>.self, forKey: .animate)
        animationType = try container.decodeIfPresent(String.self, forKey: .animationType)
        frameRate = try container.decodeIfPresent(ExprOr<Double>.self, forKey: .frameRate)
        onComplete = try container.decodeIfPresent(ActionFlow.self, forKey: .onComplete)
    }
}
