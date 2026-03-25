import Foundation

struct StoryVideoPlayerProps: Decodable, Equatable, Sendable {
    let videoUrl: ExprOr<String>?
    let autoPlay: ExprOr<Bool>?
    let looping: ExprOr<Bool>?
    let fit: ExprOr<String>?

    let dataSource: JSONValue?
    let controller: JSONValue?
    let onComplete: ActionFlow?
    let onSlideDown: ActionFlow?
    let onSlideStart: ActionFlow?
    let onLeftTap: ActionFlow?
    let onRightTap: ActionFlow?
    let onPreviousCompleted: ActionFlow?
    let onStoryChanged: ActionFlow?
    let initialIndex: ExprOr<Int>?
    let restartOnCompleted: ExprOr<Bool>?
    let duration: ExprOr<Int>?
    let indicator: StoryIndicatorProps?

    private enum CodingKeys: String, CodingKey {
        case videoUrl
        case autoPlay
        case looping
        case fit
        case dataSource
        case controller
        case onComplete
        case onSlideDown
        case onSlideStart
        case onLeftTap
        case onRightTap
        case onPreviousCompleted
        case onStoryChanged
        case initialIndex
        case restartOnCompleted
        case duration
        case indicator
    }
}
