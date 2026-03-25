import SwiftUI

/// Wraps the application root and renders in-app message overlays
/// (dialogs, bottom sheets, toasts) above all app content via the SDUI engine.
///
/// Place this widget once, at the root of your application:
/// ```swift
/// DigiaHost {
///     ContentView()
/// }
/// ```
@MainActor
public struct DigiaHost<Content: View>: View {
    private let content: Content
    @ObservedObject private var controller = SDKInstance.shared.controller
    @ObservedObject private var navigation = SDKInstance.shared.navigationController

    /// Separate from navigation.path.isEmpty so we can animate the overlay
    /// in/out independently — the path is already updated before this fires,
    /// so the NavigationStack's content is fully set when the slide begins.
    @State private var isNavigationVisible = false

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ZStack {
            content
                .onAppear { SDKInstance.shared.onHostMounted() }
                .onDisappear { SDKInstance.shared.onHostUnmounted() }

            if isNavigationVisible {
                NavigationStack(
                    path: Binding(
                        get: { Array(navigation.path.dropFirst()) },
                        set: { newTail in
                            guard let first = navigation.path.first else { return }
                            navigation.updatePath([first] + newTail)
                        }
                    )
                ) {
                    if let first = navigation.path.first {
                        DUIFactory.shared.createPage(
                            first.pageID,
                            pageArgs: navigation.args(for: first.id)
                        )
                        .navigationDestination(for: NavigationEntry.self) { entry in
                            DUIFactory.shared.createPage(
                                entry.pageID,
                                pageArgs: navigation.args(for: entry.id)
                            )
                        }
                    }
                }
                .transition(.move(edge: .trailing))
                .ignoresSafeArea()
            }

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
        // Drive the overlay slide from the view using withAnimation so the
        // explicit animation context is set in the same render pass that
        // evaluates the if/transition.  By the time onChange fires, navigation.path
        // already contains the new entries, so the NavigationStack's root content
        // is fully populated when the slide begins — no double-animation.
        .onChange(of: navigation.path.isEmpty) { isEmpty in
            withAnimation(.easeInOut(duration: isEmpty ? 0.25 : 0.3)) {
                isNavigationVisible = !isEmpty
            }
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
