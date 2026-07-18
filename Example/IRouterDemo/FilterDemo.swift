import IRouter
import SwiftUI

/// Hosts the filter, redirect, block, and cycle-detection lab.
struct FilterDemoView: View {
    /// The authentication state read synchronously by the filter chain.
    @State private var auth: DemoAuthState
    /// The router configured with the lab's complete filter chain.
    @State private var router: IRouter<AppRoute>
    /// The latest formatted navigation outcome.
    @State private var latestOutcome = "No command yet"

    /// Creates the authentication state and router filter chain together.
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

    /// Hosts every filtered destination in one router view.
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

/// Renders filter controls and state for the current route.
private struct FilterLabView: View {
    /// The route currently rendered by the router.
    let route: AppRoute
    /// The authentication state shared with the filter closure.
    @Bindable var auth: DemoAuthState
    /// The latest outcome shared with the root lab.
    @Binding var latestOutcome: String
    /// The router for the currently visible hierarchy level.
    @Environment(IRouter<AppRoute>.self) private var router

    /// Builds authentication, inspector, filter, and dismissal controls.
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
