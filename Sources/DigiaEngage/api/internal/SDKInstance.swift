import Foundation

@MainActor
final class SDKInstance: ObservableObject, DigiaCEPDelegate {
    static let shared = SDKInstance()

    @Published private(set) var config: DigiaConfig?
    @Published private(set) var sdkState: SDKState = .notInitialized
    @Published private(set) var isHostMounted = false

    private var activePlugin: DigiaCEPPlugin?
    private(set) var fontFactory: DUIFontFactory = DefaultFontFactory()

    let campaignStore = CampaignStore()
    let controller = DigiaOverlayController()
    let inlineController = InlineCampaignController()
    let guideOrchestrator = GuideOrchestrator()
    let surveyOrchestrator = SurveyOrchestrator()

    private var completedSurveyToken: Int64?
    /// Survey whose start-engagement ("welcome_start") click has already fired
    /// (once per showing).
    private var welcomeStartToken: Int64?
    private var analyticsService: AnalyticsService?

    // Event system (mirrors Android): a fan-out emitter over two sinks — the
    // coarse CEP channel (`toCep`) and Digia's rich analytics (`toDigia`).
    // Campaign id/type are resolved from the store inside the Digia sink.
    private let dwellTracker = DwellTracker()
    private var events: EngageEventEmitter!

    private init() {
        events = EngageEventEmitter(
            cep: CepPluginSink { [weak self] event, payload in
                self?.activePlugin?.notifyEvent(event, payload: payload)
            },
            digia: DigiaAnalyticsSink(
                getAnalyticsService: { [weak self] in self?.analyticsService },
                getCampaign: { [weak self] key in self?.campaignStore.find(key) }
            )
        )
    }

    func initialize(_ config: DigiaConfig) async throws {
        guard self.config == nil else { return }
        self.config = config
        DigiaEndpoints.configure(config)

        if let family = config.fontFamily?.trimmingCharacters(in: .whitespacesAndNewlines),
            !family.isEmpty
        {
            fontFactory = ConfiguredFontFactory(fontFamily: family)
        }

        do {
            let campaigns = try await CampaignFetcher(config: config).fetch()
            campaignStore.populate(campaigns)
            if campaignStore.isEmpty {
                logVerbose("No campaigns fetched — CampaignStore is empty")
            }
        } catch {
            // Campaign fetch failure must not block SDK readiness.
            logVerbose("CampaignFetcher failed: \(error)")
        }

        sdkState = .ready
        analyticsService = AnalyticsService.create(config: config)

        if let plugin = activePlugin, !plugin.healthCheck().isHealthy {
            plugin.setup(delegate: self)
        }
    }

    private func logVerbose(_ message: String) {
        guard config?.logLevel == .verbose else { return }
        print("Digia [SDKInstance] \(message)")
    }

    func register(_ plugin: DigiaCEPPlugin) {
        activePlugin?.teardown()
        activePlugin = plugin
        plugin.setup(delegate: self)
    }

    func registerFontFactory(_ factory: DUIFontFactory) {
        fontFactory = factory
    }

    func registerPlaceholderForSlot(propertyID: String) -> Int? {
        activePlugin?.registerPlaceholder(propertyID: propertyID)
    }

    func deregisterPlaceholderForSlot(_ id: Int) {
        activePlugin?.deregisterPlaceholder(id)
    }

    func onHostMounted() {
        isHostMounted = true
    }

    func onHostUnmounted() {
        isHostMounted = false
    }

