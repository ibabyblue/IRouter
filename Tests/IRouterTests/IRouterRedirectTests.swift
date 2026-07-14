import Testing
@testable import IRouter

@Suite("Redirect resolution")
struct IRouterRedirectTests {
    @Test @MainActor
    func redirectCommitsFinalDestination() {
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, _ in
                route == .settings ? .redirect(.login, .push) : .allow
            },
        ])

        let outcome = router.push(.settings)

        #expect(outcome == .committed(.init(route: .login, presentation: .push)))
        #expect(router.path == [.login])
        #expect(router.modalContext == nil)
    }

    @Test @MainActor
    func selfRedirectReturnsCycleWithoutMutation() {
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, presentation in
                .redirect(route, presentation)
            },
        ])

        let outcome = router.push(.settings)

        #expect(outcome == .rejected(.redirectCycle(chain: [
            .init(route: .settings, presentation: .push),
            .init(route: .settings, presentation: .push),
        ])))
        #expect(router.path.isEmpty)
        #expect(router.modalContext == nil)
    }

    @Test @MainActor
    func optionsApplyToFinalRedirectedDestination() {
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, _ in
                route == .settings ? .redirect(.detail(1), .push) : .allow
            },
        ])
        router.push(.detail(1))

        let outcome = router.push(
            .settings,
            options: [.deduplicateTop]
        )

        #expect(outcome == .deduplicated(.init(
            route: .detail(1),
            presentation: .push
        )))
        #expect(router.path == [.detail(1)])
    }

    @Test @MainActor
    func twoNodeRedirectReturnsCycle() {
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, presentation in
                switch route {
                case .detail(1): .redirect(.detail(2), presentation)
                case .detail(2): .redirect(.detail(1), presentation)
                default: .allow
                }
            },
        ])

        let outcome = router.push(.detail(1))

        #expect(outcome == .rejected(.redirectCycle(chain: [
            .init(route: .detail(1), presentation: .push),
            .init(route: .detail(2), presentation: .push),
            .init(route: .detail(1), presentation: .push),
        ])))
    }

    @Test @MainActor
    func thirtyThirdRedirectReturnsLimitFailure() {
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, presentation in
                guard case .redirect(let value) = route else { return .allow }
                return .redirect(.redirect(value + 1), presentation)
            },
        ])

        let outcome = router.push(.redirect(0))

        guard case .rejected(.redirectLimitExceeded(let chain, let limit)) = outcome else {
            Issue.record("Expected redirectLimitExceeded, got \(outcome)")
            return
        }
        #expect(limit == 32)
        #expect(chain.count == 34)
        #expect(chain.first?.route == .redirect(0))
        #expect(chain.last?.route == .redirect(33))
        #expect(router.path.isEmpty)
    }
}
