import SwiftUI

// Native bottom-sheet / dialog nudge renderer, ported from Android's `NudgeRenderer.kt`.
// Renders the campaign's native DUI widget tree (`config.layout`) through the recursive
// SDUI renderer, wrapped in a hand-rolled sheet or dialog. The impression event is fired
// by `DigiaOverlayController.showNudge`; dismiss button actions (Action.hideBottomSheet /
// Action.dismissDialog) are intercepted by their processors and routed to `dismissNudge`.
@MainActor
struct NudgeOverlayView: View {
    @ObservedObject private var controller = SDKInstance.shared.controller

    var body: some View {
        if let nudge = controller.activeNudge {
            NudgeContainerView(presentation: nudge)
                .id(nudge.payload.id)
        }
    }
}

@MainActor
private struct NudgeContainerView: View {
    let presentation: DigiaNudgePresentation
    @State private var dragOffset: CGFloat = 0

    private var container: NudgeContainerConfig { presentation.config.container }
    private var scrimColor: Color { Color(hex: container.scrimColor) ?? Color.black.opacity(0.4) }
    private var backgroundColor: Color { Color(hex: container.bgColor) ?? .white }

    private func dismiss() { SDKInstance.shared.controller.dismissNudge() }

    var body: some View {
        ZStack(alignment: presentation.config.templateType == .bottomSheet ? .bottom : .center) {
            scrimColor
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { if container.dismissOnOutsideTap { dismiss() } }

            switch presentation.config.templateType {
            case .bottomSheet: sheetPanel
            case .dialog: dialogPanel
            }
        }
    }

    // MARK: - Panels

    private var sheetPanel: some View {
        VStack(spacing: 0) {
            if container.dragHandle {
                // Drag-to-dismiss lives on the handle so it never competes with the
                // content ScrollView's own vertical scrolling.
                Capsule()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .gesture(dragGesture)
            }
            ScrollView {
                renderedTree.padding(container.padding)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: UIScreen.main.bounds.height * container.maxHeightRatio)
        .background(backgroundColor)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: container.cornerRadius,
                topTrailingRadius: container.cornerRadius
            )
        )
        .offset(y: max(dragOffset, 0))
        .transition(.move(edge: .bottom))
    }

    private var dialogPanel: some View {
        ScrollView {
            renderedTree.padding(container.padding)
        }
        .frame(width: container.width ?? (UIScreen.main.bounds.width * 0.85))
        .frame(maxHeight: UIScreen.main.bounds.height * 0.85)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: container.cornerRadius))
        .transition(.opacity)
    }

    // MARK: - Drag-to-dismiss (bottom sheet)

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in dragOffset = value.translation.height }
            .onEnded { value in
                if value.translation.height > 120 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.3)) { dragOffset = 0 }
                }
            }
    }

    // MARK: - SDUI tree

    private var renderedTree: AnyView {
        guard let widget = try? DefaultVirtualWidgetRegistry()
            .createWidget(presentation.config.layout, parent: nil)
        else { return AnyView(EmptyView()) }
        let resources = ResourceProvider(
            fontFactory: SDKInstance.shared.fontFactory,
            appConfigStore: SDKInstance.shared.appConfigStore
        )
        return widget.toWidget(RenderPayload(resources: resources))
    }
}
