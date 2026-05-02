import SwiftUI

@MainActor
final class DigiaOverlayController: ObservableObject {
    @Published private(set) var activePayload: InAppPayload?
    @Published private(set) var activeBottomSheet: DigiaBottomSheetPresentation?
    @Published private(set) var activeDialog: DigiaDialogPresentation?
    @Published private(set) var activeToast: DigiaToastPresentation?
    @Published private(set) var activePip: PipRequest?
    @Published private(set) var activeTooltip: TooltipRequest?
    @Published private(set) var slotPayloads: [String: InAppPayload] = [:]

    private var toastToken = UUID()
    var onEvent: ((DigiaExperienceEvent, InAppPayload) -> Void)?
    var onDialogDismissed: ((JSONValue?) -> Void)?
    var onBottomSheetDismissed: ((JSONValue?) -> Void)?
    var bottomSheetTransition: BottomSheetTransitionModel?
    private(set) var bottomSheetRendersInHost = false

    func show(_ payload: InAppPayload) {
        activePayload = payload
    }

    func dismiss() {
        activePayload = nil
    }

    func showBottomSheet(_ presentation: DigiaBottomSheetPresentation, rendersInHost: Bool = false) {
        activeBottomSheet = presentation
        bottomSheetRendersInHost = rendersInHost
    }

    func dismissBottomSheet(result: JSONValue? = nil) {
        bottomSheetTransition = nil
        bottomSheetRendersInHost = false
        activeBottomSheet = nil
        onBottomSheetDismissed?(result)
        onBottomSheetDismissed = nil
    }

    func showDialog(_ presentation: DigiaDialogPresentation) {
        activeDialog = presentation
    }

    func dismissDialog(result: JSONValue? = nil) {
        activeDialog = nil
        onDialogDismissed?(result)
        onDialogDismissed = nil
    }

    func showToast(_ presentation: DigiaToastPresentation) {
        activeToast = presentation
        let token = UUID()
        toastToken = token
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(max(presentation.durationSeconds, 0) * 1_000_000_000))
            if self.toastToken == token {
                self.dismissToast()
            }
        }
    }

    func dismissToast() {
        activeToast = nil
    }

    func showPip(_ request: PipRequest) {
        activePip = request
    }

    func dismissPip() {
        activePip = nil
    }

    func showTooltip(_ request: TooltipRequest) {
        activeTooltip = request
    }

    func dismissTooltip(result: Any? = nil) {
        let req = activeTooltip
        activeTooltip = nil
        req?.onDismiss?(result)
    }

    /// Call when the active screen changes (e.g. from a NavigationStack onChange or UIViewController viewDidAppear).
    /// Dismisses PiP if `closeOnScreenChange` is true or the new screen is blocked by `screenFilter`.
    func onScreenChanged(_ screenName: String) {
        guard let pip = activePip else { return }
        let shouldDismiss = pip.closeOnScreenChange ||
            pip.screenFilter.map { !$0.isAllowed(screenName) } ?? false
        if shouldDismiss { dismissPip() }
    }

    func addSlot(_ placementKey: String, payload: InAppPayload) {
        slotPayloads[placementKey] = payload
    }

    func slotPayload(for placementKey: String) -> InAppPayload? {
        slotPayloads[placementKey]
    }

    func removeSlotByID(_ campaignID: String) {
        slotPayloads = slotPayloads.filter { _, payload in payload.id != campaignID }
    }

    func clearSlots() {
        slotPayloads.removeAll()
    }
}
