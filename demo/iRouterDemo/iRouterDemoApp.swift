import SwiftUI
import iRouter

@main
struct iRouterDemoApp: App {

    @State private var router = IRouter<AppRoute>(
        root: .home,
        filters: [
            IRouterFilter { route, _ in
                if case .settings = route, !AuthState.shared.isLoggedIn {
                    return .redirect(.login, .sheet)
                }
                return .allow
            }
        ]
    )

    var body: some Scene {
        WindowGroup {
            ContentView(router: router)
        }
    }
}
