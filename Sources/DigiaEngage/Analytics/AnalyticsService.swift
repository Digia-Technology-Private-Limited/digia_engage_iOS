import Foundation
import UIKit

// MARK: - AnalyticsSender

protocol AnalyticsSender: Sendable {
    func post(url: String, body: Data, headers: [String: String]) async throws -> Int
}

struct URLSessionAnalyticsSender: AnalyticsSender {
    func post(url: String, body: Data, headers: [String: String]) async throws -> Int {
        guard let endpoint = URL(string: url) else { throw URLError(.badURL) }
        var request = URLRequest(url: endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        request.httpBody = body
        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode ?? 0
    }
}

// MARK: - AnalyticsService

@MainActor
final class AnalyticsService {
    private let config: AnalyticsConfig
    private let apiKey: String
    let identity: AnalyticsIdentityManager
    let queue: AnalyticsQueue
    private let staticContext: [String: Any]
    private let sender: any AnalyticsSender

    private var flushTimer: Timer?
    private var isDispatching = false
    private(set) var retryAttempt = 0
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    /// Override retry delays (ms) for testing. Index is attempt-1.
    var retryScheduleMs: [Int]?

    init(
        config: AnalyticsConfig,
        apiKey: String,
        identity: AnalyticsIdentityManager,
        queue: AnalyticsQueue,
        staticContext: [String: Any],
        sender: any AnalyticsSender = URLSessionAnalyticsSender()
    ) {
        self.config = config
        self.apiKey = apiKey
        self.identity = identity
        self.queue = queue
        self.staticContext = staticContext
        self.sender = sender

        identity.initialize(sessionTimeoutMs: config.sessionTimeoutMs)

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.cancelTimer()
                await self.dispatchPending()
            }
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.identity.maybeExpireSession()
            }
        }

        if queue.size > 0 {
            scheduleTimer()
        }
    }

    // MARK: - Public

    func capture(_ event: DigiaExperienceEvent, payload: InAppPayload) {
        guard config.enabled else {
            print("[DigiaAnalytics] capture: DISABLED — event '\(event.analyticsEventName)' dropped")
            return
        }
        let campaignKey = payload.content.campaignKey ?? argString(payload.content.args["campaign_key"])
        let campaignId = argString(payload.content.args["campaign_id"]) ?? payload.id
        let campaignType = payload.content.type.isEmpty ? nil : payload.content.type
        print("[DigiaAnalytics] capture: event='\(event.analyticsEventName)' campaignKey=\(campaignKey ?? "nil") campaignId=\(campaignId)")

        let elementId: String?
        if case .clicked(let eid) = event { elementId = eid } else { elementId = nil }

        enqueue(
            eventName: event.analyticsEventName,
            campaignId: campaignId,
            campaignKey: campaignKey,
            campaignType: campaignType,
            extraProperties: elementId.map { ["element_id": $0] } ?? [:]
        )
    }

    /// The single entry point for the analytics event matrix. Renderers assemble
    /// the snake_case `properties` map at the call site (e.g. display_style,
    /// item_index, time_to_action_ms) and name the event explicitly. Mirrors the
    /// Android `AnalyticsService.capture(eventName:…)` / Flutter `capture`. Pass
    /// `flush` for terminal events (Experience Dismissed / Completed).
    func capture(
        eventName: String,
        payload: InAppPayload,
        properties: [String: Any] = [:],
        flush: Bool = false
    ) {
        guard config.enabled else { return }
        let campaignKey = payload.content.campaignKey ?? argString(payload.content.args["campaign_key"])
        let campaignId = argString(payload.content.args["campaign_id"]) ?? payload.id
        let campaignType = payload.content.type.isEmpty ? nil : payload.content.type
        enqueue(
            eventName: eventName,
            campaignId: campaignId,
            campaignKey: campaignKey,
            campaignType: campaignType,
            extraProperties: properties
        )
        if flush { self.flush() }
    }

    func setUserId(_ userId: String) {
        identity.setUserId(userId)
    }

    func clearUserId() {
        identity.clearUserId()
    }

    func flush() {
        cancelTimer()
        Task { await dispatchPending() }
    }

    /// Cancels timers and removes lifecycle observers. Call before releasing the service.
    func clear() {
        cancelTimer()
        if let obs = backgroundObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = foregroundObserver { NotificationCenter.default.removeObserver(obs) }
        backgroundObserver = nil
        foregroundObserver = nil
        isDispatching = false
        retryAttempt = 0
    }

    /// Cancels in-flight state without clearing the queue. Mirrors Android's resetForTest().
    func resetForTest() {
        cancelTimer()
        isDispatching = false
        retryAttempt = 0
    }

    // MARK: - Factory

    @MainActor
    static func create(config: DigiaConfig) -> AnalyticsService? {
        let ac = config.analyticsConfig
        guard ac.enabled else {
            print("[DigiaAnalytics] create: analytics DISABLED in DigiaConfig — no events will be captured")
            return nil
        }
        print("[DigiaAnalytics] create: analytics enabled, endpoint=\(ac.endpointUrl) batchSize=\(ac.flushBatchSize) interval=\(ac.flushIntervalMs)ms")
        return AnalyticsService(
            config: ac,
            apiKey: config.apiKey,
            identity: AnalyticsIdentityManager(),
            queue: AnalyticsQueue(),
            staticContext: buildStaticContext()
        )
    }

    // MARK: - Private

    private func enqueue(
        eventName: String,
        campaignId: String?,
        campaignKey: String?,
        campaignType: String?,
        extraProperties: [String: Any] = [:]
    ) {
        let eventId = UUID().uuidString
        identity.captureEventTime()

        var properties = staticContext
        for (k, v) in extraProperties { properties[k] = v }

        var payloadMap: [String: Any] = [
            "event_id": eventId,
            "event_name": eventName,
            "occurred_at": isoNow(),
            "anonymous_id": identity.anonymousId,
            "session_id": identity.sessionId,
            "properties": properties,
        ]
        if let id = campaignId { payloadMap["campaign_id"] = id }
        if let key = campaignKey { payloadMap["campaign_key"] = key }
        if let type = campaignType { payloadMap["campaign_type"] = type }
        if let uid = identity.userId { payloadMap["user_id"] = uid }

        queue.append(
            QueueEntry(eventId: eventId, payload: payloadMap, createdAt: Date().timeIntervalSince1970, attempts: 0),
            maxEvents: config.queueMaxEvents
        )
        print("[DigiaAnalytics] enqueued '\(eventName)' eventId=\(eventId) queueSize=\(queue.size) flushBatchSize=\(config.flushBatchSize)")

        if queue.size >= config.flushBatchSize {
            print("[DigiaAnalytics] batch threshold reached — dispatching immediately")
            cancelTimer()
            Task { await dispatchPending() }
        } else {
            print("[DigiaAnalytics] scheduling flush timer (interval=\(config.flushIntervalMs)ms)")
            scheduleTimer()
        }
    }

    private func dispatchPending() async {
        guard !isDispatching else {
            print("[DigiaAnalytics] dispatchPending: already dispatching — skipped")
            return
        }
        cancelTimer()
        isDispatching = true
        defer { isDispatching = false }

        let batch = queue.peek(maxCount: config.maxBatchSize)
        guard !batch.isEmpty else {
            print("[DigiaAnalytics] dispatchPending: queue empty — nothing to send")
            retryAttempt = 0
            return
        }

        print("[DigiaAnalytics] dispatchPending: sending batch of \(batch.count) event(s) to \(config.endpointUrl)")
        queue.incrementAttempt(eventIds: batch.map { $0.eventId })

        do {
            let body = try JSONSerialization.data(withJSONObject: ["events": batch.map { $0.payload }])
            let statusCode = try await sender.post(
                url: config.endpointUrl,
                body: body,
                headers: [
                    "Content-Type": "application/json",
                    "X-Digia-Project-Id": apiKey,
                    "X-Digia-Device-Id": identity.anonymousId,
                ]
            )
            print("[DigiaAnalytics] dispatchPending: HTTP \(statusCode)")

            switch statusCode {
            case 200, 207:
                queue.remove(eventIds: batch.map { $0.eventId })
                retryAttempt = 0
                print("[DigiaAnalytics] dispatch success — removed \(batch.count) event(s), queueSize=\(queue.size)")
                if queue.size > 0 { scheduleTimer(minDelayMs: 15_000) }
            case 500...:
                print("[DigiaAnalytics] dispatch failed (5xx \(statusCode)) — scheduling retry #\(retryAttempt + 1)")
                scheduleRetry()
            default:
                print("[DigiaAnalytics] dispatch failed (\(statusCode)) — dropping batch")
                queue.remove(eventIds: batch.map { $0.eventId })
                retryAttempt = 0
                if queue.size > 0 { scheduleTimer(minDelayMs: 15_000) }
            }
        } catch {
            print("[DigiaAnalytics] dispatchPending: exception — \(error.localizedDescription)")
            scheduleRetry()
        }
    }

    private func scheduleTimer(minDelayMs: Int = 0) {
        guard flushTimer == nil, !isDispatching else { return }
        let delayMs = max(config.flushIntervalMs, minDelayMs)
        flushTimer = Timer.scheduledTimer(
            withTimeInterval: Double(delayMs) / 1_000,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.flushTimer = nil
                await self.dispatchPending()
            }
        }
    }

    private func cancelTimer() {
        flushTimer?.invalidate()
        flushTimer = nil
    }

    private func scheduleRetry() {
        retryAttempt += 1
        let delayNs = UInt64(retryDelayMs(retryAttempt)) * 1_000_000
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNs)
            guard let self else { return }
            await self.dispatchPending()
        }
    }

    private func retryDelayMs(_ attempt: Int) -> Int {
        if let schedule = retryScheduleMs {
            let idx = max(0, min(attempt - 1, schedule.count - 1))
            return schedule[idx]
        }
        return min(1_000 * (1 << (attempt - 1)), 16_000)
    }

    private func isoNow() -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.string(from: Date())
    }

    private func argString(_ value: JSONValue?) -> String? {
        guard case .string(let s) = value, !s.isEmpty else { return nil }
        return s
    }

    private static func buildStaticContext() -> [String: Any] {
        var ctx: [String: Any] = [
            "sdk_version": "1.0.0",
            "sdk_platform": "ios",
            "device_platform": "ios",
            "device_make": "Apple",
            "app_locale": Locale.current.identifier,
        ]
        let os = ProcessInfo.processInfo.operatingSystemVersion
        ctx["os_version"] = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            ctx["app_version"] = version
        }
        var sysInfo = utsname()
        uname(&sysInfo)
        let machine = withUnsafePointer(to: &sysInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        if !machine.isEmpty { ctx["device_model"] = machine }
        return ctx
    }
}

// MARK: - Event name mapping

private extension DigiaExperienceEvent {
    var analyticsEventName: String {
        switch self {
        case .impressed: return "Digia Experience Viewed"
        case .clicked: return "Digia Experience Clicked"
        case .dismissed: return "Digia Experience Dismissed"
        }
    }
}
