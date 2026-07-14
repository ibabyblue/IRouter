//
//  IRouterContext.swift
//  IRouter
//
//  Created by ibabyblue on 2026/05/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import Foundation

@MainActor
public final class IRouterContext<Route: Hashable & Sendable>: Identifiable {
    public let id: UUID
    public let route: Route
    public let style: IRouterModalStyle
    public let childRouter: IRouter<Route>

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
