#if os(iOS)
import SwiftUI
import Testing
import UIKit
@testable import IRouter

@Suite("Presentation animations", .serialized)
@MainActor
struct IRouterPresentationAnimationTests {
    @Test
    func sheetPresentationUsesSystemAnimation() async throws {
        let isAnimated = try await presentedTransitionIsAnimated { router in
            router.sheet(.modal("A"))
        }
        #expect(isAnimated == true)
    }

    @Test
    func fullScreenCoverPresentationUsesSystemAnimation() async throws {
        let isAnimated = try await presentedTransitionIsAnimated { router in
            router.fullScreenCover(.modal("A"))
        }
        #expect(isAnimated == true)
    }

    private func presentedTransitionIsAnimated(
        present: (IRouter<TestRoute>) -> Void
    ) async throws -> Bool? {
        let router = IRouter<TestRoute>(root: .home)
        let hostingController = UIHostingController(
            rootView: IRouterView(router: router) { _ in
                Text("Destination")
            }
        )
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        await settleViewHierarchy()
        present(router)

        return try await presentedTransitionIsAnimated(from: hostingController)
    }

    private func settleViewHierarchy() async {
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(20))
    }

    private func presentedTransitionIsAnimated(
        from hostingController: UIViewController
    ) async throws -> Bool? {
        for _ in 0..<200 {
            if let presented = hostingController.presentedViewController {
                return presented.transitionCoordinator?.isAnimated
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        return nil
    }
}
#endif
