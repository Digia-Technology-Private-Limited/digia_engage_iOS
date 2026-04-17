import SwiftUI
@MainActor
struct DigiaNavigationView: View {
    @ObservedObject private var store = SDKInstance.shared.appConfigStore
    @ObservedObject private var navigation = SDKInstance.shared.navigationController

    var body: some View {
        ZStack {
            if let initialRoute = store.appConfig?.initialRoute {
                navigationStack(initialRoute: initialRoute)
            } else if let error = store.lastError {
                DigiaNavigationStatusView(
                    title: "Digia load failed",
                    message: error,
                    messageColor: .red
                )
            } else {
                DigiaNavigationLoadingView(isLoading: store.isLoading)
            }
        }
    }

    private func navigationStack(initialRoute: String) -> some View {
        let rootID = navigation.rootRoute.flatMap { $0.isEmpty ? nil : $0 } ?? initialRoute

        return NavigationStack(
            path: Binding(
                get: { navigation.path },
                set: { navigation.updatePath($0) }
            )
        ) {
            DUIFactory.shared.createPage(rootID, pageArgs: navigation.rootArgs)
                .digiaSmartSwipeBackControl()
                .navigationDestination(for: NavigationEntry.self) { entry in
                    DUIFactory.shared.createPage(
                        entry.pageID,
                        pageArgs: navigation.args(for: entry.id)
                    )
                }
        }
        .onChange(of: navigation.path) { oldPath, newPath in
            navigation.syncForPathChange(oldPath: oldPath, newPath: newPath)
        }
        .ignoresSafeArea()
        .onAppear { SDKInstance.shared.onNavigationMounted() }
        .onDisappear { SDKInstance.shared.onNavigationUnmounted() }
        .task(id: initialRoute) {
            SDKInstance.shared.navigationController.setInitialRoute(initialRoute)
        }
    }
}

private struct DigiaNavigationStatusView: View {
    let title: String
    let message: String
    let messageColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(messageColor)
        }
    }
}

private struct DigiaNavigationLoadingView: View {
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView("Loading Digia App")
            Text(isLoading ? "Waiting for remote AppConfig..." : "No AppConfig loaded yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
