import Foundation
@testable import DigiaEngage
import Testing

@MainActor
@Suite("Basic Action Processors", .serialized)
struct BasicActionProcessorTests {
    @Test("delay processor sleeps for at least the requested duration")
    func delayExecutes() async throws {
        let requestedMs = 50
        let action = DelayAction(disableActionIf: nil, data: ["durationInMs": .int(requestedMs)])
        let processor = DelayProcessor()
        let clock = ContinuousClock()
        let start = clock.now
        try await processor.execute(action: action, context: context())
        let elapsed = start.duration(to: clock.now)
        #expect(elapsed >= .milliseconds(requestedMs))
    }

    @Test("openUrl processor stores resolved URL")
    func openUrlStoresResolvedURL() async throws {
        SDKInstance.shared.resetForTesting()
        let action = OpenUrlAction(disableActionIf: nil, data: ["url": .string("https://app.digia.tech/")])
        let processor = OpenUrlProcessor()
        try await processor.execute(action: action, context: context())
        #expect(SDKInstance.shared.lastOpenedURL?.absoluteString == "https://app.digia.tech/")
    }

    @Test("copyToClipBoard processor stores copied message")
    func copyToClipboardStoresMessage() async throws {
        SDKInstance.shared.resetForTesting()
        let action = CopyToClipBoardAction(disableActionIf: nil, data: ["message": .string("TEST COPIED")])
        let processor = CopyToClipBoardProcessor()
        try await processor.execute(action: action, context: context())
        #expect(SDKInstance.shared.clipboardString == "TEST COPIED")
    }

    @Test("showToast processor publishes toast presentation")
    func showToastPublishesPresentation() async throws {
        SDKInstance.shared.resetForTesting()
        let action = ShowToastAction(disableActionIf: nil, data: ["message": .string("hello")])
        let processor = ShowToastProcessor()
        try await processor.execute(action: action, context: context())
        #expect(SDKInstance.shared.controller.activeToast?.message == "hello")
    }

    private func context() -> ActionProcessorContext {
        ActionProcessorContext(appConfig: AppConfigStore())
    }
}
