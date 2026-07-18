//
//  IRouterContext.swift
//  IRouter
//
//  Created by ibabyblue on 2026/05/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import Foundation

/// Describes one modal and owns the router for navigation inside that modal.
@MainActor
public final class IRouterContext<Route: Hashable & Sendable>: Identifiable {
    /// The identity used to reject stale presentation and dismissal callbacks.
    public let id: UUID
    /// The route rendered at the modal child router's root.
    public let route: Route
    /// The sheet or full-screen presentation style.
    public let style: IRouterModalStyle
    /// The router that owns stack and nested-modal state inside this modal.
    public let childRouter: IRouter<Route>

    /// Creates a modal context and its inherited child router.
    ///
    /// - Parameters:
    ///   - route: The route rendered by the modal.
    ///   - style: The modal's presentation style.
    ///   - filters: The filter chain inherited by the child router.
    ///   - parent: The router that owns this direct modal.
    init(
        route: Route,
        style: IRouterModalStyle,
        filters: [IRouterFilter<Route>],
        parent: IRouter<Route>
    ) {
        let id = UUID()
        self.id = id
        self.route = route
        self.style = style
        self.childRouter = IRouter(
            root: route,
            filters: filters,
            dismissFromParent: { [weak parent] in
                parent?.dismissModal(id: id) ?? false
            }
        )
    }
}