    func onCampaignTriggered(_ payload: InAppPayload) {
        logVerbose(
            "onCampaignTriggered id='\(payload.id)' type='\(payload.content.type)' "
            + "campaignKey='\(payload.content.campaignKey ?? "nil")' "
            + "placementKey='\(payload.content.placementKey ?? "nil")'")
        // campaign_key path (native CEP plugins, e.g. CleverTap): resolve the full
        // campaign from the store and route by campaignType, mirroring Android.
        // The key may arrive either in content.campaignKey or — as the RN bridge
        // sends it — as payload.id. Mirror Android's fallback chain
        // (campaign_key ?? digiaKey ?? payload.id) and route whenever the resolved
        // key matches a known campaign, so inline/survey/nudge/guide campaigns
        // delivered without an explicit content.campaignKey still work.
        func argKey(_ key: String) -> String? {
            if case .string(let value)? = payload.content.args[key] {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            return nil
        }
        let explicitKey = payload.content.campaignKey?.trimmingCharacters(
            in: .whitespacesAndNewlines)
        let fallbackKey = payload.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedKey =
            (explicitKey?.isEmpty == false ? explicitKey : nil)
            ?? argKey("campaign_key") ?? argKey("campaignKey")
            ?? (fallbackKey.isEmpty ? nil : fallbackKey)

        logVerbose("onCampaignTriggered resolvedKey='\(resolvedKey ?? "nil")'")
        if let campaignKey = resolvedKey, campaignStore.find(campaignKey) != nil {
            routeByCampaignKey(campaignKey, payload: payload)
            return
        }

        // Fallback: RN-triggered campaigns may omit `campaignKey`. If the payload id
        // matches a stored campaign, route by it (covers native nudges via the RN bridge).
        if campaignStore.find(payload.id) != nil {
            routeByCampaignKey(payload.id, payload: payload)
            return
        }

        // Typed path (RN/JS-driven): content already carries display info.
        let displayType = payload.content.type.lowercased()
        let placementKey = payload.content.placementKey?.trimmingCharacters(
            in: .whitespacesAndNewlines)
        let viewId = payload.content.viewId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = payload.content.command?.uppercased() ?? ""

        let routeInline: Bool = {
            if displayType == "inline", let pk = placementKey, !pk.isEmpty { return true }
            if let pk = placementKey, !pk.isEmpty, let vid = viewId, !vid.isEmpty {
                if command.isEmpty || command == "SHOW_INLINE" { return true }
            }
            return false
        }()

        if routeInline, let pk = placementKey, !pk.isEmpty {
            inlineController.setCampaign(pk, payload: payload)
        } else {
            controller.show(payload)
        }
    }

    private func routeByCampaignKey(_ key: String, payload: InAppPayload) {
        guard let campaign = campaignStore.find(key) else {
            logVerbose("campaign_key path: no campaign found for key '\(key)'")
            return
        }

        logVerbose("routeByCampaignKey key='\(key)' type='\(campaign.campaignType)'")
        // The lean lifecycle payload carried through the event flow. Identity is
        // the CEP's id; campaign id/type are resolved from the store at event time.
        let trigger = CEPTriggerPayload(
            cepCampaignId: payload.id,
            campaignKey: key,
            cepMetadata: payload.cepContext,
            variables: payload.content.variables
        )
        switch campaign.config {
        case .inline(let cfg):
            logVerbose("routeByCampaignKey INLINE slotKey='\(cfg.slotKey)' items=\(cfg.items.count)")
            inlineController.setCarouselConfig(cfg.slotKey, config: cfg)
            inlineController.setCampaign(cfg.slotKey, payload: trigger)
            // syncTemplate semantics: CEP considers an inline slot shown and done
            // the moment it is delivered. Digia's impression fires only when the
            // slot first renders (see reportSlotFirstRender).
            events.toCep(.impressed, payload: trigger)
            events.toCep(.dismissed, payload: trigger)
        case .story(let cfg):
            inlineController.setStoryConfig(cfg.slotKey, config: cfg)
            inlineController.setCampaign(cfg.slotKey, payload: trigger)
            events.toCep(.impressed, payload: trigger)
            events.toCep(.dismissed, payload: trigger)
        case .guide:
            dwellTracker.markViewed(trigger.cepCampaignId)
            guideOrchestrator.start(campaign, payload: trigger)
        case .nudge(let nudgeConfig):
            // Dashboard-declared defaults first, CEP trigger variables layered
            // on top (CEP wins) — mirrors Flutter's `digia_host._presentNudge`.
            var mergedVariables = nudgeConfig.defaultVariables
            for (key, value) in payload.content.variables ?? [:] {
                mergedVariables[key] = value
            }
            controller.showNudge(DigiaNudgePresentation(
                config: nudgeConfig,
                payload: trigger,
                variables: mergedVariables.isEmpty ? nil : mergedVariables
            ))
        case .survey(let cfg):
            // campaignId is read back in reportSurveyCompleted; carry it through
            // cepMetadata so submission attribution survives.
            let routed = CEPTriggerPayload(
                cepCampaignId: campaign.id,
                campaignKey: campaign.campaignKey,
                cepMetadata: payload.cepContext.merging([
                    "campaignId": campaign.id,
                    "campaignKey": campaign.campaignKey,
                ]) { _, new in new },
                variables: payload.content.variables
            )
            if !surveyOrchestrator.start(payload: routed, config: cfg) {
                logVerbose("survey campaign dropped: another survey is on screen: \(key)")
            }
        }
    }

    func onCampaignInvalidated(_ campaignID: String) {
        if controller.activePayload?.id == campaignID {
            controller.dismiss()
        }
        if controller.activeNudge?.payload.cepCampaignId == campaignID {
            controller.dismissNudge()
        }
        if surveyOrchestrator.state?.payload.cepCampaignId == campaignID {
            surveyOrchestrator.dismiss()
        }
        inlineController.removeCampaign(campaignID)
        guideOrchestrator.dismissIfActive(campaignKey: campaignID)
        // Forget the impression mark so a re-trigger impresses to Digia afresh.
        events.resetImpression(campaignID)
    }

    // MARK: - Survey lifecycle
    //
    // CEP plugin sees: Impressed (started), Dismissed (every teardown — closed
    // without finishing AND completed; all routed through markSurveyDismissed).
    // Internal analytics (TBD) sees: Answered, Completed.
    // Surveys are started from `routeByCampaignKey` once a `survey` campaign is
    // resolved from the store, so there is no separate `startSurvey` entry point.

    /// Fired once when the survey first becomes visible (treated as an impression).
    func reportSurveyStarted() {
        guard let state = surveyOrchestrator.state else { return }
        let config = state.config
        dwellTracker.markViewed(state.payload.cepCampaignId)
        events.toBoth(
            .impressed,
            SurveyEvent.Viewed(
                itemTotal: config.questionCount,
                hasWelcome: config.hasWelcome,
                hasThanks: config.hasThanks,
                hasBranching: config.hasBranching
            ),
            payload: state.payload
        )
    }

    /// The survey's start engagement — fired once per showing. When a welcome
    /// screen is present this is its "Start" CTA tap; when there's no welcome
    /// screen it is raised on the first continue (see `reportSurveyAnswered` /
    /// `reportSurveyQuestionSkipped`).
    func reportSurveyWelcomeStart() {
        guard let state = surveyOrchestrator.state else { return }
        if welcomeStartToken == state.token { return }
        welcomeStartToken = state.token
        events.toDigia(SurveyEvent.Clicked(elementId: "welcome_start"), payload: state.payload)
    }

    /// When no welcome screen exists, the first continue is the start engagement.
    private func ensureWelcomeStartIfNoWelcome(_ state: ActiveSurveyState) {
        if !state.config.hasWelcome { reportSurveyWelcomeStart() }
    }

    /// A survey question became visible. `itemIndex` is its 1-based shown position.
    func reportSurveyQuestionViewed(nodeId: String, itemIndex: Int) {
        guard let state = surveyOrchestrator.state else { return }
        guard let block = state.config.blockForNode(nodeId) else { return }
        if block.type.isContent { return }
        events.toDigia(
            SurveyEvent.QuestionViewed(
                questionId: nodeId,
                questionType: block.type.rawValue,
                itemIndex: itemIndex,
                itemTotal: state.config.questionCount,
                blockId: block.id,
                isRequired: block.required
            ),
            payload: state.payload
        )
    }

    /// An eligible optional question was skipped (advanced without an answer).
    func reportSurveyQuestionSkipped(nodeId: String, itemIndex: Int) {
        guard let state = surveyOrchestrator.state else { return }
        ensureWelcomeStartIfNoWelcome(state)
        guard let block = state.config.blockForNode(nodeId) else { return }
        events.toDigia(
            SurveyEvent.QuestionSkipped(questionId: nodeId, itemIndex: itemIndex, blockId: block.id),
            payload: state.payload
        )
    }

    /// Fired each time the user answers a question (one event per answered question).
    func reportSurveyAnswered(stepId: String, answer: [String: JSONValue]) {
        guard let state = surveyOrchestrator.state else { return }
        ensureWelcomeStartIfNoWelcome(state)
        let block = state.config.blockForNode(stepId)
        let values = Self.stringArray(answer["values"])
        let comment = Self.stringValue(answer["comment"])
        events.toDigia(
            SurveyEvent.QuestionAnswered(
                questionId: stepId,
                questionType: block?.type.rawValue,
                answerValue: values.first,
                answerText: comment ?? (values.isEmpty ? nil : values.joined(separator: ", ")),
                blockId: block?.id,
                answerOptions: values.count > 1 ? values : nil,
                answer: Self.foundation(answer)
            ),
            payload: state.payload
        )
    }

    func markSurveyCompleted(response: [String: JSONValue], answers: [String: SurveyAnswer] = [:]) {
        reportSurveyCompleted(response: response, answers: answers)
        markSurveyDismissed()
    }

    func reportSurveyCompleted(response: [String: JSONValue], answers: [String: SurveyAnswer] = [:])
    {
        guard let state = surveyOrchestrator.state else {
            logVerbose("reportSurveyCompleted: skip — no active survey state")
            return
        }
        if completedSurveyToken == state.token {
            logVerbose("reportSurveyCompleted: skip — already reported for token=\(state.token)")
            return
        }
        completedSurveyToken = state.token

        // Analytics "Completed" fires once per survey showing, regardless of
        // whether a submission is reported to the backend below.
        let answeredCount = answers.isEmpty ? response.count : answers.count
        events.toDigia(
            SurveyEvent.Completed(
                itemTotal: state.config.questionCount,
                answeredCount: answeredCount,
                timeToCompleteMs: Int64(Date().timeIntervalSince(state.startedAt) * 1000),
                response: Self.foundation(response)
            ),
            payload: state.payload
        )

        if answers.isEmpty {
            logVerbose("reportSurveyCompleted: skip submission — answers is empty")
            return
        }
        guard let config = self.config else {
            logVerbose("reportSurveyCompleted: skip submission — SDK not initialized (config is nil)")
            return
        }
        guard let campaignId = state.payload.cepMetadata["campaignId"] else {
            logVerbose("reportSurveyCompleted: skip submission — campaignId missing from cepMetadata")
            return
        }
        logVerbose("reportSurveyCompleted: submitting campaignId=\(campaignId) answers=\(answers.count)")
        SurveySubmissionReporter(config: config).report(
            campaignId: campaignId,
            survey: state.config,
            answers: answers,
            startedAt: state.startedAt
        )
    }

    func dismissCompletedSurvey() {
        markSurveyDismissed()
    }

    func markSurveyDismissed(abandonedAtItem: Int? = nil, answeredCount: Int? = nil) {
        guard let state = surveyOrchestrator.state else { return }
        events.toBoth(
            .dismissed,
            SurveyEvent.Dismissed(
                abandonedAtItem: abandonedAtItem,
                itemTotal: state.config.questionCount,
                answeredCount: answeredCount,
                dwellMs: dwellTracker.consumeDwellMs(state.payload.cepCampaignId)
            ),
            payload: state.payload
        )
        surveyOrchestrator.dismiss()
    }

    func markInitializedForTesting(with config: DigiaConfig) {
        self.config = config
    }

    func setCampaignsForTesting(_ campaigns: [CampaignModel]) {
        campaignStore.populate(campaigns)
        sdkState = .ready
    }

    func setUserId(_ userId: String) {
        analyticsService?.setUserId(userId)
    }

    func clearUserId() {
        analyticsService?.clearUserId()
    }

    // MARK: - Nudge lifecycle
    //
    // Impression and Dismissed go to both CEP and Digia analytics (toBoth); a
    // primary-button Click is a Digia-only engagement signal (toDigia), matching
    // Android's NudgeNodeRenderer.

    func reportNudgeImpression() {
        guard let nudge = controller.activeNudge else { return }
        dwellTracker.markViewed(nudge.payload.cepCampaignId)
        events.toBoth(
            .impressed,
            NudgeEvent.Viewed(displayStyle: nudge.config.surface.displayType.displayStyle),
            payload: nudge.payload
        )
    }

    func emitNudgeClick(
        elementId: String? = nil,
        ctaLabel: String? = nil,
        actionType: String? = nil,
        actionUrl: String? = nil,
        ctaRole: String? = nil
    ) {
        guard let payload = controller.activeNudge?.payload else { return }
        events.toDigia(
            NudgeEvent.Clicked(
                elementId: elementId,
                ctaLabel: ctaLabel,
                actionType: actionType,
                actionUrl: actionUrl,
                ctaRole: ctaRole,
                // ms since the nudge was viewed (peek — the nudge is still open).
                timeToActionMs: dwellTracker.elapsedMs(payload.cepCampaignId)
            ),
            payload: payload
        )
    }

    func markNudgeDismissed() {
        guard let nudge = controller.activeNudge else { return }
        events.toBoth(
            .dismissed,
            NudgeEvent.Dismissed(dwellMs: dwellTracker.consumeDwellMs(nudge.payload.cepCampaignId)),
            payload: nudge.payload
        )
        controller.dismissNudge()
    }

    // MARK: - Inline slot lifecycle
    //
    // CEP is Impressed + Dismissed instantly at route time (syncTemplate
    // semantics — see routeByCampaignKey). Digia's impression fires once, when
    // the slot first actually renders, deduped per campaign.

    func reportSlotFirstRender(_ payload: CEPTriggerPayload) {
        guard let campaign = campaignStore.find(payload.campaignKey) else { return }
        let viewed: EngageAnalyticsEvent
        switch campaign.config {
        case .inline(let cfg):
            viewed = CarouselEvent.Viewed(itemTotal: cfg.items.count, slotKey: cfg.slotKey)
        case .story(let cfg):
            viewed = StoriesEvent.Viewed(slotKey: cfg.slotKey)
        default:
            return
        }
        events.digiaImpressionOnce(payload: payload, event: viewed)
    }

    /// A carousel item scrolled into view. `auto` = autoplay advance vs manual swipe.
    func reportCarouselStepViewed(payload: CEPTriggerPayload, itemIndex: Int, itemTotal: Int, auto: Bool) {
        events.toDigia(
            CarouselEvent.StepViewed(itemIndex: itemIndex, itemTotal: itemTotal, auto: auto),
            payload: payload
        )
    }

    /// A carousel item (or its CTA) was tapped.
    func reportCarouselStepClicked(payload: CEPTriggerPayload, itemIndex: Int, actionUrl: String?) {
        let actionType = actionUrl.map { _ in "deeplink" }
        // The first item tap also counts as an experience-level engagement click (once).
        events.digiaExperienceClickedOnce(
            payload: payload,
            event: CarouselEvent.Clicked(actionType: actionType, actionUrl: actionUrl)
        )
        events.toDigia(
            CarouselEvent.StepClicked(itemIndex: itemIndex, actionType: actionType, actionUrl: actionUrl),
            payload: payload
        )
    }

    // MARK: - Guide lifecycle

    func dismissGuide() {
        guard let state = guideOrchestrator.state else { return }
        let payload = state.payload
        guideOrchestrator.dismiss()
        events.toBoth(
            .dismissed,
            GuideEvent.Dismissed(
                abandonedAtItem: state.stepIndex + 1,
                itemTotal: state.campaign.guideConfig?.steps.count,
                dwellMs: dwellTracker.consumeDwellMs(payload.cepCampaignId)
            ),
            payload: payload
        )
    }

    /// Public analytics entry point for JS-rendered RN campaigns (guides). The JS
    /// layer fires each lifecycle event by its Engage matrix `eventName` with
    /// wire-keyed `props`; this maps it to the typed analytics event and records
    /// it to Digia. CEP forwarding for JS-rendered campaigns is handled JS-side.
    func captureAnalyticsEvent(campaignKey: String, eventName: String, props: [String: Any]) {
        guard let event = guideEventFor(eventName: eventName, props: props) else {
            logVerbose("captureAnalyticsEvent: unsupported event '\(eventName)' for key '\(campaignKey)' — skipped")
            return
        }
        let campaign = campaignStore.find(campaignKey)
        let payload = CEPTriggerPayload(cepCampaignId: campaign?.id ?? campaignKey, campaignKey: campaignKey)
        events.toDigia(event, payload: payload)
    }

    private func guideEventFor(eventName: String, props: [String: Any]) -> EngageAnalyticsEvent? {
        func str(_ key: String) -> String? { props[key] as? String }
        func int(_ key: String) -> Int? { (props[key] as? NSNumber)?.intValue ?? (props[key] as? Int) }
        switch eventName {
        case "Digia Experience Viewed":
            return GuideEvent.Viewed(displayStyle: str("display_style") ?? "", itemTotal: int("step_total") ?? 0)
        case "Digia Step Viewed":
            return GuideEvent.StepViewed(
                itemIndex: int("step_index") ?? 0,
                itemTotal: int("step_total") ?? 0,
                anchorKey: str("anchor_key"),
                displayStyle: str("display_style")
            )
        // Guides only have Step Clicked in the matrix; map both click variants to it.
        case "Digia Step Clicked", "Digia Experience Clicked":
            return GuideEvent.StepClicked(
                itemIndex: int("step_index") ?? 0,
                elementId: str("element_id"),
                ctaLabel: str("cta_label"),
                actionType: str("action_type"),
                actionUrl: str("action_url")
            )
        case "Digia Step Dismissed":
            return GuideEvent.StepDismissed(itemIndex: int("step_index") ?? 0)
        case "Digia Experience Dismissed":
            return GuideEvent.Dismissed(abandonedAtItem: int("abandoned_at_step") ?? int("step_index"), itemTotal: int("step_total"))
        case "Digia Experience Completed":
            return GuideEvent.Completed(itemTotal: int("step_total"))
        default:
            return nil
        }
    }

    /// Converts a `JSONValue` map to a Foundation map for JSON serialization,
    /// dropping `null` entries.
    private static func foundation(_ map: [String: JSONValue]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in map {
            if let any = value.anyValue { result[key] = any }
        }
        return result
    }

    private static func stringArray(_ value: JSONValue?) -> [String] {
        guard case .array(let arr)? = value else { return [] }
        return arr.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
    }

    private static func stringValue(_ value: JSONValue?) -> String? {
        if case .string(let s)? = value { return s }
        return nil
    }

    func resetForTesting() {
        activePlugin?.teardown()
        activePlugin = nil
        analyticsService?.clear()
        analyticsService = nil
        config = nil
        sdkState = .notInitialized
        isHostMounted = false
        fontFactory = DefaultFontFactory()
        campaignStore.clear()
        controller.dismiss()
        controller.dismissNudge()
        controller.dismissStoryOverlay()
        inlineController.clear()
        surveyOrchestrator.dismiss()
        guideOrchestrator.dismiss()
        events.clearImpressions()
        dwellTracker.clear()
        completedSurveyToken = nil
        welcomeStartToken = nil
    }

}

// MARK: - Survey config metrics (Engage matrix props)

private extension SurveyConfigModel {
    /// Configured questions = graph nodes whose block is an actual prompt (not
    /// content chrome like welcome / text-media / result pages).
    var questionCount: Int {
        nodes.filter { node in
            guard let block = blockFor(node) else { return false }
            return !block.type.isContent
        }.count
    }

    var hasWelcome: Bool { welcomeBlock() != nil }

    var hasThanks: Bool { blocks.contains { $0.type == .resultPage } }

    var hasBranching: Bool { nodes.contains { $0.branching.type != .linear } }

    func blockForNode(_ nodeId: String) -> SurveyBlock? {
        nodeById(nodeId).flatMap { blockFor($0) }
    }
}
