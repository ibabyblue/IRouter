//
//  IRouterPresentationCoordinator.swift
//  IRouter
//
//  Created by ibabyblue on 2026/07/14.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import Foundation
import Observation

struct IRouterPresentationSession: Hashable, Sendable, Identifiable {
    let id: UUID
    let style: IRouterModalStyle
}

@MainActor
@Observable
final class IRouterPresentationCoordinator<Route: Hashable & Sendable> {
    private(set) var presentedContext: IRouterContext<Route>?
    private(set) var pendingContext: IRouterContext<Route>?
    private var visibleID: UUID?
    private var dismissing: (id: UUID, style: IRouterModalStyle)?

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

    func presentationDidAppear(id: UUID) {
        guard dismissing == nil,
              presentedContext?.id == id else { return }
        visibleID = id
    }

    func context(for style: IRouterModalStyle) -> IRouterContext<Route>? {
        presentedContext?.style == style ? presentedContext : nil
    }

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

    func presentationID(for style: IRouterModalStyle) -> UUID? {
        presentationSession(for: style)?.id
    }

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

    func presentationDidDismiss(id: UUID, style: IRouterModalStyle) {
        guard dismissing?.id == id,
              dismissing?.style == style else { return }
        dismissing = nil
        presentedContext = pendingContext
        pendingContext = nil
        visibleID = nil
    }
}
