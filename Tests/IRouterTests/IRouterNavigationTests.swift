import Testing
@testable import IRouter

@Suite("Navigation values")
struct IRouterNavigationValueTests {
    @Test
    func destinationRetainsRouteAndPresentation() {
        let destination = IRouterDestination(
            route: TestRoute.detail(42),
            presentation: .push
        )

        #expect(destination.route == .detail(42))
        #expect(destination.presentation == .push)
    }

    @Test
    func navigationOptionsCompose() {
        let options: IRouterNavigationOptions = [
            .deduplicateTop,
            .dismissPresented,
        ]

        #expect(options.contains(.deduplicateTop))
        #expect(options.contains(.dismissPresented))
    }
}
