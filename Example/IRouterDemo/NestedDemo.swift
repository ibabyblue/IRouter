import IRouter
import SwiftUI

/// Hosts the hierarchical child-router and nested-modal lab.
struct NestedDemoView: View {
    /// The root router that opens the first nested modal level.
    @State private var router = IRouter<AppRoute>(root: .home)
    /// Outcome text retained independently for each visible level.
    @State private var outcomes = DemoOutcomeStore()

    /// Hosts every hierarchy level through the shared destination builder.
    var body: some View {
        IRouterView(router: router) { route in
            NestedLabView(route: route, outcomes: outcomes)
        }
    }
}

/// Renders commands for one router level in the nested hierarchy.
private struct NestedLabView: View {
    /// The route currently rendered at this level.
    let route: AppRoute
    /// The shared per-level outcome store.
    let outcomes: DemoOutcomeStore
    /// The child or root router for the visible level.
    @Environment(IRouter<AppRoute>.self) private var router

    /// Builds hierarchy navigation, dismissal, and inspection controls.
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

    /// The modal nesting level represented by the current router root.
    private var level: Int {
        guard case .nested(let level) = router.root else { return 0 }
        return level
    }

    /// The stable storage key for this level's latest outcome.
    private var outcomeKey: String {
        "nested-level-\(level)"
    }

    /// Records a formatted navigation outcome for the current level.
    ///
    /// - Parameter outcome: The navigation result to display.
    private func record(_ outcome: IRouterNavigationOutcome<AppRoute>) {
        outcomes.record(outcome.displayText, for: outcomeKey)
    }
}
