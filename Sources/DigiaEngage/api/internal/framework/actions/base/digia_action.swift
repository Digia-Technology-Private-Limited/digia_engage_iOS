import Foundation

enum ActionType: String, CaseIterable, Codable, Sendable {
    case callRestApi = "Action.callRestApi"
    case copyToClipBoard = "Action.copyToClipBoard"
    case delay = "Action.delay"
    case navigateBack = "Action.pop"
    case navigateBackUntil = "Action.popUntil"
    case navigateToPage = "Action.navigateToPage"
    case openUrl = "Action.openUrl"
    case postMessage = "Action.handleDigiaMessage"
    case rebuildState = "Action.rebuildState"
    case setState = "Action.setState"
    case shareContent = "Action.share"
    case showBottomSheet = "Action.showBottomSheet"
    case showDialog = "Action.openDialog"
    case showToast = "Action.showToast"
    case fireEvent = "Action.fireEvent"
    case setAppState = "Action.setAppState"
    case hideBottomSheet = "Action.hideBottomSheet"
    case dismissDialog = "Action.dismissDialog"
    case showPip = "Action.showPip"
    case dismissPip = "Action.dismissPip"
}

enum DigiaActionModel: Sendable {
    case callRestApi(CallRestApiAction)
    case copyToClipBoard(CopyToClipBoardAction)
    case delay(DelayAction)
    case navigateBack(NavigateBackAction)
    case navigateBackUntil(NavigateBackUntilAction)
    case navigateToPage(NavigateToPageAction)
    case openUrl(OpenUrlAction)
    case postMessage(PostMessageAction)
    case rebuildState(RebuildStateAction)
    case setState(SetStateAction)
    case shareContent(ShareContentAction)
    case showBottomSheet(ShowBottomSheetAction)
    case showDialog(ShowDialogAction)
    case showToast(ShowToastAction)
    case fireEvent(FireEventAction)
    case setAppState(SetAppStateAction)
    case hideBottomSheet(HideBottomSheetAction)
    case dismissDialog(DismissDialogAction)
    case showPip(ShowPipAction)
    case dismissPip(DismissPipAction)
}

extension DigiaActionModel {
    var actionType: ActionType {
        switch self {
        case .callRestApi: return .callRestApi
        case .copyToClipBoard: return .copyToClipBoard
        case .delay: return .delay
        case .navigateBack: return .navigateBack
        case .navigateBackUntil: return .navigateBackUntil
        case .navigateToPage: return .navigateToPage
        case .openUrl: return .openUrl
        case .postMessage: return .postMessage
        case .rebuildState: return .rebuildState
        case .setState: return .setState
        case .shareContent: return .shareContent
        case .showBottomSheet: return .showBottomSheet
        case .showDialog: return .showDialog
        case .showToast: return .showToast
        case .fireEvent: return .fireEvent
        case .setAppState: return .setAppState
        case .hideBottomSheet: return .hideBottomSheet
        case .dismissDialog: return .dismissDialog
        case .showPip: return .showPip
        case .dismissPip: return .dismissPip
        }
    }

    var disableActionIf: ExprOr<Bool>? {
        switch self {
        case let .callRestApi(action): return action.disableActionIf
        case let .copyToClipBoard(action): return action.disableActionIf
        case let .delay(action): return action.disableActionIf
        case let .navigateBack(action): return action.disableActionIf
        case let .navigateBackUntil(action): return action.disableActionIf
        case let .navigateToPage(action): return action.disableActionIf
        case let .openUrl(action): return action.disableActionIf
        case let .postMessage(action): return action.disableActionIf
        case let .rebuildState(action): return action.disableActionIf
        case let .setState(action): return action.disableActionIf
        case let .shareContent(action): return action.disableActionIf
        case let .showBottomSheet(action): return action.disableActionIf
        case let .showDialog(action): return action.disableActionIf
        case let .showToast(action): return action.disableActionIf
        case let .fireEvent(action): return action.disableActionIf
        case let .setAppState(action): return action.disableActionIf
        case let .hideBottomSheet(action): return action.disableActionIf
        case let .dismissDialog(action): return action.disableActionIf
        case let .showPip(action): return action.disableActionIf
        case let .dismissPip(action): return action.disableActionIf
        }
    }
}
