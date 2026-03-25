import SwiftUI

@MainActor
public struct DigiaInitialRouteScreen: View {
    @ObservedObject private var store = SDKInstance.shared.appConfigStore
    @ObservedObject private var navigation = SDKInstance.shared.navigationController

    public init() {}

    public var body: some View {
        Group {
            if let initialRoute = store.appConfig?.initialRoute {
                let rootID = navigation.rootRoute?.isEmpty == false ? navigation.rootRoute! : initialRoute
                NavigationStack(path: Binding(get: { navigation.path }, set: { navigation.updatePath($0) })) {
                    DUIFactory.shared.createPage(rootID, pageArgs: navigation.rootArgs)
                        .navigationDestination(for: NavigationEntry.self) { entry in
                            DUIFactory.shared.createPage(
                                entry.pageID,
                                pageArgs: navigation.args(for: entry.id)
                            )
                        }
                }
                .digiaHideHostNavigationBar()
                .onAppear {
                    SDKInstance.shared.navigationController.setInitialRoute(initialRoute)
                }
            } else if let error = store.lastError {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Digia load failed")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ProgressView("Loading Digia App")
                    Text(store.isLoading ? "Waiting for remote AppConfig..." : "No AppConfig loaded yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func digiaHideHostNavigationBar() -> some View {
        self
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .digiaKeepSwipeBackGestureEnabled()
    }
}
