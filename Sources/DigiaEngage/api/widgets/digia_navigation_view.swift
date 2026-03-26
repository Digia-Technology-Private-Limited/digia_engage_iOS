import SwiftUI

/// Full-screen Digia navigation container. Renders the SDUI initial route as the
/// NavigationStack root and drives all push/pop transitions natively — no overlay
/// or custom slide animation needed, so forward and back feel identical.
///
/// Obtain via ``DUIFactory/createInitialPage()``.
@MainActor
struct DigiaNavigationView: View {
    @ObservedObject private var store = SDKInstance.shared.appConfigStore
    @ObservedObject private var navigation = SDKInstance.shared.navigationController

    var body: some View {
        if let initialRoute = store.appConfig?.initialRoute {
            let rootID = navigation.rootRoute?.isEmpty == false ? navigation.rootRoute! : initialRoute
            NavigationStack(
                path: Binding(
                    get: { navigation.path },
                    set: { navigation.updatePath($0) }
                )
            ) {
                DUIFactory.shared.createPage(rootID, pageArgs: navigation.rootArgs)
                    .navigationDestination(for: NavigationEntry.self) { entry in
                        DUIFactory.shared.createPage(
                            entry.pageID,
                            pageArgs: navigation.args(for: entry.id)
                        )
                    }
            }
            .ignoresSafeArea()
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
