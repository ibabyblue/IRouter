import IRouter
import SwiftUI

struct StackDemoView: View {
    @State private var router = IRouter<AppRoute>(root: .home)
    @State private var latestOutcome = "No command yet"

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

private struct StackLabView: View {
    let route: AppRoute
    @Binding var latestOutcome: String
    @Environment(IRouter<AppRoute>.self) private var router

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
