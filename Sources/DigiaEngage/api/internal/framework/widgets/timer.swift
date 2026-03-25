import Foundation
import SwiftUI

@MainActor
final class VWTimer: VirtualStatelessWidget<TimerProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        guard let child else { return empty() }

        let duration = payload.eval(props.duration) ?? 0
        let initialValue = payload.eval(props.initialValue) ?? (props.isCountDown ? duration : 0)

        if duration < 0 {
            return child.toWidget(payload.copyWithChainedContext(makeContext(value: initialValue)))
        }

        let controller = payload.evalAny(props.controller) as? DigiaTimerController
        let updateInterval = TimeInterval(max(payload.eval(props.updateInterval) ?? 1, 0))
        let restartKey = TimerRenderKey(
            initialValue: initialValue,
            updateInterval: updateInterval,
            isCountDown: props.isCountDown,
            duration: duration,
            controllerID: controller.map(ObjectIdentifier.init)
        )

        return AnyView(
            InternalTimerWidget(
                controller: controller,
                initialValue: initialValue,
                updateInterval: updateInterval,
                isCountDown: props.isCountDown,
                duration: duration,
                onTick: props.onTick?.isEmpty == false ? { value in
                    let chained = payload.copyWithChainedContext(self.makeContext(value: value))
                    chained.executeAction(self.props.onTick, triggerType: "onTick", scopeContext: chained.scopeContext)
                } : nil,
                onTimerEnd: props.onTimerEnd?.isEmpty == false ? { value in
                    let chained = payload.copyWithChainedContext(self.makeContext(value: value))
                    chained.executeAction(self.props.onTimerEnd, triggerType: "onTimerEnd", scopeContext: chained.scopeContext)
                } : nil,
                content: { value in
                    child.toWidget(payload.copyWithChainedContext(self.makeContext(value: value)))
                }
            )
            .id(restartKey)
        )
    }

    private func makeContext(value: Int?) -> any ScopeContext {
        let timerObject: [String: Any?] = [
            "tickValue": value,
        ]

        var variables = timerObject
        if let refName {
            variables[refName] = timerObject
        }
        return BasicExprContext(variables: variables)
    }
}

private struct TimerRenderKey: Hashable {
    let initialValue: Int
    let updateInterval: TimeInterval
    let isCountDown: Bool
    let duration: Int
    let controllerID: ObjectIdentifier?
}

@MainActor
private struct InternalTimerWidget<Content: View>: View {
    let controller: DigiaTimerController?
    let initialValue: Int
    let updateInterval: TimeInterval
    let isCountDown: Bool
    let duration: Int
    let onTick: ((Int) -> Void)?
    let onTimerEnd: ((Int) -> Void)?
    let content: (Int?) -> Content

    @State private var currentValue: Int?
    @State private var tickToken: UUID?
    @State private var completionToken: UUID?
    @State private var internalController: DigiaTimerController?

    init(
        controller: DigiaTimerController?,
        initialValue: Int,
        updateInterval: TimeInterval,
        isCountDown: Bool,
        duration: Int,
        onTick: ((Int) -> Void)? = nil,
        onTimerEnd: ((Int) -> Void)? = nil,
        @ViewBuilder content: @escaping (Int?) -> Content
    ) {
        self.controller = controller
        self.initialValue = initialValue
        self.updateInterval = updateInterval
        self.isCountDown = isCountDown
        self.duration = duration
        self.onTick = onTick
        self.onTimerEnd = onTimerEnd
        self.content = content
        _currentValue = State(initialValue: initialValue)
        _internalController = State(
            initialValue: controller == nil ? DigiaTimerController(
                initialValue: initialValue,
                updateInterval: updateInterval,
                isCountDown: isCountDown,
                duration: duration
            ) : nil
        )
    }

    var body: some View {
        content(currentValue)
            .onAppear(perform: bind)
            .onDisappear(perform: unbind)
    }

    private var effectiveController: DigiaTimerController {
        controller ?? internalController!
    }

    private func bind() {
        let effectiveController = effectiveController
        currentValue = effectiveController.currentValue as? Int ?? initialValue

        if tickToken == nil {
            tickToken = effectiveController.subscribe { nextValue in
                let resolved = nextValue as? Int ?? initialValue
                DispatchQueue.main.async {
                    currentValue = resolved
                    onTick?(resolved)
                }
            }
        }

        if completionToken == nil {
            completionToken = effectiveController.subscribeCompletion { finalValue in
                DispatchQueue.main.async {
                    currentValue = finalValue
                    onTimerEnd?(finalValue)
                }
            }
        }

        effectiveController.start()
    }

    private func unbind() {
        let effectiveController = effectiveController

        if let tickToken {
            effectiveController.unsubscribe(tickToken)
        }
        if let completionToken {
            effectiveController.unsubscribeCompletion(completionToken)
        }

        self.tickToken = nil
        self.completionToken = nil

        if controller == nil {
            effectiveController.dispose()
        }
    }
}

