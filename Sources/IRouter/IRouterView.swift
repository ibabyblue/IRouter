//
//  IRouterView.swift
//  IRouter
//
//  Created by ibabyblue on 2026/05/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import SwiftUI

public struct IRouterView<Route: Hashable & Sendable, Content: View>: View {
    @Bindable private var router: IRouter<Route>
    private let destination: (Route) -> Content

    public init(
        router: IRouter<Route>,
        @ViewBuilder destination: @escaping (Route) -> Content
    ) {
        _router = Bindable(router)
        self.destination = destination
    }

    public var body: some View {
        NavigationStack(path: pathBinding) {
            destination(router.root)
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
        .environment(router)
    }

    private var pathBinding: Binding<[Route]> {
        Binding(
            get: { router.path },
            set: { _ = router.synchronizePathFromUI($0) }
        )
    }
}
