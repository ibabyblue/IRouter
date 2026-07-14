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

@Suite("Stack navigation")
struct IRouterStackTests {
    @Test @MainActor
    func pushCommitsDestination() {
        let router = IRouter<TestRoute>(root: .home)

        let outcome = router.push(.detail(1))

        #expect(outcome == .committed(.init(route: .detail(1), presentation: .push)))
        #expect(router.path == [.detail(1)])
    }

    @Test @MainActor
    func finalDestinationIsDeduplicatedWithoutMutation() {
        let router = IRouter<TestRoute>(root: .home)
        router.push(.detail(1))
        let before = router.path

        let outcome = router.push(.detail(1), options: [.deduplicateTop])

        #expect(outcome == .deduplicated(.init(route: .detail(1), presentation: .push)))
        #expect(router.path == before)
    }

    @Test @MainActor
    func filterCanReadMainActorState() {
        let auth = TestAuthState()
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, _ in
                route == .settings && !auth.isLoggedIn ? .block : .allow
            },
        ])

        #expect(router.push(.settings) == .blocked(.init(route: .settings, presentation: .push)))
        auth.isLoggedIn = true
        #expect(router.push(.settings) == .committed(.init(route: .settings, presentation: .push)))
    }

    @Test @MainActor
    func filtersRunInOrderAndStopAtFirstBlock() {
        var order: [Int] = []
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { _, _ in
                order.append(1)
                return .allow
            },
            IRouterFilter { _, _ in
                order.append(2)
                return .block
            },
            IRouterFilter { _, _ in
                order.append(3)
                return .allow
            },
        ])

        let outcome = router.push(.detail(1))

        #expect(outcome == .blocked(.init(route: .detail(1), presentation: .push)))
        #expect(order == [1, 2])
        #expect(router.path.isEmpty)
    }

    @Test @MainActor
    func popAndPopToRootReportMutation() {
        let router = IRouter<TestRoute>(root: .home)
        #expect(router.pop() == false)
        router.push(.detail(1))
        router.push(.detail(2))
        #expect(router.pop() == true)
        #expect(router.path == [.detail(1)])
        #expect(router.popToRoot() == true)
        #expect(router.path.isEmpty)
        #expect(router.popToRoot() == false)
    }

    @Test @MainActor
    func uiSynchronizationOnlyAcceptsPathContraction() {
        let router = IRouter<TestRoute>(root: .home)
        router.push(.detail(1))
        router.push(.detail(2))

        #expect(router.synchronizePathFromUI([.detail(1)]) == true)
        #expect(router.path == [.detail(1)])
        #expect(router.synchronizePathFromUI([.detail(1), .settings]) == false)
        #expect(router.path == [.detail(1)])
        #expect(router.synchronizePathFromUI([.settings]) == false)
        #expect(router.path == [.detail(1)])
    }
}
