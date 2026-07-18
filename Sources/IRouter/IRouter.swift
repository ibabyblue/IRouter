//
//  IRouter.swift
//  IRouter
//
//  Created by ibabyblue on 2026/05/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import Foundation
import Observation

/// Owns one typed navigation stack and at most one directly presented modal.
///
/// Navigation resolves filters before committing one atomic state mutation.
/// All observable state and operations are isolated to the main actor.
@MainActor
@Observable
public final class IRouter<Route: Hashable & Sendable> {
    /// The maximum number of redirects a single navigation transaction may follow.
    static var redirectLimit: Int { 32 }

    /// The destination rendered at the root of this router level.
    public let root: Route
    /// The pushed destinations above ``root`` in navigation order.
    public private(set) var path: [Route] = []
    /// The single modal directly owned by this router, if one is presented.
    public private(set) var modalContext: IRouterContext<Route>?

    /// The ordered filters inherited by modal child routers.
    private let filters: [IRouterFilter<Route>]
    /// Dismisses the parent-owned modal containing this child router.
    private let dismissFromParent: (@MainActor @Sendable () -> Bool)?

    /// Creates a root router with an optional ordered filter chain.
    ///
    /// - Parameters:
    ///   - root: The destination rendered at the base of the navigation stack.
    ///   - filters: Filters evaluated in registration order for every transaction.
    public init(root: Route, filters: [IRouterFilter<Route>] = []) {
        self.root = root
        self.filters = filters
        self.dismissFromParent = nil
    }

    /// Creates a child router that may dismiss its parent-owned modal.
    ///
    /// - Parameters:
    ///   - root: The modal destination rendered at this child level.
    ///   - filters: The complete filter chain inherited from the parent router.
    ///   - dismissFromParent: A closure that removes the matching parent modal.
    init(
        root: Route,
        filters: [IRouterFilter<Route>],
        dismissFromParent: @escaping @MainActor @Sendable () -> Bool
    ) {
        self.root = root
        self.filters = filters
        self.dismissFromParent = dismissFromParent
    }

    /// Resolves filters and atomically applies a typed navigation request.
    ///
    /// Redirects restart filtering from the first filter. Repeated destinations
    /// and transactions exceeding `redirectLimit` are rejected without mutation.
    ///
    /// - Parameters:
    ///   - route: The initially requested route.
    ///   - presentation: The initially requested stack or modal presentation.
    ///   - options: Options applied only to the final resolved destination.
    /// - Returns: The committed, blocked, deduplicated, or rejected outcome.
    @discardableResult
    public func navigate(
        to route: Route,
        as presentation: IRouterPresentation,
        options: IRouterNavigationOptions = []
    ) -> IRouterNavigationOutcome<Route> {
        var current = IRouterDestination(route: route, presentation: presentation)
        var visited: Set<IRouterDestination<Route>> = []
        var chain: [IRouterDestination<Route>] = []
        var redirectCount = 0

        while true {
            guard visited.insert(current).inserted else {
                return .rejected(.redirectCycle(chain: chain + [current]))
            }
            chain.append(current)

            switch runFilters(for: current) {
            case .allow:
                return commit(current, options: options)
            case .block:
                return .blocked(current)
            case .redirect(let route, let presentation):
                let redirected = IRouterDestination(
                    route: route,
                    presentation: presentation
                )
                guard redirectCount < Self.redirectLimit else {
                    return .rejected(.redirectLimitExceeded(
                        chain: chain + [redirected],
                        limit: Self.redirectLimit
                    ))
                }
                redirectCount += 1
                current = redirected
            }
        }
    }

    /// Pushes a route after resolving the filter chain.
    ///
    /// - Parameters:
    ///   - route: The route to append to the stack.
    ///   - options: Options applied to the final resolved destination.
    /// - Returns: The navigation transaction outcome.
    @discardableResult
    public func push(
        _ route: Route,
        options: IRouterNavigationOptions = []
    ) -> IRouterNavigationOutcome<Route> {
        navigate(to: route, as: .push, options: options)
    }

    /// Presents a route in a sheet after resolving the filter chain.
    ///
    /// - Parameters:
    ///   - route: The route to present.
    ///   - options: Options applied to the final resolved destination.
    /// - Returns: The navigation transaction outcome.
    @discardableResult
    public func sheet(
        _ route: Route,
        options: IRouterNavigationOptions = []
    ) -> IRouterNavigationOutcome<Route> {
        navigate(to: route, as: .sheet, options: options)
    }

    /// Presents a route in a full-screen cover after resolving the filter chain.
    ///
    /// - Parameters:
    ///   - route: The route to present.
    ///   - options: Options applied to the final resolved destination.
    /// - Returns: The navigation transaction outcome.
    @available(macOS, unavailable, message: "Full-screen cover is unavailable on macOS")
    @discardableResult
    public func fullScreenCover(
        _ route: Route,
        options: IRouterNavigationOptions = []
    ) -> IRouterNavigationOutcome<Route> {
        navigate(to: route, as: .fullScreenCover, options: options)
    }

