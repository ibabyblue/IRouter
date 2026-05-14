import SwiftUI

public struct IRouterView<Route: Hashable & Sendable, Content: View>: View {

    @Bindable private var router: IRouter<Route>
    private let destination: (Route) -> Content

    public init(
        router: IRouter<Route>,
        @ViewBuilder destination: @escaping (Route) -> Content
    ) {
        _router = Bindable(router)
        self.destination = destination
    }

    public var body: some View {
        NavigationStack(path: $router.path) {
            destination(router.root)
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
        .sheet(item: $router.sheetContext) { ctx in
            IRouterView(router: ctx.childRouter, destination: destination)
        }
        #if !os(macOS)
        .fullScreenCover(item: $router.coverContext) { ctx in
            IRouterView(router: ctx.childRouter, destination: destination)
        }
        #endif
        .environment(router)
    }
}
