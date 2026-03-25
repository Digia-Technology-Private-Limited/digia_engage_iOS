import Foundation

enum ActionFactoryError: Error {
    case unsupportedType(String)
}

enum ActionFactory {
    static func makeAction(from step: ActionStep) throws -> DigiaActionModel {
        guard let decoded = ActionType(rawValue: step.type) else {
            throw ActionFactoryError.unsupportedType(step.type)
        }
        let data = step.data ?? [:]

        switch decoded {
        case .callRestApi:
            return .callRestApi(CallRestApiAction(disableActionIf: step.disableActionIf, data: data))
        case .copyToClipBoard:
            return .copyToClipBoard(CopyToClipBoardAction(disableActionIf: step.disableActionIf, data: data))
        case .delay:
            return .delay(DelayAction(disableActionIf: step.disableActionIf, data: data))
        case .navigateBack:
            return .navigateBack(NavigateBackAction(disableActionIf: step.disableActionIf, data: data))
        case .navigateBackUntil:
            return .navigateBackUntil(NavigateBackUntilAction(disableActionIf: step.disableActionIf, data: data))
        case .navigateToPage:
            let openAs = data["openAs"]?.stringValue ?? data["pageType"]?.stringValue
            if openAs?.lowercased() == "bottomsheet" {
                return .showBottomSheet(ShowBottomSheetAction(disableActionIf: step.disableActionIf, data: data))
            }
            return .navigateToPage(NavigateToPageAction(disableActionIf: step.disableActionIf, data: data))
        case .openUrl:
            return .openUrl(OpenUrlAction(disableActionIf: step.disableActionIf, data: data))
        case .postMessage:
            return .postMessage(PostMessageAction(disableActionIf: step.disableActionIf, data: data))
        case .rebuildState:
            return .rebuildState(RebuildStateAction(disableActionIf: step.disableActionIf, data: data))
        case .setState:
            return .setState(SetStateAction(disableActionIf: step.disableActionIf, data: data))
        case .shareContent:
            return .shareContent(ShareContentAction(disableActionIf: step.disableActionIf, data: data))
        case .showBottomSheet:
            return .showBottomSheet(ShowBottomSheetAction(disableActionIf: step.disableActionIf, data: data))
        case .showDialog:
            return .showDialog(ShowDialogAction(disableActionIf: step.disableActionIf, data: data))
        case .showToast:
            return .showToast(ShowToastAction(disableActionIf: step.disableActionIf, data: data))
        case .fireEvent:
            return .fireEvent(FireEventAction(disableActionIf: step.disableActionIf, data: data))
        case .setAppState:
            return .setAppState(SetAppStateAction(disableActionIf: step.disableActionIf, data: data))
        case .hideBottomSheet:
            return .hideBottomSheet(HideBottomSheetAction(disableActionIf: step.disableActionIf, data: data))
        case .dismissDialog:
            return .dismissDialog(DismissDialogAction(disableActionIf: step.disableActionIf, data: data))
        }
    }
}
