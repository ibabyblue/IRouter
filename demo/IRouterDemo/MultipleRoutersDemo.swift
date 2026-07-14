import IRouter
import SwiftUI

struct MultipleRoutersDemoView: View {
    @State private var routerA = IRouter<AppRoute>(root: .home)
    @State private var routerB = IRouter<AppRoute>(root: .feed)
    @State private var outcomeA = "No command yet"
    @State private var outcomeB = "No command yet"

    var body: some View {
        NavigationStack {
            DemoSectionContainer(title: "Multiple Routers Lab") {
                Section("Router A") {
                    RouterInspector(
                        router: routerA,
                        latestOutcome: outcomeA,
                        accessibilityPrefix: "demo.multiple.routerA"
                    )

                    DemoCommandButton(
                        "Push detail on A",
                        systemImage: "a.square",
                        accessibilityIdentifier: DemoAccessibility.routerAPush
                    ) {
                        let options: IRouterNavigationOptions = [.deduplicateTop]
                        outcomeA = routerA.push(
                            .detail(routerA.path.count + 1),
                            options: options
                        ).displayText
                    }

                    DemoCommandButton(
                        "Pop A",
                        systemImage: "arrow.backward",
                        accessibilityIdentifier: DemoAccessibility.routerAPop
                    ) {
                        outcomeA = routerA.pop() ? "Popped A" : "A unchanged"
                    }
                }

                Section("Router B") {
                    RouterInspector(
                        router: routerB,
                        latestOutcome: outcomeB,
                        accessibilityPrefix: "demo.multiple.routerB"
                    )

                    DemoCommandButton(
                        "Push settings on B",
                        systemImage: "b.square",
                        accessibilityIdentifier: DemoAccessibility.routerBPush
                    ) {
                        let options: IRouterNavigationOptions = [.deduplicateTop]
                        outcomeB = routerB.push(
                            .settings,
                            options: options
                        ).displayText
                    }

                    DemoCommandButton(
                        "Pop B",
                        systemImage: "arrow.backward",
                        accessibilityIdentifier: DemoAccessibility.routerBPop
                    ) {
                        outcomeB = routerB.pop() ? "Popped B" : "B unchanged"
                    }
                }
            }
        }
    }
}
