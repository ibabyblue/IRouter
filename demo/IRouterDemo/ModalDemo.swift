import IRouter
import SwiftUI

struct ModalDemoView: View {
    @State private var router = IRouter<AppRoute>(root: .home)
    @State private var latestOutcome = "No command yet"

    var body: some View {
        IRouterView(router: router) { route in
            ModalLabView(route: route, latestOutcome: $latestOutcome)
        }
    }
}

private struct ModalLabView: View {
    let route: AppRoute
    @Binding var latestOutcome: String
    @Environment(IRouter<AppRoute>.self) private var router

    var body: some View {
        DemoSectionContainer(title: "Modal Lab") {
            Section("Current destination") {
                DemoRouteHeader(
                    route: route,
                    detail: route == .home
                        ? "Present one modal through the router."
                        : "This content is owned by the modal child router.",
                    accessibilityIdentifier: modalIdentifier
                )

                Text(currentModalText)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(DemoAccessibility.modalState)
            }

            Section("Router inspector") {
                RouterInspector(
                    router: router,
                    latestOutcome: latestOutcome,
                    accessibilityPrefix: "demo.modals"
                )
            }

            if route == .home {
                Section("Present") {
                    DemoCommandButton(
                        "Open sheet A",
                        systemImage: "rectangle.bottomhalf.inset.filled",
                        accessibilityIdentifier: DemoAccessibility.openSheetA
                    ) {
                        let options: IRouterNavigationOptions = []
                        latestOutcome = router.sheet(
                            .modal("A"),
                            options: options
                        ).displayText
                    }

                    DemoCommandButton(
                        "Open cover B",
                        systemImage: "rectangle.inset.filled",
                        accessibilityIdentifier: DemoAccessibility.openCoverB
                    ) {
                        let options: IRouterNavigationOptions = []
                        #if os(macOS)
                        latestOutcome = router.navigate(
                            to: .modal("B"),
                            as: .fullScreenCover,
                            options: options
                        ).displayText
                        #else
                        latestOutcome = router.fullScreenCover(
                            .modal("B"),
                            options: options
                        ).displayText
                        #endif
                    }
                }
            } else {
                Section("Child router") {
                    DemoCommandButton(
                        "Dismiss current modal",
                        systemImage: "xmark",
                        accessibilityIdentifier: DemoAccessibility.dismissCurrent,
                        role: .cancel
                    ) {
                        latestOutcome = router.dismiss().displayText
                    }
                }
            }
        }
    }

    private var modalIdentifier: String {
        switch route {
        case .modal("A"): DemoAccessibility.modalA
        case .modal("B"): DemoAccessibility.modalB
        case .modal("C"): DemoAccessibility.modalC
        default: DemoAccessibility.stateCurrentRoute("demo.modals")
        }
    }

    private var currentModalText: String {
        if let modalRoute = router.modalContext?.route {
            return modalRoute.compactTitle
        }
        if case .modal = route {
            return route.compactTitle
        }
        return "none"
    }
}
