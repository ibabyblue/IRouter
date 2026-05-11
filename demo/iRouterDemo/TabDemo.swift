import SwiftUI
import iRouter

struct TabDemoView: View {
    @State private var tabARouter = IRouter<AppRoute>(root: .home)
    @State private var tabBRouter = IRouter<AppRoute>(root: .feed)

    var body: some View {
        TabView {
            IRouterView(router: tabARouter) { route in
                switch route {
                case .home:           HomeView()
                case .detail(let id): DetailView(id: id)
                case .settings:       SettingsView()
                case .login:          LoginView()
                case .feed:           FeedView()
                }
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            IRouterView(router: tabBRouter) { route in
                switch route {
                case .home:           HomeView()
                case .detail(let id): DetailView(id: id)
                case .settings:       SettingsView()
                case .login:          LoginView()
                case .feed:           FeedView()
                }
            }
            .tabItem {
                Label("Feed", systemImage: "list.bullet")
            }
        }
    }
}
