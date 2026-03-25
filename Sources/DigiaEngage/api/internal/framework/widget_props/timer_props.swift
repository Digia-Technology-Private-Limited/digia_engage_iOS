import Foundation

struct TimerProps: Decodable, Equatable, Sendable {
    private static let countDownTimerTypeValue = "countDown"

    let controller: JSONValue?
    let duration: ExprOr<Int>?
    let updateInterval: ExprOr<Int>?
    private let timerType: String?
    let initialValue: ExprOr<Int>?
    let onTick: ActionFlow?
    let onTimerEnd: ActionFlow?

    var isCountDown: Bool {
        (timerType ?? Self.countDownTimerTypeValue) == Self.countDownTimerTypeValue
    }

    init(
        controller: JSONValue?,
        duration: ExprOr<Int>?,
        updateInterval: ExprOr<Int>?,
        timerType: String?,
        initialValue: ExprOr<Int>?,
        onTick: ActionFlow?,
        onTimerEnd: ActionFlow?
    ) {
        self.controller = controller
        self.duration = duration
        self.updateInterval = updateInterval
        self.timerType = timerType
        self.initialValue = initialValue
        self.onTick = onTick
        self.onTimerEnd = onTimerEnd
    }
}
