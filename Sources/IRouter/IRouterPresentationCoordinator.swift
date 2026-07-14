//
//  IRouterPresentationCoordinator.swift
//  IRouter
//
//  Created by ibabyblue on 2026/07/14.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import Foundation
import Observation

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

    func bindingDidDismiss(
        style: IRouterModalStyle,
        router: IRouter<Route>
    ) {
        guard dismissing == nil,
              let presentedContext,
              presentedContext.style == style else { return }
        dismissing = (presentedContext.id, style)
        pendingContext = nil
        self.presentedContext = nil
        visibleID = nil
        router.modalDidDismiss(id: presentedContext.id)
    }

    func presentationDidDismiss(style: IRouterModalStyle) {
        guard dismissing?.style == style else { return }
        dismissing = nil
        presentedContext = pendingContext
        pendingContext = nil
        visibleID = nil
    }
}
