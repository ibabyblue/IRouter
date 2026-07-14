import IRouter
import SwiftUI

struct MultipleRoutersDemoView: View {
    @State private var routerA = IRouter<AppRoute>(root: .home)
    @State private var routerB = IRouter<AppRoute>(root: .feed)
    @State private var outcomeA = "No command yet"
    @State private var outcomeB = "No command yet"
    @State private var selection = MultipleRouterSelection.routerA

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
        .id(selection)
    }

    private var selectedRouter: IRouter<AppRoute> {
        switch selection {
        case .routerA: routerA
        case .routerB: routerB
        }
    }
}

private enum MultipleRouterSelection: String, CaseIterable, Identifiable {
    case routerA
    case routerB

    var id: Self { self }

    var title: String {
        switch self {
        case .routerA: "Router A"
        case .routerB: "Router B"
        }
    }
}

private struct MultipleRoutersLabView: View {
    let route: AppRoute
    let routerA: IRouter<AppRoute>
    let routerB: IRouter<AppRoute>
    @Binding var selection: MultipleRouterSelection
    @Binding var outcomeA: String
    @Binding var outcomeB: String

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

    private var selectedRouter: IRouter<AppRoute> {
        switch selection {
        case .routerA: routerA
        case .routerB: routerB
        }
    }

    private func record(_ outcome: IRouterNavigationOutcome<AppRoute>) {
        record(outcome.displayText)
    }

    private func record(_ outcome: String) {
        switch selection {
        case .routerA: outcomeA = outcome
        case .routerB: outcomeB = outcome
        }
    }
}

private extension MultipleRouterSelection {
    var accessibilityIdentifier: String {
        switch self {
        case .routerA: DemoAccessibility.multipleRouterAOption
        case .routerB: DemoAccessibility.multipleRouterBOption
        }
    }
}
