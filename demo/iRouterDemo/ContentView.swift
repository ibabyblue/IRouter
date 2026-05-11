import SwiftUI
import iRouter

enum AppRoute: Hashable, Sendable {
    case home
    case detail(id: String)
    case settings
    case login
    case feed
}

final class AuthState {
    static let shared = AuthState()
    var isLoggedIn = false
    private init() {}
}

struct ContentView: View {
    let router: IRouter<AppRoute>

    var body: some View {
        IRouterView(router: router) { route in
            switch route {
            case .home:           HomeView()
            case .detail(let id): DetailView(id: id)
            case .settings:       SettingsView()
            case .login:          LoginView()
            case .feed:           FeedView()
            }
        }
    }
}
