import Foundation
@testable import DigiaEngage
import Testing

@MainActor
@Suite("Overlay Action Processors", .serialized)
struct OverlayActionProcessorTests {
    @Test("showToast uses default duration when absent")
    func showToastDefaultsDuration() async throws {
        SDKInstance.shared.resetForTesting()

        try await ShowToastProcessor().execute(
            action: ShowToastAction(
                disableActionIf: nil,
                data: ["message": .string("Saved")]
            ),
            context: context()
        )

        #expect(SDKInstance.shared.controller.activeToast?.message == "Saved")
        #expect(SDKInstance.shared.controller.activeToast?.durationSeconds == 2)
    }

    @Test("showBottomSheet maps componentId fallback")
    func showBottomSheetUsesComponentIdFallback() async throws {
        SDKInstance.shared.resetForTesting()

        try await ShowBottomSheetProcessor().execute(
            action: ShowBottomSheetAction(
                disableActionIf: nil,
                data: [
                    "componentId": .string("checkout_sheet"),
                    "title": .string("Checkout"),
                ]
            ),
            context: context()
        )

        #expect(SDKInstance.shared.controller.activeBottomSheet?.view.viewID == "checkout_sheet")
        #expect(SDKInstance.shared.controller.activeBottomSheet?.view.title == "Checkout")
    }

    @Test("showBottomSheet forwards args into the presentation")
    func showBottomSheetForwardsArgs() async throws {
        SDKInstance.shared.resetForTesting()

        try await ShowBottomSheetProcessor().execute(
            action: ShowBottomSheetAction(
                disableActionIf: nil,
                data: [
                    "componentId": .string("checkout_sheet"),
                    "args": .object(["name": .string("Ada")]),
                ]
            ),
            context: context()
        )

        #expect(SDKInstance.shared.controller.activeBottomSheet?.view.args == ["name": .string("Ada")])
    }

    @Test("showBottomSheet accepts integer borderWidth")
    func showBottomSheetAcceptsIntegerBorderWidth() async throws {
        SDKInstance.shared.resetForTesting()

        try await ShowBottomSheetProcessor().execute(
            action: ShowBottomSheetAction(
                disableActionIf: nil,
                data: [
                    "componentId": .string("checkout_sheet"),
                    "style": .object([
                        "borderWidth": .int(10),
                    ]),
                ]
            ),
            context: context()
        )

        #expect(SDKInstance.shared.controller.activeBottomSheet?.borderWidth == CGFloat(10))
    }

    @Test("showDialog forwards args into the presentation")
    func showDialogForwardsArgs() async throws {
        SDKInstance.shared.resetForTesting()

        try await ShowDialogProcessor().execute(
            action: ShowDialogAction(
                disableActionIf: nil,
                data: [
                    "componentId": .string("checkout_dialog"),
                    "args": .object(["step": .int(2)]),
                ]
            ),
            context: context()
        )

        #expect(SDKInstance.shared.controller.activeDialog?.view.args == ["step": .int(2)])
    }

    private func context() -> ActionProcessorContext {
        ActionProcessorContext(appConfig: AppConfigStore())
    }
}
