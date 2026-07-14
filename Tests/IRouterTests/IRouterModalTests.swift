import Testing
@testable import IRouter

@Suite("Modal transactions")
struct IRouterModalTests {
    @Test @MainActor
    func sheetCreatesOneTypedContext() {
        let router = IRouter<TestRoute>(root: .home)

        let outcome = router.sheet(.modal("A"))

        #expect(outcome == .committed(.init(route: .modal("A"), presentation: .sheet)))
        #expect(router.modalContext?.route == .modal("A"))
        #expect(router.modalContext?.style == .sheet)
        #expect(router.modalContext?.childRouter.root == .modal("A"))
    }

    @Test @MainActor
    func secondModalWithoutReplacementIsRejectedAtomically() {
        let router = IRouter<TestRoute>(root: .home)
        router.sheet(.modal("A"))
        let originalID = router.modalContext?.id

        let outcome = router.sheet(.modal("B"))

        #expect(outcome == .rejected(.modalAlreadyPresented(
            current: .init(route: .modal("A"), presentation: .sheet)
        )))
        #expect(router.modalContext?.id == originalID)
        #expect(router.modalContext?.route == .modal("A"))
    }

    @Test @MainActor
    func blockedDismissPresentedRequestLeavesModalUntouched() {
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, _ in route == .settings ? .block : .allow },
        ])
        router.sheet(.modal("A"))
        let originalID = router.modalContext?.id

        let outcome = router.push(.settings, options: [.dismissPresented])

        #expect(outcome == .blocked(.init(route: .settings, presentation: .push)))
        #expect(router.modalContext?.id == originalID)
        #expect(router.path.isEmpty)
    }

    @Test @MainActor
    func replacementCreatesNewDesiredContext() {
        let router = IRouter<TestRoute>(root: .home)
        router.sheet(.modal("A"))
        let originalID = router.modalContext?.id

        let outcome = router.sheet(.modal("B"), options: [.dismissPresented])

        #expect(outcome == .committed(.init(route: .modal("B"), presentation: .sheet)))
        #expect(router.modalContext?.id != originalID)
        #expect(router.modalContext?.route == .modal("B"))
    }

    @Test @MainActor
    func redirectCommitsFinalModalAndCarriesOptions() {
        let router = IRouter<TestRoute>(root: .home, filters: [
            IRouterFilter { route, _ in
                route == .settings ? .redirect(.login, .sheet) : .allow
            },
        ])
        router.sheet(.modal("A"))

        let outcome = router.push(
            .settings,
            options: [.dismissPresented]
        )

        #expect(outcome == .committed(.init(route: .login, presentation: .sheet)))
        #expect(router.modalContext?.route == .login)
        #expect(router.modalContext?.style == .sheet)
        #expect(router.path.isEmpty)
    }

    #if os(macOS)
    @Test @MainActor
    func dynamicFullScreenCoverIsRejectedOnMacOS() {
        let router = IRouter<TestRoute>(root: .home)

        let outcome = router.navigate(
            to: .modal("cover"),
            as: .fullScreenCover
        )

        #expect(outcome == .rejected(.unsupportedPresentation(.fullScreenCover)))
        #expect(router.modalContext == nil)
    }
    #else
    @Test @MainActor
    func fullScreenCoverCreatesTypedContextOniOS() {
        let router = IRouter<TestRoute>(root: .home)

        let outcome = router.fullScreenCover(.modal("cover"))

        #expect(outcome == .committed(.init(
            route: .modal("cover"),
            presentation: .fullScreenCover
        )))
        #expect(router.modalContext?.style == .fullScreenCover)
    }
    #endif
}

@Suite("Hierarchical dismissal")
struct IRouterDismissalTests {
    @Test @MainActor
    func childDismissPopsBeforeClosingParentModal() {
        let parent = IRouter<TestRoute>(root: .home)
        parent.sheet(.modal("A"))
        let child = parent.modalContext!.childRouter
        child.push(.detail(1))

        #expect(child.dismiss() == .popped)
        #expect(parent.modalContext != nil)
        #expect(child.path.isEmpty)
        #expect(child.dismiss() == .dismissedFromParent)
        #expect(parent.modalContext == nil)
    }

    @Test @MainActor
    func staleChildCannotDismissReplacement() {
        let parent = IRouter<TestRoute>(root: .home)
        parent.sheet(.modal("A"))
        let staleChild = parent.modalContext!.childRouter
        parent.sheet(.modal("B"), options: [.dismissPresented])
        let replacementID = parent.modalContext!.id

        #expect(staleChild.dismiss() == .unchanged)
        #expect(parent.modalContext?.id == replacementID)
        #expect(parent.modalContext?.route == .modal("B"))
    }

    @Test @MainActor
    func nestedDismissRemovesExactlyOneVisibleLevel() {
        let root = IRouter<TestRoute>(root: .home)
        root.sheet(.modal("level1"))
        let level1 = root.modalContext!.childRouter
        level1.sheet(.modal("level2"))
        let level2 = level1.modalContext!.childRouter

        #expect(level2.dismiss() == .dismissedFromParent)
        #expect(level1.modalContext == nil)
        #expect(root.modalContext != nil)
        #expect(level1.dismiss() == .dismissedFromParent)
        #expect(root.modalContext == nil)
    }
}
