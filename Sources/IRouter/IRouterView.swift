//
//  IRouterView.swift
//  IRouter
//
//  Created by ibabyblue on 2026/05/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import SwiftUI

/// Hosts a typed router in a `NavigationStack` and stable modal presenters.
public struct IRouterView<Route: Hashable & Sendable, Content: View>: View {
    /// The observable router that owns stack and modal state.
    @Bindable private var router: IRouter<Route>
    /// The coordinator that serializes modal state with SwiftUI callbacks.
    @State private var presentationCoordinator:
        IRouterPresentationCoordinator<Route>
    /// Builds view content for every route at this router level.
    private let destination: (Route) -> Content

    /// Creates a router host and destination builder.
    ///
    /// - Parameters:
    ///   - router: The router whose state drives this view hierarchy.
    ///   - destination: A builder that renders every route value.
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

    /// Builds the navigation stack, stable modal hosts, and router environment.
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

    /// Synchronizes system-driven stack contraction without permitting UI growth.
    private var pathBinding: Binding<[Route]> {
        Binding(
            get: { router.path },
            set: { _ = router.synchronizePathFromUI($0) }
        )
    }

    /// Builds the stable presentation host for one modal style.
    ///
    /// - Parameter style: The sheet or full-screen-cover style to host.
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

/// Owns one stable SwiftUI modal modifier for the lifetime of `IRouterView`.
private struct IRouterModalPresentationHost<
    Route: Hashable & Sendable,
    Content: View
>: View {
    /// The modal style handled by this host.
    let style: IRouterModalStyle
    /// The router updated after interactive dismissal.
    let router: IRouter<Route>
    /// The coordinator that supplies and serializes presentation context.
    let presentationCoordinator: IRouterPresentationCoordinator<Route>
    /// Builds route content recursively inside a modal child router.
    let destination: (Route) -> Content
    /// The context identity that has appeared in this host.
    @State private var activeSessionID: UUID?

    /// Applies the sheet or platform-available full-screen-cover modifier.
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

    /// A layout-neutral anchor that keeps the presentation modifier stable.
    private var presenterAnchor: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }

    /// Bridges coordinator context to the SwiftUI modal item binding.
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

    /// Completes dismissal for the active presentation session.
    private func presentationDidDismiss() {
        guard let activeSessionID else { return }
        self.activeSessionID = nil
        presentationCoordinator.presentationDidDismiss(
            id: activeSessionID,
            style: style
        )
    }

    /// Builds a recursive router host for one modal context.
    ///
    /// - Parameter context: The modal context and child router to render.
    /// - Returns: A view that reports a matching context appearance.
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
