import IRouter
import SwiftUI

struct NestedDemoView: View {
    @State private var router = IRouter<AppRoute>(root: .home)
    @State private var outcomes = DemoOutcomeStore()

    var body: some View {
        IRouterView(router: router) { route in
            NestedLabView(route: route, outcomes: outcomes)
        }
    }
}

private struct NestedLabView: View {
    let route: AppRoute
    let outcomes: DemoOutcomeStore
    @Environment(IRouter<AppRoute>.self) private var router

    var body: some View {
        DemoSectionContainer(title: "Nested Lab") {
            Section("Current destination") {
                DemoRouteHeader(
                    route: route,
                    detail: level == 0
                        ? "Open the first router-owned child level."
                        : "Dismiss pops this level before closing its owning modal.",
                    accessibilityIdentifier: level == 0
                        ? DemoAccessibility.nestedRoot
                        : DemoAccessibility.nestedLevelRoot(level)
                )
            }

            Section("Router inspector") {
                RouterInspector(
                    router: router,
                    latestOutcome: outcomes.value(for: outcomeKey),
                    accessibilityPrefix: DemoAccessibility.nestedInspectorPrefix(level)
                )
            }

            if level == 0 {
                Section("Parent command") {
                    DemoCommandButton(
                        "Open nested level 1",
                        systemImage: "square.stack.3d.forward.dottedline",
                        accessibilityIdentifier: DemoAccessibility.nestedOpenChild
                    ) {
                        record(router.sheet(.nested(level: 1)))
                    }
                }
            } else {
                Section("Level \(level) commands") {
                    DemoCommandButton(
                        "Push detail in level \(level)",
                        systemImage: "arrow.forward.square",
                        accessibilityIdentifier: DemoAccessibility.nestedPush(level)
                    ) {
                        record(router.push(
                            .detail(level),
                            options: [.deduplicateTop]
                        ))
                    }

                    DemoCommandButton(
                        "Dismiss once",
                        systemImage: "arrow.uturn.backward.circle",
                        accessibilityIdentifier: DemoAccessibility.nestedDismiss(level),
                        role: .cancel
                    ) {
                        outcomes.record(router.dismiss().displayText, for: outcomeKey)
                    }

                    if level < 3 {
                        DemoCommandButton(
                            "Open nested level \(level + 1)",
                            systemImage: "square.stack.3d.forward.dottedline",
                            accessibilityIdentifier: DemoAccessibility.nestedOpenNext(level)
                        ) {
                            record(router.sheet(.nested(level: level + 1)))
                        }
                    }
                }
            }
        }
    }

    private var level: Int {
        guard case .nested(let level) = router.root else { return 0 }
        return level
    }

    private var outcomeKey: String {
        "nested-level-\(level)"
    }

    private func record(_ outcome: IRouterNavigationOutcome<AppRoute>) {
        outcomes.record(outcome.displayText, for: outcomeKey)
    }
}