final class DigiaTimerController: DigiaValueStream, ExprInstance, @unchecked Sendable {
    private let stateQueue = DispatchQueue(label: "com.digia.engage.timer.controller")
    private var listeners: [UUID: @Sendable (Any?) -> Void] = [:]
    private var completionListeners: [UUID: @Sendable (Int) -> Void] = [:]
    private var timer: DispatchSourceTimer?
    private var isRunning = false
    private var isPaused = false
    private var hasCompleted = false
    private var emittedCount = 0

    let initialValue: Int
    let updateInterval: TimeInterval
    let isCountDown: Bool
    let duration: Int

    init(
        initialValue: Int,
        updateInterval: TimeInterval,
        isCountDown: Bool,
        duration: Int
    ) {
        self.initialValue = initialValue
        self.updateInterval = max(updateInterval, 0.001)
        self.isCountDown = isCountDown
        self.duration = duration
        currentResolvedValue = initialValue
    }

    private var currentResolvedValue: Int

    var currentValue: Any? {
        stateQueue.sync { currentResolvedValue }
    }

    @discardableResult
    func subscribe(_ onValue: @escaping @Sendable (Any?) -> Void) -> UUID {
        stateQueue.sync {
            let token = UUID()
            listeners[token] = onValue
            return token
        }
    }

    func unsubscribe(_ token: UUID) {
        stateQueue.sync {
            listeners.removeValue(forKey: token)
        }
    }

    @discardableResult
    func subscribeCompletion(_ onCompletion: @escaping @Sendable (Int) -> Void) -> UUID {
        stateQueue.sync {
            let token = UUID()
            completionListeners[token] = onCompletion
            return token
        }
    }

    func unsubscribeCompletion(_ token: UUID) {
        stateQueue.sync {
            completionListeners.removeValue(forKey: token)
        }
    }

    func start() {
        stateQueue.async {
            guard !self.isRunning else { return }
            if self.hasCompleted {
                self.resetLocked(shouldRestart: false)
            }
            self.isRunning = true
            self.isPaused = false
            self.scheduleTimerLocked()
        }
    }

    func reset() {
        stateQueue.async {
            self.resetLocked(shouldRestart: true)
        }
    }

    func pause() {
        stateQueue.async {
            guard self.isRunning else { return }
            self.invalidateTimerLocked()
            self.isRunning = false
            self.isPaused = true
        }
    }

    func resume() {
        stateQueue.async {
            guard self.isPaused, !self.hasCompleted else { return }
            self.isRunning = true
            self.isPaused = false
            self.scheduleTimerLocked()
        }
    }

    func dispose() {
        stateQueue.async {
            self.invalidateTimerLocked()
            self.isRunning = false
            self.isPaused = false
            self.listeners.removeAll()
            self.completionListeners.removeAll()
        }
    }

    func getField(_ name: String) throws -> ExprValue? {
        switch name {
        case "currentValue":
            return ExprValue.from(currentValue)
        default:
            throw ExpressionError.undefinedProperty(name)
        }
    }

    private func resetLocked(shouldRestart: Bool) {
        invalidateTimerLocked()
        emittedCount = 0
        currentResolvedValue = initialValue
        isRunning = false
        isPaused = false
        hasCompleted = false

        if shouldRestart {
            isRunning = true
            scheduleTimerLocked()
        }
    }

    private func scheduleTimerLocked() {
        invalidateTimerLocked()

        let timer = DispatchSource.makeTimerSource(queue: stateQueue)
        timer.schedule(deadline: .now() + updateInterval, repeating: updateInterval)
        timer.setEventHandler { [weak self] in
            self?.handleTickLocked()
        }
        self.timer = timer
        timer.resume()
    }

    private func handleTickLocked() {
        let nextValue = resolvedValue(forEmissionAt: emittedCount)
        currentResolvedValue = nextValue

        let currentListeners = Array(listeners.values)
        currentListeners.forEach { $0(nextValue) }

        emittedCount += 1
        if emittedCount >= totalTickCount {
            completeLocked(finalValue: nextValue)
        }
    }

    private func completeLocked(finalValue: Int) {
        invalidateTimerLocked()
        isRunning = false
        isPaused = false
        hasCompleted = true

        let currentCompletionListeners = Array(completionListeners.values)
        currentCompletionListeners.forEach { $0(finalValue) }
    }

    private func invalidateTimerLocked() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    private var totalTickCount: Int {
        max(duration, 0) + 1
    }

    private func resolvedValue(forEmissionAt count: Int) -> Int {
        if isCountDown {
            return initialValue - count
        }
        return initialValue + count
    }

    deinit {
        timer?.setEventHandler {}
        timer?.cancel()
    }
}
