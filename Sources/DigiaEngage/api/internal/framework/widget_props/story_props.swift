import Foundation

struct StoryIndicatorProps: Decodable, Equatable, Sendable {
    let activeColor: ExprOr<String>?
    let backgroundCompletedColor: ExprOr<String>?
    let backgroundDisabledColor: ExprOr<String>?
    let height: Double?
    let borderRadius: Double?
    let horizontalGap: Double?
    let margin: Spacing?
    let alignment: String?
    let enableBottomSafeArea: Bool?
    let enableTopSafeArea: Bool?
}

struct StoryProps: Decodable, Equatable, Sendable {
    let dataSource: JSONValue?
    let controller: JSONValue?
    let onSlideDown: ActionFlow?
    let onSlideStart: ActionFlow?
    let onLeftTap: ActionFlow?
    let onRightTap: ActionFlow?
    let onCompleted: ActionFlow?
    let onPreviousCompleted: ActionFlow?
    let onStoryChanged: ActionFlow?
    let indicator: StoryIndicatorProps?
    let initialIndex: ExprOr<Int>?
    let restartOnCompleted: ExprOr<Bool>?
    let duration: ExprOr<Int>?

    private enum CodingKeys: String, CodingKey {
        case dataSource
        case controller
        case onSlideDown
        case onSlideStart
        case onLeftTap
        case onRightTap
        case onCompleted
        case onPreviousCompleted
        case onStoryChanged
        case indicator
        case initialIndex
        case restartOnCompleted
        case duration
    }
}
