import SwiftUI

/// Wraps the application root and renders in-app message overlays
/// (dialogs, bottom sheets, toasts) above all app content via the SDUI engine.
///
/// Place this widget once, at the root of your application:
/// ```swift
/// DigiaHost {
///     DUIFactory.shared.createInitialPage()
/// }
/// ```
@MainActor
public struct DigiaHost<Content: View>: View {
    private let content: Content
    @ObservedObject private var controller = SDKInstance.shared.controller

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ZStack {
            content
                .onAppear { SDKInstance.shared.onHostMounted() }
                .onDisappear { SDKInstance.shared.onHostUnmounted() }

            // Toast overlay (rendered natively above all navigation)
            VStack {
                Spacer()
                if let toast = controller.activeToast {
                    Text(toast.message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: controller.activeToast != nil)
        }
        .onChange(of: controller.activePayload) { payload in
            handlePayload(payload)
        }
    }

    private func handlePayload(_ payload: InAppPayload?) {
        guard let payload else { return }

        let command = (payload.content.command ?? payload.content.type)
            .trimmingCharacters(in: .whitespaces)
            .uppercased()

        let viewId = payload.content.viewId

        guard let viewId, !viewId.isEmpty else {
            controller.onEvent?(.dismissed, payload)
            controller.dismiss()
            return
        }

        controller.onEvent?(.impressed, payload)

        let appConfig = SDKInstance.shared.appConfigStore
        let executor = ActionExecutor()

        if command == "SHOW_BOTTOM_SHEET" || command == "BOTTOMSHEET" {
            var actionData: [String: JSONValue] = ["componentId": .string(viewId)]
            if !payload.content.args.isEmpty {
                actionData["args"] = .object(payload.content.args)
            }
            let action = ShowBottomSheetAction(disableActionIf: nil, data: actionData)
            let context = ActionProcessorContext(appConfig: appConfig, actionExecutor: executor)
            Task { @MainActor in
                try? await ShowBottomSheetProcessor().execute(action: action, context: context)
                controller.onEvent?(.dismissed, payload)
                controller.dismiss()
            }
        } else {
            var actionData: [String: JSONValue] = [
                "componentId": .string(viewId),
                "barrierDismissible": .bool(true)
            ]
            if !payload.content.args.isEmpty {
                actionData["args"] = .object(payload.content.args)
            }
            let action = ShowDialogAction(disableActionIf: nil, data: actionData)
            let context = ActionProcessorContext(appConfig: appConfig, actionExecutor: executor)
            Task { @MainActor in
                try? await ShowDialogProcessor().execute(action: action, context: context)
                controller.onEvent?(.dismissed, payload)
                controller.dismiss()
            }
        }
    }

}
