import IRouter
import SwiftUI

struct NestedDemoView: View {
    @State private var router = IRouter<AppRoute>(root: .home)
    @State private var latestOutcome = "No command yet"

    var body: some View {
        IRouterView(router: router) { route in
            NestedLabView(route: route, latestOutcome: $latestOutcome)
        }
    }
}

private struct NestedLabView: View {
    let route: AppRoute
    @Binding var latestOutcome: String
    @Environment(IRouter<AppRoute>.self) private var router

    var body: some View {
        DemoSectionContainer(title: "Nested Lab") {
            Section("Current destination") {
                DemoRouteHeader(
                    route: route,
                    detail: isChild
                        ? "Push and pop inside the child stack, then dismiss its parent modal."
                        : "Open one router-owned child level.",
                    accessibilityIdentifier: DemoAccessibility.stateCurrentRoute(
                        isChild ? "demo.nested.child" : "demo.nested.root"
                    )
                )
            }

            Section("Router inspector") {
                RouterInspector(
                    router: router,
                    latestOutcome: latestOutcome,
                    accessibilityPrefix: isChild ? "demo.nested.child" : "demo.nested.root"
                )
            }

            if isChild {
                Section("Child commands") {
                    DemoCommandButton(
                        "Push child detail",
                        systemImage: "arrow.forward.square",
                        accessibilityIdentifier: DemoAccessibility.nestedPush
                    ) {
                        latestOutcome = router.push(
                            .detail(router.path.count + 1),
                            options: [.deduplicateTop]
                        ).displayText
                    }

                    DemoCommandButton(
                        "Pop child stack",
                        systemImage: "arrow.backward",
                        accessibilityIdentifier: DemoAccessibility.nestedPop
                    ) {
                        latestOutcome = router.pop()
                            ? "Popped child stack"
                            : "Child stack already at root"
                    }

                    DemoCommandButton(
                        "Dismiss child",
                        systemImage: "xmark.circle",
                        accessibilityIdentifier: DemoAccessibility.nestedDismiss,
                        role: .cancel
                    ) {
                        latestOutcome = router.dismiss().displayText
                    }
                }
            } else {
                Section("Parent command") {
                    DemoCommandButton(
                        "Open child router",
                        systemImage: "square.stack.3d.forward.dottedline",
                        accessibilityIdentifier: DemoAccessibility.nestedOpenChild
                    ) {
                        let options: IRouterNavigationOptions = []
                        latestOutcome = router.sheet(
                            .nested(level: 1),
                            options: options
                        ).displayText
                    }
                }
            }
        }
    }

    private var isChild: Bool {
        if case .nested = route { return true }
        return !router.path.isEmpty
    }
}