    /// Removes the top pushed route when the stack is nonempty.
    ///
    /// - Returns: `true` when the path changed; otherwise `false`.
    @discardableResult
    public func pop() -> Bool {
        guard !path.isEmpty else { return false }
        path.removeLast()
        return true
    }

    /// Removes every pushed route when the stack is nonempty.
    ///
    /// - Returns: `true` when the path changed; otherwise `false`.
    @discardableResult
    public func popToRoot() -> Bool {
        guard !path.isEmpty else { return false }
        path.removeAll()
        return true
    }

    /// Performs the first available hierarchical dismissal action.
    ///
    /// A direct modal is removed first, followed by a stack pop, followed by
    /// dismissal of this child router's owning parent modal.
    ///
    /// - Returns: The action performed, or ``IRouterDismissOutcome/unchanged``.
    @discardableResult
    public func dismiss() -> IRouterDismissOutcome {
        if modalContext != nil {
            modalContext = nil
            return .dismissedPresentedModal
        }
        if pop() {
            return .popped
        }
        if dismissFromParent?() == true {
            return .dismissedFromParent
        }
        return .unchanged
    }

    /// Removes the direct modal only when its identity matches the supplied session.
    ///
    /// - Parameter id: The modal context identity expected by the caller.
    /// - Returns: `true` when the matching modal was removed.
    @discardableResult
    func dismissModal(id: UUID) -> Bool {
        guard modalContext?.id == id else { return false }
        modalContext = nil
        return true
    }

    /// Synchronizes an interactive modal dismissal reported by SwiftUI.
    ///
    /// - Parameter id: The context identity belonging to the dismissed presentation.
    func modalDidDismiss(id: UUID) {
        _ = dismissModal(id: id)
    }

    /// Accepts a UI-originated path update only when it contracts the current prefix.
    ///
    /// - Parameter newPath: The path reported by `NavigationStack`.
    /// - Returns: `true` when a valid contraction changed router state.
    @discardableResult
    func synchronizePathFromUI(_ newPath: [Route]) -> Bool {
        guard newPath != path,
              newPath.count < path.count,
              path.starts(with: newPath) else { return false }
        path = newPath
        return true
    }

    /// Applies one already-filtered destination as an atomic state mutation.
    ///
    /// - Parameters:
    ///   - destination: The final route and presentation selected by filtering.
    ///   - options: Options evaluated against that final destination.
    /// - Returns: The resulting navigation outcome.
    private func commit(
        _ destination: IRouterDestination<Route>,
        options: IRouterNavigationOptions
    ) -> IRouterNavigationOutcome<Route> {
        #if os(macOS)
        if destination.presentation == .fullScreenCover {
            return .rejected(.unsupportedPresentation(.fullScreenCover))
        }
        #endif

        switch destination.presentation {
        case .push:
            if options.contains(.deduplicateTop), path.last == destination.route {
                return .deduplicated(destination)
            }
            if options.contains(.dismissPresented) {
                modalContext = nil
            }
            path.append(destination.route)
            return .committed(destination)

        case .sheet:
            return commitModal(destination, style: .sheet, options: options)

        case .fullScreenCover:
            return commitModal(
                destination,
                style: .fullScreenCover,
                options: options
            )
        }
    }

    /// Creates or replaces the router's direct modal when permitted by options.
    ///
    /// - Parameters:
    ///   - destination: The final modal destination.
    ///   - style: The modal presentation style owned by the new context.
    ///   - options: Options controlling replacement of an existing direct modal.
    /// - Returns: A committed outcome or an atomic modal-already-presented rejection.
    private func commitModal(
        _ destination: IRouterDestination<Route>,
        style: IRouterModalStyle,
        options: IRouterNavigationOptions
    ) -> IRouterNavigationOutcome<Route> {
        if let current = modalContext,
           !options.contains(.dismissPresented) {
            return .rejected(.modalAlreadyPresented(
                current: IRouterDestination(
                    route: current.route,
                    presentation: current.style.presentation
                )
            ))
        }

        modalContext = IRouterContext(
            route: destination.route,
            style: style,
            filters: filters,
            parent: self
        )
        return .committed(destination)
    }

    /// Evaluates filters in order until one blocks or redirects the destination.
    ///
    /// - Parameter destination: The destination for the current resolution pass.
    /// - Returns: The first non-allow result, or `.allow` after every filter allows.
    private func runFilters(
        for destination: IRouterDestination<Route>
    ) -> IRouterFilter<Route>.Result {
        for filter in filters {
            let result = filter.handler(
                destination.route,
                destination.presentation
            )
            if case .allow = result {
                continue
            }
            return result
        }
        return .allow
    }
}
