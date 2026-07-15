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
        NavigationStack(path: pathBinding) {
            destination(router.root)
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
        .background {
            modalPresentationHost(for: .sheet)
        }
        #if !os(macOS)
        .background {
            modalPresentationHost(for: .fullScreenCover)
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

    @ViewBuilder
    private func modalPresentationHost(
        for style: IRouterModalStyle
    ) -> some View {
        IRouterModalPresentationHost(
            style: style,
            router: router,
            presentationCoordinator: presentationCoordinator,
            destination: destination
        )
    }
}

private struct IRouterModalPresentationHost<
    Route: Hashable & Sendable,
    Content: View
>: View {
    let style: IRouterModalStyle
    let router: IRouter<Route>
    let presentationCoordinator: IRouterPresentationCoordinator<Route>
    let destination: (Route) -> Content
    @State private var activeSessionID: UUID?

    @ViewBuilder
    var body: some View {
        switch style {
        case .sheet:
            presenterAnchor.sheet(
                item: modalBinding,
                onDismiss: presentationDidDismiss,
                content: modalContent
            )
        case .fullScreenCover:
            #if os(macOS)
            EmptyView()
            #else
            presenterAnchor.fullScreenCover(
                item: modalBinding,
                onDismiss: presentationDidDismiss,
                content: modalContent
            )
            #endif
        }
    }

    private var presenterAnchor: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }

    private var modalBinding: Binding<IRouterContext<Route>?> {
        Binding(
            get: { presentationCoordinator.context(for: style) },
            set: { context in
                guard context == nil,
                      let activeSessionID else { return }
                presentationCoordinator.bindingDidDismiss(
                    id: activeSessionID,
                    style: style,
                    router: router
                )
            }
        )
    }

    private func presentationDidDismiss() {
        guard let activeSessionID else { return }
        self.activeSessionID = nil
        presentationCoordinator.presentationDidDismiss(
            id: activeSessionID,
            style: style
        )
    }

    private func modalContent(
        context: IRouterContext<Route>
    ) -> some View {
        IRouterView(
            router: context.childRouter,
            destination: destination
        )
        .onAppear {
            guard presentationCoordinator.context(for: style)?.id == context.id else {
                return
            }
            activeSessionID = context.id
            presentationCoordinator.presentationDidAppear(id: context.id)
        }
    }
}
