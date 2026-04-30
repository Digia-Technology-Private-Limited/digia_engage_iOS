import Foundation

@MainActor
final class ActionExecutor {
    func execute(
        _ actionFlow: ActionFlow?,
        appConfig: AppConfigStore,
        scopeContext: ExprContext,
        triggerType: String?,
        localStateStore: StateContext?
    ) {
        guard let actionFlow, !actionFlow.isEmpty else { return }
        Task { @MainActor in
            await executeNow(
                actionFlow,
                appConfig: appConfig,
                scopeContext: scopeContext,
                triggerType: triggerType,
                localStateStore: localStateStore
            )
        }
    }

    func executeNow(
        _ actionFlow: ActionFlow?,
        appConfig: AppConfigStore,
        scopeContext: ExprContext,
        triggerType: String?,
        localStateStore: StateContext?
    ) async {
        guard let actionFlow, !actionFlow.isEmpty else { return }
        for step in actionFlow.steps {
            do {
                let action = try ActionFactory.makeAction(from: step)
                if action.disableActionIf?.evaluate(in: scopeContext) == true {
                    continue
                }
                let context = ActionProcessorContext(
                    appConfig: appConfig,
                    scopeContext: scopeContext,
                    localStateStore: localStateStore,
                    actionExecutor: self
                )
                try await execute(action: action, context: context)
            } catch {
                NSLog("[DigiaEngage][ActionExecutor] stepFailed type=%@ error=%@", step.type, String(describing: error))
            }
        }
    }

    private func execute(action: DigiaActionModel, context: ActionProcessorContext) async throws {
        switch action {
        case let .callRestApi(model):
            try await CallRestApiProcessor().execute(action: model, context: context)
        case let .copyToClipBoard(model):
            try await CopyToClipBoardProcessor().execute(action: model, context: context)
        case let .delay(model):
            try await DelayProcessor().execute(action: model, context: context)
        case let .navigateBack(model):
            try await NavigateBackProcessor().execute(action: model, context: context)
        case let .navigateBackUntil(model):
            try await NavigateBackUntilProcessor().execute(action: model, context: context)
        case let .navigateToPage(model):
            try await NavigateToPageProcessor().execute(action: model, context: context)
        case let .openUrl(model):
            try await OpenUrlProcessor().execute(action: model, context: context)
        case let .postMessage(model):
            try await PostMessageProcessor().execute(action: model, context: context)
        case let .rebuildState(model):
            try await RebuildStateProcessor().execute(action: model, context: context)
        case let .setState(model):
            try await SetStateProcessor().execute(action: model, context: context)
        case let .shareContent(model):
            try await ShareContentProcessor().execute(action: model, context: context)
        case let .showBottomSheet(model):
            try await ShowBottomSheetProcessor().execute(action: model, context: context)
        case let .showDialog(model):
            try await ShowDialogProcessor().execute(action: model, context: context)
        case let .showToast(model):
            try await ShowToastProcessor().execute(action: model, context: context)
        case let .fireEvent(model):
            try await FireEventProcessor().execute(action: model, context: context)
        case let .setAppState(model):
            try await SetAppStateProcessor().execute(action: model, context: context)
        case let .hideBottomSheet(model):
            try await HideBottomSheetProcessor().execute(action: model, context: context)
        case let .dismissDialog(model):
            try await DismissDialogProcessor().execute(action: model, context: context)
        case let .showPip(model):
            try await ShowPipProcessor().execute(action: model, context: context)
        case let .dismissPip(model):
            try await DismissPipProcessor().execute(action: model, context: context)
        }
    }
}
