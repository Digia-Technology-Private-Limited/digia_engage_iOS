import Foundation

struct CircularProgressBarProps: Codable, Equatable, Sendable {
    let progressValue: ExprOr<Double>?
    let size: ExprOr<Double>?
    let thickness: ExprOr<Double>?
    let type: String?
    let indicatorColor: ExprOr<String>?
    let bgColor: ExprOr<String>?
    let animation: Bool?
    let animateFromLastPercent: Bool?
}
