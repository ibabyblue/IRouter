import IRouter
import SwiftUI

/// Hosts the typed stack transaction lab.
struct StackDemoView: View {
    /// The router that owns the lab's navigation stack.
    @State private var router = IRouter<AppRoute>(root: .home)
    /// The latest formatted stack command outcome.
    @State private var latestOutcome = "No command yet"

    /// Hosts stack destinations in one router view.
    var body: some View {
        IRouterView(router: router) { route in
            switch route {
            case .home, .detail, .settings:
                StackLabView(route: route, latestOutcome: $latestOutcome)
            default:
                DemoSectionContainer(title: route.title) {
                    Section {
                        Text("This route is not part of the Stack lab.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// Renders stack commands and state for the current route.
private struct StackLabView: View {
    /// The route currently rendered by the stack.
    let route: AppRoute
    /// The latest outcome shared with the root lab.
    @Binding var latestOutcome: String
    /// The router injected for the visible stack level.
    @Environment(IRouter<AppRoute>.self) private var router

    /// Builds append, contraction, and state-inspection controls.
    var body: some View {
        DemoSectionContainer(title: "Stack Lab") {
            Section("Current destination") {
                DemoRouteHeader(
                    route: route,
                    detail: "Append routes, deduplicate the top entry, or contract the stack.",
                    accessibilityIdentifier: DemoAccessibility.stateCurrentRoute("demo.stack")
                )
            }

            Section("Router inspector") {
                RouterInspector(
                    router: router,
                    latestOutcome: latestOutcome,
                    accessibilityPrefix: "demo.stack"
                )
            }

            Section("Append") {
                DemoCommandButton(
                    "Append next detail",
                    systemImage: "plus.square.on.square",
                    accessibilityIdentifier: DemoAccessibility.stackPushDetail
                ) {
                    let next = router.path.compactMap { route -> Int? in
                        guard case .detail(let value) = route else { return nil }
                        return value
                    }.max().map { $0 + 1 } ?? 1
                    latestOutcome = router.push(.detail(next)).displayText
                }

                DemoCommandButton(
                    "Append settings",
                    systemImage: "gearshape",
                    accessibilityIdentifier: DemoAccessibility.stackPushSettings
                ) {
                    latestOutcome = router.push(.settings).displayText
                }

                DemoCommandButton(
                    "Append current route with deduplication",
                    systemImage: "equal.square",
                    accessibilityIdentifier: DemoAccessibility.stackDeduplicate,
                    isDisabled: route == .home
                ) {
                    latestOutcome = router.push(
                        route,
                        options: [.deduplicateTop]
                    ).displayText
                }
            }

            Section("Contract") {
                DemoCommandButton(
                    "Pop",
                    systemImage: "arrow.backward",
                    accessibilityIdentifier: DemoAccessibility.stackPop
                ) {
                    latestOutcome = router.pop()
                        ? "Popped top route"
                        : "Pop unchanged"
                }

                DemoCommandButton(
                    "Pop to root",
                    systemImage: "arrow.uturn.backward",
                    accessibilityIdentifier: DemoAccessibility.stackPopToRoot
                ) {
                    latestOutcome = router.popToRoot()
                        ? "Popped to root"
                        : "Already at root"
                }
            }
        }
    }
}
