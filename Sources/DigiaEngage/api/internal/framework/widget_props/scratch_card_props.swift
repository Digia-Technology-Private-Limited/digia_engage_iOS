import Foundation

struct ScratchCardProps: Codable, Equatable, Sendable {
    let height: String?
    let width: String?
    let brushSize: ExprOr<Double>?
    let revealFullAtPercent: ExprOr<Double>?
    let isScratchingEnabled: ExprOr<Bool>?
    let gridResolution: ExprOr<Int>?
    let enableTapToScratch: ExprOr<Bool>?
    let brushColor: ExprOr<String>?
    let brushOpacity: ExprOr<Double>?
    let brushShape: ExprOr<String>?
    let enableHapticFeedback: ExprOr<Bool>?
    let revealAnimationType: ExprOr<String>?
    let animationDurationMs: ExprOr<Int>?
    let enableProgressAnimation: ExprOr<Bool>?
    let onScratchComplete: ActionFlow?
}
