import Foundation

struct LinearProgressBarProps: Codable, Equatable, Sendable {
    let progressValue: ExprOr<Double>?
    let width: ExprOr<Double>?
    let thickness: ExprOr<Double>?
    let type: String?
    let indicatorColor: ExprOr<String>?
    let bgColor: ExprOr<String>?
    let borderRadius: ExprOr<Double>?
    let isReverse: ExprOr<Bool>?
    let animation: Bool?
    let animateFromLastPercent: Bool?
}
