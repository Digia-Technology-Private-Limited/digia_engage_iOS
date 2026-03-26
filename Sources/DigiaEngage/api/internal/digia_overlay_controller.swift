import Foundation
import Combine
import SwiftUI

struct DigiaViewPresentation: Equatable, Sendable {
    let viewID: String
    let title: String?
    let text: String?
    let args: [String: JSONValue]
}

struct DigiaToastPresentation: Equatable, Sendable {
    let message: String
    let durationSeconds: Double
}

struct DigiaBottomSheetPresentation: Equatable, Sendable {
    let view: DigiaViewPresentation
    let barrierColor: Color
    let maxHeight: Double
    let borderColor: Color?
    let borderWidth: CGFloat?
    
    init(
        view: DigiaViewPresentation,
        barrierColor: Color = Color.black.opacity(0.54),
        maxHeight: Double = 1.0,
        borderColor: Color? = nil,
        borderWidth: CGFloat? = nil
    ) {
        self.view = view
        self.barrierColor = barrierColor
        self.maxHeight = maxHeight
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }
}

struct DigiaDialogPresentation: Equatable, Sendable {
    let view: DigiaViewPresentation
    let barrierDismissible: Bool
    let barrierColor: Color
    
    init(
        view: DigiaViewPresentation,
        barrierDismissible: Bool = true,
        barrierColor: Color = Color.black.opacity(0.54)
    ) {
        self.view = view
        self.barrierDismissible = barrierDismissible
        self.barrierColor = barrierColor
    }
}

@MainActor
final class DigiaOverlayController: ObservableObject {
    @Published private(set) var activePayload: InAppPayload?
    @Published private(set) var activeBottomSheet: DigiaBottomSheetPresentation?
    @Published private(set) var activeDialog: DigiaDialogPresentation?
    @Published private(set) var activeToast: DigiaToastPresentation?
    @Published private(set) var slotPayloads: [String: InAppPayload] = [:]

    private var toastToken = UUID()
    var onEvent: ((DigiaExperienceEvent, InAppPayload) -> Void)?

    /// Callback invoked when the active dialog is dismissed, carrying an optional result value.
    var onDialogDismissed: ((JSONValue?) -> Void)?
    /// Callback invoked when the active bottom sheet is dismissed, carrying an optional result value.
    var onBottomSheetDismissed: ((JSONValue?) -> Void)?

    func show(_ payload: InAppPayload) {
        activePayload = payload
    }

    func dismiss() {
        activePayload = nil
    }

    func showBottomSheet(_ presentation: DigiaBottomSheetPresentation) {
        activeBottomSheet = presentation
    }

    func dismissBottomSheet(result: JSONValue? = nil) {
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
