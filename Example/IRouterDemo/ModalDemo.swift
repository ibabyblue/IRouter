import IRouter
import SwiftUI

/// Hosts direct-modal presentation, replacement, and dismissal scenarios.
struct ModalDemoView: View {
    /// The root router that owns the lab's direct modal.
    @State private var router = IRouter<AppRoute>(root: .home)
    /// The latest formatted modal transaction outcome.
    @State private var latestOutcome = "No command yet"

    /// Hosts root and modal-child routes through one destination builder.
    var body: some View {
        IRouterView(router: router) { route in
            ModalLabView(
                route: route,
                rootRouter: router,
                latestOutcome: $latestOutcome
            )
        }
    }
}

/// Renders modal commands for either the root router or a modal child router.
private struct ModalLabView: View {
    /// The route currently rendered at this hierarchy level.
    let route: AppRoute
    /// The root router used for direct-modal replacement scenarios.
    let rootRouter: IRouter<AppRoute>
    /// The latest outcome shared across root and modal content.
    @Binding var latestOutcome: String
    /// The router belonging to the currently visible hierarchy level.
    @Environment(IRouter<AppRoute>.self) private var router

    /// Builds modal presentation, replacement, child-stack, and inspector controls.
    var body: some View {
        DemoSectionContainer(title: "Modal Lab") {
            Section("Current destination") {
                DemoRouteHeader(
                    route: route,
                    detail: isModalDestination
                        ? "This content reads its child router from the environment."
                        : "Run modal transactions through the owning root router.",
                    accessibilityIdentifier: DemoAccessibility.modalHeader(modalIdentifier)
                )

                Text(currentModalText)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(DemoAccessibility.modalState)
            }

            if isModalDestination {
                Section("Regression commands") {
                    DemoCommandButton(
                        "Dismiss current modal",
                        systemImage: "xmark",
                        accessibilityIdentifier: DemoAccessibility.dismissCurrent,
                        role: .cancel
                    ) {
                        latestOutcome = router.dismiss().displayText
                    }

                    #if !os(macOS)
                    DemoCommandButton(
                        "Replace with cover B",
                        systemImage: "rectangle.inset.filled",
                        accessibilityIdentifier: DemoAccessibility.replaceWithCoverB
                    ) {
                        latestOutcome = rootRouter.fullScreenCover(
                            .modal("B"),
                            options: [.dismissPresented]
                        ).displayText
                    }
                    #endif

                    DemoCommandButton(
                        "Rapidly replace with B, then C",
                        systemImage: "forward.end.alt",
                        accessibilityIdentifier: DemoAccessibility.rapidReplaceABC
                    ) {
                        _ = rootRouter.sheet(
                            .modal("B"),
                            options: [.dismissPresented]
                        )
                        latestOutcome = rootRouter.sheet(
                            .modal("C"),
                            options: [.dismissPresented]
                        ).displayText
                    }
                }

                Section("Additional root commands") {
                    DemoCommandButton(
                        "Try second sheet without replacement",
                        systemImage: "exclamationmark.rectangle.stack",
                        accessibilityIdentifier: DemoAccessibility.rejectSecondModal
                    ) {
                        latestOutcome = rootRouter.sheet(.modal("B")).displayText
                    }

                    DemoCommandButton(
                        "Replace with sheet B",
                        systemImage: "rectangle.2.swap",
                        accessibilityIdentifier: DemoAccessibility.replaceWithSheetB
                    ) {
                        latestOutcome = rootRouter.sheet(
                            .modal("B"),
                            options: [.dismissPresented]
                        ).displayText
                    }

                    DemoCommandButton(
                        "Replace modal with pushed detail",
                        systemImage: "arrow.forward.to.line",
                        accessibilityIdentifier: DemoAccessibility.replaceWithPush
                    ) {
                        latestOutcome = rootRouter.push(
                            .detail(1),
                            options: [.dismissPresented]
                        ).displayText
                    }
                }

                Section("Child router") {
                    DemoCommandButton(
                        "Push inside modal",
                        systemImage: "arrow.forward.square",
                        accessibilityIdentifier: DemoAccessibility.modalChildPush
                    ) {
                        latestOutcome = router.push(
                            .detail(router.path.count + 1),
                            options: [.deduplicateTop]
                        ).displayText
                    }
                }
            } else {
                Section("Present") {
                    DemoCommandButton(
                        "Open sheet A",
                        systemImage: "rectangle.bottomhalf.inset.filled",
                        accessibilityIdentifier: DemoAccessibility.openSheetA
                    ) {
                        latestOutcome = rootRouter.sheet(.modal("A")).displayText
                    }

                    #if os(macOS)
                    DemoCommandButton(
                        "Try unsupported cover B",
                        systemImage: "nosign",
                        accessibilityIdentifier: DemoAccessibility.openCoverB
                    ) {
                        latestOutcome = rootRouter.navigate(
                            to: .modal("B"),
                            as: .fullScreenCover,
                            options: [.dismissPresented]
                        ).displayText
                    }
                    #else
                    DemoCommandButton(
                        "Open cover B",
                        systemImage: "rectangle.inset.filled",
                        accessibilityIdentifier: DemoAccessibility.openCoverB
                    ) {
                        latestOutcome = rootRouter.fullScreenCover(
                            .modal("B"),
                            options: [.dismissPresented]
                        ).displayText
                    }
                    #endif
                }
            }

            Section("Router inspector") {
                RouterInspector(
                    router: router,
                    latestOutcome: latestOutcome,
                    accessibilityPrefix: inspectorPrefix
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(modalIdentifier)
    }

    /// The stable accessibility identity for the currently rendered modal route.
    private var modalIdentifier: String {
        switch presentedModalRoute {
        case .modal("A"): DemoAccessibility.modalA
        case .modal("B"): DemoAccessibility.modalB
        case .modal("C"): DemoAccessibility.modalC
        default: DemoAccessibility.modalRoot
        }
    }

    /// The compact route name of the root router's current direct modal.
    private var currentModalText: String {
        if let modalRoute = rootRouter.modalContext?.route {
            return modalRoute.compactTitle
        }
        return "None"
    }

    /// A value indicating whether this view is rendered inside a modal child router.
    private var isModalDestination: Bool {
        router !== rootRouter
    }

    /// The route used to select root or modal-specific presentation metadata.
    private var presentedModalRoute: AppRoute {
        isModalDestination ? router.root : route
    }

    /// The state-inspector prefix for the root or modal-child router.
    private var inspectorPrefix: String {
        if isModalDestination {
            return "\(DemoAccessibility.modalInspectorPrefix).child"
        }
        return DemoAccessibility.modalInspectorPrefix
    }
}
