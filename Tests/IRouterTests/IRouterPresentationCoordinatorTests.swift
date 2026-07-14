import Testing
@testable import IRouter

@Suite("Presentation coordinator")
struct IRouterPresentationCoordinatorTests {
    @Test @MainActor
    func replacementWaitsForCurrentDismissal() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        let contextA = router.modalContext!
        coordinator.reconcile(desired: contextA)
        coordinator.presentationDidAppear(id: contextA.id)

        router.sheet(.modal("B"), options: [.dismissPresented])
        let contextB = router.modalContext!
        coordinator.reconcile(desired: contextB)

        #expect(coordinator.presentedContext == nil)
        #expect(coordinator.pendingContext?.id == contextB.id)
        coordinator.presentationDidDismiss(id: contextA.id, style: .sheet)
        #expect(coordinator.presentedContext?.id == contextB.id)
        #expect(coordinator.pendingContext == nil)
    }

    @Test @MainActor
    func rapidReplacementKeepsOnlyLatestPendingContext() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        let contextA = router.modalContext!
        coordinator.reconcile(desired: contextA)
        coordinator.presentationDidAppear(id: contextA.id)

        router.sheet(.modal("B"), options: [.dismissPresented])
        coordinator.reconcile(desired: router.modalContext)
        router.sheet(.modal("C"), options: [.dismissPresented])
        coordinator.reconcile(desired: router.modalContext)

        #expect(coordinator.pendingContext?.route == .modal("C"))
        coordinator.presentationDidDismiss(id: contextA.id, style: .sheet)
        #expect(coordinator.presentedContext?.route == .modal("C"))
    }

    @Test @MainActor
    func staleDismissCallbackCannotCompleteNewerDismissal() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        let contextA = router.modalContext!
        coordinator.reconcile(desired: contextA)
        coordinator.presentationDidAppear(id: contextA.id)
        #expect(coordinator.presentationID(for: .sheet) == contextA.id)

        router.sheet(.modal("B"), options: [.dismissPresented])
        let contextB = router.modalContext!
        coordinator.reconcile(desired: contextB)
        #expect(coordinator.presentationID(for: .sheet) == contextA.id)
        coordinator.presentationDidDismiss(id: contextA.id, style: .sheet)
        #expect(coordinator.presentationID(for: .sheet) == contextB.id)
        coordinator.presentationDidAppear(id: contextB.id)

        router.sheet(.modal("C"), options: [.dismissPresented])
        let contextC = router.modalContext!
        coordinator.reconcile(desired: contextC)
        coordinator.presentationDidDismiss(id: contextA.id, style: .sheet)

        #expect(coordinator.presentedContext == nil)
        #expect(coordinator.pendingContext?.id == contextC.id)
        coordinator.presentationDidDismiss(id: contextB.id, style: .sheet)
        #expect(coordinator.presentedContext?.id == contextC.id)
    }

    @Test @MainActor
    func interactiveDismissalClearsMatchingRouterContext() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        let contextA = router.modalContext!
        coordinator.reconcile(desired: contextA)
        coordinator.presentationDidAppear(id: contextA.id)

        coordinator.bindingDidDismiss(
            id: contextA.id,
            style: .sheet,
            router: router
        )

        #expect(router.modalContext == nil)
        #expect(coordinator.presentedContext == nil)
        coordinator.presentationDidDismiss(id: contextA.id, style: .sheet)
        #expect(coordinator.presentedContext == nil)
    }

    @Test @MainActor
    func staleBindingDismissalCannotClearPromotedPresentation() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        let contextA = router.modalContext!
        coordinator.reconcile(desired: contextA)
        coordinator.presentationDidAppear(id: contextA.id)

        router.sheet(.modal("B"), options: [.dismissPresented])
        let contextB = router.modalContext!
        coordinator.reconcile(desired: contextB)
        coordinator.presentationDidDismiss(id: contextA.id, style: .sheet)

        coordinator.bindingDidDismiss(
            id: contextA.id,
            style: .sheet,
            router: router
        )

        #expect(router.modalContext?.id == contextB.id)
        #expect(coordinator.presentedContext?.id == contextB.id)
    }

    @Test @MainActor
    func callbackForWrongStyleIsIgnored() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        let contextA = router.modalContext!
        coordinator.reconcile(desired: contextA)
        coordinator.presentationDidAppear(id: contextA.id)
        router.sheet(.modal("B"), options: [.dismissPresented])
        coordinator.reconcile(desired: router.modalContext)

        coordinator.presentationDidDismiss(
            id: contextA.id,
            style: .fullScreenCover
        )

        #expect(coordinator.presentedContext == nil)
        #expect(coordinator.pendingContext?.route == .modal("B"))
    }

    @Test @MainActor
    func replacementBeforeAppearanceDoesNotWaitForDismissCallback() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        coordinator.reconcile(desired: router.modalContext)

        router.sheet(.modal("B"), options: [.dismissPresented])
        coordinator.reconcile(desired: router.modalContext)

        #expect(coordinator.presentedContext?.route == .modal("B"))
        #expect(coordinator.pendingContext == nil)
    }

    @Test @MainActor
    func pendingPresentationCanBeCancelled() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        let contextA = router.modalContext!
        coordinator.reconcile(desired: contextA)
        coordinator.presentationDidAppear(id: contextA.id)
        router.sheet(.modal("B"), options: [.dismissPresented])
        coordinator.reconcile(desired: router.modalContext)

        #expect(router.dismiss() == .dismissedPresentedModal)
        coordinator.reconcile(desired: router.modalContext)
        coordinator.presentationDidDismiss(id: contextA.id, style: .sheet)

        #expect(coordinator.presentedContext == nil)
        #expect(coordinator.pendingContext == nil)
    }

    #if !os(macOS)
    @Test @MainActor
    func crossStyleReplacementWaitsForSheetDismissal() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        let contextA = router.modalContext!
        coordinator.reconcile(desired: contextA)
        coordinator.presentationDidAppear(id: contextA.id)

        router.fullScreenCover(
            .modal("B"),
            options: [.dismissPresented]
        )
        coordinator.reconcile(desired: router.modalContext)

        #expect(coordinator.context(for: .sheet) == nil)
        #expect(coordinator.context(for: .fullScreenCover) == nil)
        coordinator.presentationDidDismiss(id: contextA.id, style: .sheet)
        #expect(coordinator.context(for: .fullScreenCover)?.route == .modal("B"))
    }
    #endif
}
