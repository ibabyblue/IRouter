//
//  IRouter.swift
//  IRouter
//
//  Created by ibabyblue on 2026/05/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import Foundation
import Observation

@MainActor
@Observable
public final class IRouter<Route: Hashable & Sendable> {
    static var redirectLimit: Int { 32 }

    public let root: Route
    public private(set) var path: [Route] = []
    public private(set) var modalContext: IRouterContext<Route>?

    private let filters: [IRouterFilter<Route>]
    private let dismissFromParent: (@MainActor @Sendable () -> Bool)?

    public init(root: Route, filters: [IRouterFilter<Route>] = []) {
        self.root = root
        self.filters = filters
        self.dismissFromParent = nil
    }

    init(
        root: Route,
        filters: [IRouterFilter<Route>],
        dismissFromParent: @escaping @MainActor @Sendable () -> Bool
    ) {
        self.root = root
        self.filters = filters
        self.dismissFromParent = dismissFromParent
    }

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

    @discardableResult
    public func push(
        _ route: Route,
        options: IRouterNavigationOptions = []
    ) -> IRouterNavigationOutcome<Route> {
        navigate(to: route, as: .push, options: options)
    }

    @discardableResult
    public func sheet(
        _ route: Route,
        options: IRouterNavigationOptions = []
    ) -> IRouterNavigationOutcome<Route> {
        navigate(to: route, as: .sheet, options: options)
    }

    @available(macOS, unavailable, message: "Full-screen cover is unavailable on macOS")
    @discardableResult
    public func fullScreenCover(
        _ route: Route,
        options: IRouterNavigationOptions = []
    ) -> IRouterNavigationOutcome<Route> {
        navigate(to: route, as: .fullScreenCover, options: options)
    }

    @discardableResult
    public func pop() -> Bool {
        guard !path.isEmpty else { return false }
        path.removeLast()
        return true
    }

    @discardableResult
    public func popToRoot() -> Bool {
        guard !path.isEmpty else { return false }
        path.removeAll()
        return true
    }

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

    @discardableResult
    func dismissModal(id: UUID) -> Bool {
        guard modalContext?.id == id else { return false }
        modalContext = nil
        return true
    }

    func modalDidDismiss(id: UUID) {
        _ = dismissModal(id: id)
    }

    @discardableResult
    func synchronizePathFromUI(_ newPath: [Route]) -> Bool {
        guard newPath != path,
              newPath.count < path.count,
              path.starts(with: newPath) else { return false }
        path = newPath
        return true
    }

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
