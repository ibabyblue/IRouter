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
        coordinator.presentationDidDismiss(style: .sheet)
        #expect(coordinator.presentedContext?.id == contextB.id)
        #expect(coordinator.pendingContext == nil)
    }

    @Test @MainActor
    func rapidReplacementKeepsOnlyLatestPendingContext() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        coordinator.reconcile(desired: router.modalContext)
        coordinator.presentationDidAppear(id: router.modalContext!.id)

        router.sheet(.modal("B"), options: [.dismissPresented])
        coordinator.reconcile(desired: router.modalContext)
        router.sheet(.modal("C"), options: [.dismissPresented])
        coordinator.reconcile(desired: router.modalContext)

        #expect(coordinator.pendingContext?.route == .modal("C"))
        coordinator.presentationDidDismiss(style: .sheet)
        #expect(coordinator.presentedContext?.route == .modal("C"))
    }

    @Test @MainActor
    func interactiveDismissalClearsMatchingRouterContext() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        coordinator.reconcile(desired: router.modalContext)
        coordinator.presentationDidAppear(id: router.modalContext!.id)

        coordinator.bindingDidDismiss(style: .sheet, router: router)

        #expect(router.modalContext == nil)
        #expect(coordinator.presentedContext == nil)
        coordinator.presentationDidDismiss(style: .sheet)
        #expect(coordinator.presentedContext == nil)
    }

    @Test @MainActor
    func callbackForWrongStyleIsIgnored() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        coordinator.reconcile(desired: router.modalContext)
        coordinator.presentationDidAppear(id: router.modalContext!.id)
        router.sheet(.modal("B"), options: [.dismissPresented])
        coordinator.reconcile(desired: router.modalContext)

        coordinator.presentationDidDismiss(style: .fullScreenCover)

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
        coordinator.reconcile(desired: router.modalContext)
        coordinator.presentationDidAppear(id: router.modalContext!.id)
        router.sheet(.modal("B"), options: [.dismissPresented])
        coordinator.reconcile(desired: router.modalContext)

        #expect(router.dismiss() == .dismissedPresentedModal)
        coordinator.reconcile(desired: router.modalContext)
        coordinator.presentationDidDismiss(style: .sheet)

        #expect(coordinator.presentedContext == nil)
        #expect(coordinator.pendingContext == nil)
    }

    #if !os(macOS)
    @Test @MainActor
    func crossStyleReplacementWaitsForSheetDismissal() {
        let router = IRouter<TestRoute>(root: .home)
        let coordinator = IRouterPresentationCoordinator<TestRoute>()
        router.sheet(.modal("A"))
        coordinator.reconcile(desired: router.modalContext)
        coordinator.presentationDidAppear(id: router.modalContext!.id)

        router.fullScreenCover(
            .modal("B"),
            options: [.dismissPresented]
        )
        coordinator.reconcile(desired: router.modalContext)

        #expect(coordinator.context(for: .sheet) == nil)
        #expect(coordinator.context(for: .fullScreenCover) == nil)
        coordinator.presentationDidDismiss(style: .sheet)
        #expect(coordinator.context(for: .fullScreenCover)?.route == .modal("B"))
    }
    #endif
}
