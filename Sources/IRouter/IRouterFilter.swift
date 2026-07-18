//
//  IRouterFilter.swift
//  IRouter
//
//  Created by ibabyblue on 2026/05/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

/// Evaluates one route before a navigation transaction commits.
///
/// Filters run in registration order. The first block or redirect ends the
/// current pass, and redirected destinations restart from the first filter.
///
/// ```swift
/// IRouterFilter { route, presentation in
///     if case .profile = route, !Auth.isLoggedIn {
///         return .redirect(.login, .sheet)
///     }
///     return .allow
/// }
/// ```
public struct IRouterFilter<Route: Hashable & Sendable>: Sendable {

    /// A decision produced for one route and presentation pair.
    public enum Result: Sendable {
        /// Allows the next filter, or commits after the final filter.
        case allow
        /// Blocks the destination without mutating router state.
        case block
        /// Restarts filtering with another route and presentation.
        case redirect(Route, IRouterPresentation)
    }

    /// The main-actor closure evaluated by the owning router.
    let handler: @MainActor @Sendable (Route, IRouterPresentation) -> Result

    /// Creates a filter from a synchronous main-actor decision closure.
    ///
    /// - Parameter handler: The closure that allows, blocks, or redirects a destination.
    public init(
        _ handler: @MainActor @Sendable @escaping
            (Route, IRouterPresentation) -> Result
    ) {
        self.handler = handler
    }
}
