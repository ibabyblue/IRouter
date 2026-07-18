import IRouter
import SwiftUI

/// Hosts commands against two independent router instances.
struct MultipleRoutersDemoView: View {
    /// The router rooted at the home route.
    @State private var routerA = IRouter<AppRoute>(root: .home)
    /// The router rooted at the feed route.
    @State private var routerB = IRouter<AppRoute>(root: .feed)
    /// The latest formatted outcome produced by Router A.
    @State private var outcomeA = "No command yet"
    /// The latest formatted outcome produced by Router B.
    @State private var outcomeB = "No command yet"
    /// The router currently hosted and targeted by commands.
    @State private var selection = MultipleRouterSelection.routerA

    /// Hosts the selected router without recreating `IRouterView` by identity.
    var body: some View {
        IRouterView(router: selectedRouter) { route in
            MultipleRoutersLabView(
                route: route,
                routerA: routerA,
                routerB: routerB,
                selection: $selection,
                outcomeA: $outcomeA,
                outcomeB: $outcomeB
            )
        }
    }

    /// The router selected for presentation and commands.
    private var selectedRouter: IRouter<AppRoute> {
        switch selection {
        case .routerA: routerA
        case .routerB: routerB
        }
    }
}

/// Identifies which independent router the lab currently targets.
private enum MultipleRouterSelection: String, CaseIterable, Identifiable {
    /// Selects the home-rooted router.
    case routerA
    /// Selects the feed-rooted router.
    case routerB

    /// Uses the selection value as stable picker identity.
    var id: Self { self }

    /// The visible picker title for this router.
    var title: String {
        switch self {
        case .routerA: "Router A"
        case .routerB: "Router B"
        }
    }
}

/// Renders shared commands and separate inspectors for both routers.
private struct MultipleRoutersLabView: View {
    /// The route rendered by the currently selected router.
    let route: AppRoute
    /// The independent home-rooted router.
    let routerA: IRouter<AppRoute>
    /// The independent feed-rooted router.
    let routerB: IRouter<AppRoute>
    /// The selected router shared with the root lab.
    @Binding var selection: MultipleRouterSelection
    /// The latest Router A outcome shared with the root lab.
    @Binding var outcomeA: String
    /// The latest Router B outcome shared with the root lab.
    @Binding var outcomeB: String

    /// Builds target selection, commands, and both router inspectors.
    var body: some View {
        DemoSectionContainer(title: "Multiple Routers Lab") {
            Section("Command target") {
                Picker("Router", selection: $selection) {
                    ForEach(MultipleRouterSelection.allCases) { option in
                        Text(option.title)
                            .tag(option)
                            .accessibilityIdentifier(option.accessibilityIdentifier)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(DemoAccessibility.multipleTargetPicker)

                LabeledContent("Selected") {
                    Text(selection.title)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(DemoAccessibility.multipleSelectedState)
                }

                DemoRouteHeader(
                    route: route,
                    detail: "Commands below target only \(selection.title).",
                    accessibilityIdentifier: DemoAccessibility.multipleRoot
                )
            }

            Section("Selected commands") {
                DemoCommandButton(
                    "Push detail",
                    systemImage: "arrow.forward.square",
                    accessibilityIdentifier: DemoAccessibility.multiplePush
                ) {
                    record(selectedRouter.push(
                        .detail(selectedRouter.path.count + 1),
                        options: [.deduplicateTop]
                    ))
                }

                DemoCommandButton(
                    "Present modal",
                    systemImage: "rectangle.bottomhalf.inset.filled",
                    accessibilityIdentifier: DemoAccessibility.multiplePresent
                ) {
                    record(selectedRouter.sheet(.modal(selection.title)))
                }

                DemoCommandButton(
                    "Pop",
                    systemImage: "arrow.backward",
                    accessibilityIdentifier: DemoAccessibility.multiplePop
                ) {
                    record(selectedRouter.pop() ? "Popped top route" : "Unchanged")
                }

                DemoCommandButton(
                    "Dismiss",
                    systemImage: "xmark.circle",
                    accessibilityIdentifier: DemoAccessibility.multipleDismiss,
                    role: .cancel
                ) {
                    record(selectedRouter.dismiss().displayText)
                }
            }

            Section("Router A inspector") {
                RouterInspector(
                    router: routerA,
                    latestOutcome: outcomeA,
                    accessibilityPrefix: DemoAccessibility.multipleRouterAPrefix
                )
            }

            Section("Router B inspector") {
                RouterInspector(
                    router: routerB,
                    latestOutcome: outcomeB,
                    accessibilityPrefix: DemoAccessibility.multipleRouterBPrefix
                )
            }
        }
    }

    /// The router currently targeted by shared commands.
    private var selectedRouter: IRouter<AppRoute> {
        switch selection {
        case .routerA: routerA
        case .routerB: routerB
        }
    }

    /// Formats and records a navigation outcome for the selected router.
    ///
    /// - Parameter outcome: The navigation result to display.
    private func record(_ outcome: IRouterNavigationOutcome<AppRoute>) {
        record(outcome.displayText)
    }

    /// Records already formatted outcome text for the selected router.
    ///
    /// - Parameter outcome: The text to store in the selected inspector.
    private func record(_ outcome: String) {
        switch selection {
        case .routerA: outcomeA = outcome
        case .routerB: outcomeB = outcome
        }
    }
}

/// Supplies UI-test identity for router-selection picker options.
private extension MultipleRouterSelection {
    /// The stable accessibility identity for this selection.
    var accessibilityIdentifier: String {
        switch self {
        case .routerA: DemoAccessibility.multipleRouterAOption
        case .routerB: DemoAccessibility.multipleRouterBOption
        }
    }
}
