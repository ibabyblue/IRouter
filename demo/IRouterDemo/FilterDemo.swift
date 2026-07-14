import IRouter
import SwiftUI

struct FilterDemoView: View {
    @State private var auth: DemoAuthState
    @State private var router: IRouter<AppRoute>
    @State private var latestOutcome = "No command yet"

    init() {
        let auth = DemoAuthState()
        _auth = State(initialValue: auth)
        _router = State(initialValue: IRouter(root: .home, filters: [
            IRouterFilter { route, presentation in
                switch route {
                case .settings where !auth.isLoggedIn:
                    .redirect(.login, .sheet)
                case .blocked:
                    .block
                case .selfCycle:
                    .redirect(.selfCycle, presentation)
                case .cycleA:
                    .redirect(.cycleB, presentation)
                case .cycleB:
                    .redirect(.cycleA, presentation)
                default:
                    .allow
                }
            },
        ]))
    }

    var body: some View {
        IRouterView(router: router) { route in
            FilterLabView(
                route: route,
                auth: auth,
                latestOutcome: $latestOutcome
            )
        }
    }
}

private struct FilterLabView: View {
    let route: AppRoute
    @Bindable var auth: DemoAuthState
    @Binding var latestOutcome: String
    @Environment(IRouter<AppRoute>.self) private var router

    var body: some View {
        DemoSectionContainer(title: "Filter Lab") {
            Section("Current destination") {
                DemoRouteHeader(
                    route: route,
                    detail: route == .login
                        ? "Settings redirected here because authentication was off."
                        : "Every command resolves synchronously through the filter chain.",
                    accessibilityIdentifier: DemoAccessibility.stateCurrentRoute("demo.filters")
                )
            }

            Section("Authentication") {
                Toggle(isOn: $auth.isLoggedIn) {
                    Label("Logged in", systemImage: "person.crop.circle.badge.checkmark")
                }
                .accessibilityIdentifier(DemoAccessibility.authToggle)
            }

            Section("Router inspector") {
                RouterInspector(
                    router: router,
                    latestOutcome: latestOutcome,
                    accessibilityPrefix: "demo.filters"
                )
            }

            Section("Filter outcomes") {
                DemoCommandButton(
                    "Allow detail",
                    systemImage: "checkmark.circle",
                    accessibilityIdentifier: DemoAccessibility.filterAllow
                ) {
                    latestOutcome = router.push(.detail(1)).displayText
                }

                DemoCommandButton(
                    "Block route",
                    systemImage: "hand.raised",
                    accessibilityIdentifier: DemoAccessibility.filterBlock
                ) {
                    latestOutcome = router.push(.blocked).displayText
                }

                DemoCommandButton(
                    auth.isLoggedIn ? "Open settings" : "Redirect settings to login",
                    systemImage: "arrow.triangle.turn.up.right.circle",
                    accessibilityIdentifier: DemoAccessibility.filterSettings
                ) {
                    let outcome = router.push(.settings)
                    latestOutcome = auth.isLoggedIn
                        ? outcome.displayText
                        : "settings as push -> \(outcome.displayText)"
                }

                DemoCommandButton(
                    "Reject self redirect cycle",
                    systemImage: "arrow.clockwise.circle",
                    accessibilityIdentifier: DemoAccessibility.filterSelfCycle
                ) {
                    latestOutcome = router.push(.selfCycle).displayText
                }

                DemoCommandButton(
                    "Reject two-node redirect cycle",
                    systemImage: "arrow.triangle.2.circlepath",
                    accessibilityIdentifier: DemoAccessibility.filterTwoNodeCycle
                ) {
                    latestOutcome = router.push(.cycleA).displayText
                }
            }

            Section("Dismiss") {
                DemoCommandButton(
                    "Dismiss current level",
                    systemImage: "xmark.circle",
                    accessibilityIdentifier: DemoAccessibility.filterDismiss
                ) {
                    latestOutcome = router.dismiss().displayText
                }
            }
        }
    }
}
