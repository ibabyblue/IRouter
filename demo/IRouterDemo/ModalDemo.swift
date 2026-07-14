import IRouter
import SwiftUI

struct ModalDemoView: View {
    @State private var router = IRouter<AppRoute>(root: .home)
    @State private var latestOutcome = "No command yet"

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

private struct ModalLabView: View {
    let route: AppRoute
    let rootRouter: IRouter<AppRoute>
    @Binding var latestOutcome: String
    @Environment(IRouter<AppRoute>.self) private var router

    var body: some View {
        DemoSectionContainer(title: "Modal Lab") {
            Section("Current destination") {
                DemoRouteHeader(
                    route: route,
                    detail: isModalDestination
                        ? "This content reads its child router from the environment."
                        : "Run modal transactions through the owning root router.",
                    accessibilityIdentifier: modalIdentifier
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
    }

    private var modalIdentifier: String {
        switch presentedModalRoute {
        case .modal("A"): DemoAccessibility.modalA
        case .modal("B"): DemoAccessibility.modalB
        case .modal("C"): DemoAccessibility.modalC
        default: DemoAccessibility.modalRoot
        }
    }

    private var currentModalText: String {
        if let modalRoute = rootRouter.modalContext?.route {
            return modalRoute.compactTitle
        }
        return "None"
    }

    private var isModalDestination: Bool {
        router !== rootRouter
    }

    private var presentedModalRoute: AppRoute {
        isModalDestination ? router.root : route
    }

    private var inspectorPrefix: String {
        if isModalDestination {
            return "\(DemoAccessibility.modalInspectorPrefix).child"
        }
        return DemoAccessibility.modalInspectorPrefix
    }
}
