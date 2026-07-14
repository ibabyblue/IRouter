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
    @State private var presentationCoordinator:
        IRouterPresentationCoordinator<Route>
    private let destination: (Route) -> Content

    public init(
        router: IRouter<Route>,
        @ViewBuilder destination: @escaping (Route) -> Content
    ) {
        _router = Bindable(router)
        _presentationCoordinator = State(
            initialValue: IRouterPresentationCoordinator()
        )
        self.destination = destination
    }

    public var body: some View {
        let sheetPresentationID = presentationCoordinator.presentationID(
            for: .sheet
        )
        #if !os(macOS)
        let coverPresentationID = presentationCoordinator.presentationID(
            for: .fullScreenCover
        )
        #endif

        NavigationStack(path: pathBinding) {
            destination(router.root)
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
        .sheet(
            item: modalBinding(
                for: .sheet,
                presentationID: sheetPresentationID
            ),
            onDismiss: {
                guard let sheetPresentationID else { return }
                presentationCoordinator.presentationDidDismiss(
                    id: sheetPresentationID,
                    style: .sheet
                )
            }
        ) { context in
            IRouterView(
                router: context.childRouter,
                destination: destination
            )
            .onAppear {
                presentationCoordinator.presentationDidAppear(id: context.id)
            }
        }
        #if !os(macOS)
        .fullScreenCover(
            item: modalBinding(
                for: .fullScreenCover,
                presentationID: coverPresentationID
            ),
            onDismiss: {
                guard let coverPresentationID else { return }
                presentationCoordinator.presentationDidDismiss(
                    id: coverPresentationID,
                    style: .fullScreenCover
                )
            }
        ) { context in
            IRouterView(
                router: context.childRouter,
                destination: destination
            )
            .onAppear {
                presentationCoordinator.presentationDidAppear(id: context.id)
            }
        }
        #endif
        .onAppear {
            presentationCoordinator.reconcile(desired: router.modalContext)
        }
        .onChange(of: router.modalContext?.id) {
            presentationCoordinator.reconcile(desired: router.modalContext)
        }
        .environment(router)
    }

    private var pathBinding: Binding<[Route]> {
        Binding(
            get: { router.path },
            set: { _ = router.synchronizePathFromUI($0) }
        )
    }

    private func modalBinding(
        for style: IRouterModalStyle,
        presentationID: UUID?
    ) -> Binding<IRouterContext<Route>?> {
        Binding(
            get: { presentationCoordinator.context(for: style) },
            set: { context in
                guard context == nil,
                      let presentationID else { return }
                presentationCoordinator.bindingDidDismiss(
                    id: presentationID,
                    style: style,
                    router: router
                )
            }
        )
    }
}
