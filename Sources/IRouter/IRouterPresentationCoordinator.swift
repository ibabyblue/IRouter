//
//  IRouterPresentationCoordinator.swift
//  IRouter
//
//  Created by ibabyblue on 2026/07/14.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import Foundation
import Observation

/// A stable presentation identity retained while SwiftUI completes dismissal.
struct IRouterPresentationSession: Hashable, Sendable, Identifiable {
    /// The modal context identity associated with the session.
    let id: UUID
    /// The modal host that owns the session.
    let style: IRouterModalStyle
}

/// Serializes desired router modal state against asynchronous SwiftUI callbacks.
@MainActor
@Observable
final class IRouterPresentationCoordinator<Route: Hashable & Sendable> {
    /// The context currently supplied to a SwiftUI presentation binding.
    private(set) var presentedContext: IRouterContext<Route>?
    /// The latest desired context waiting for the visible modal to dismiss.
    private(set) var pendingContext: IRouterContext<Route>?
    /// The context identity whose modal content has appeared.
    private var visibleID: UUID?
    /// The identity and host style currently waiting for an on-dismiss callback.
    private var dismissing: (id: UUID, style: IRouterModalStyle)?

    /// Reconciles the latest router-owned modal with the presentation lifecycle.
    ///
    /// Visible replacement is serialized through dismissal, while replacement
    /// before appearance may update the presented binding immediately.
    ///
    /// - Parameter desired: The modal currently owned by the router.
    func reconcile(desired: IRouterContext<Route>?) {
        if dismissing != nil {
            pendingContext = desired
            return
        }

        guard presentedContext?.id != desired?.id else { return }
        guard let presentedContext else {
            self.presentedContext = desired
            return
        }

        guard visibleID == presentedContext.id else {
            self.presentedContext = desired
            pendingContext = nil
            return
        }

        dismissing = (presentedContext.id, presentedContext.style)
        pendingContext = desired
        self.presentedContext = nil
        visibleID = nil
    }

    /// Marks a matching presented context as visible.
    ///
    /// - Parameter id: The context identity reported by modal content appearance.
    func presentationDidAppear(id: UUID) {
        guard dismissing == nil,
              presentedContext?.id == id else { return }
        visibleID = id
    }

    /// Returns the presented context owned by one modal host style.
    ///
    /// - Parameter style: The sheet or full-screen host requesting its context.
    /// - Returns: The matching context, or `nil` when another host owns it.
    func context(for style: IRouterModalStyle) -> IRouterContext<Route>? {
        presentedContext?.style == style ? presentedContext : nil
    }

    /// Returns the stable identity exposed to a modal item binding.
    ///
    /// A dismissing session remains identifiable until its dismissal callback
    /// completes, preventing SwiftUI from skipping native dismissal animation.
    ///
    /// - Parameter style: The modal host requesting a session.
    /// - Returns: The matching active or dismissing session.
    func presentationSession(
        for style: IRouterModalStyle
    ) -> IRouterPresentationSession? {
        if let dismissing, dismissing.style == style {
            return IRouterPresentationSession(
                id: dismissing.id,
                style: dismissing.style
            )
        }
        guard let context = context(for: style) else { return nil }
        return IRouterPresentationSession(id: context.id, style: context.style)
    }

    /// Returns the presentation identity for one modal host style.
    ///
    /// - Parameter style: The modal host requesting an identity.
    /// - Returns: The matching context or dismissing-session identity.
    func presentationID(for style: IRouterModalStyle) -> UUID? {
        presentationSession(for: style)?.id
    }

    /// Handles a system-driven binding dismissal for the matching visible modal.
    ///
    /// - Parameters:
    ///   - id: The active presentation identity.
    ///   - style: The modal host reporting dismissal.
    ///   - router: The router whose matching modal context must be cleared.
    func bindingDidDismiss(
        id: UUID,
        style: IRouterModalStyle,
        router: IRouter<Route>
    ) {
        guard dismissing == nil,
              let presentedContext,
              presentedContext.id == id,
              presentedContext.style == style else { return }
        dismissing = (id, style)
        pendingContext = nil
        self.presentedContext = nil
        visibleID = nil
        router.modalDidDismiss(id: id)
    }

    /// Completes a serialized dismissal and promotes the latest pending context.
    ///
    /// - Parameters:
    ///   - id: The dismissed presentation identity.
    ///   - style: The host style that completed dismissal.
    func presentationDidDismiss(id: UUID, style: IRouterModalStyle) {
        guard dismissing?.id == id,
              dismissing?.style == style else { return }
        dismissing = nil
        presentedContext = pendingContext
        pendingContext = nil
        visibleID = nil
    }
}
