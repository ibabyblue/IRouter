import Foundation

/// The stack or modal presentation requested for a route.
public enum IRouterPresentation: Hashable, Sendable {
    /// Appends the route to the current router's stack.
    case push
    /// Presents the route as the current router's direct sheet.
    case sheet
    /// Presents the route as the current router's direct full-screen cover.
    case fullScreenCover
}

/// The modal styles stored by a committed modal context.
public enum IRouterModalStyle: Hashable, Sendable {
    /// A sheet presentation.
    case sheet
    /// A full-screen-cover presentation.
    case fullScreenCover

    /// The public navigation presentation represented by this modal style.
    var presentation: IRouterPresentation {
        switch self {
        case .sheet: .sheet
        case .fullScreenCover: .fullScreenCover
        }
    }
}

/// A route paired with the presentation resolved for one transaction step.
public struct IRouterDestination<Route: Hashable & Sendable>: Hashable, Sendable {
    /// The typed route to render.
    public let route: Route
    /// The stack or modal presentation for the route.
    public let presentation: IRouterPresentation

    /// Creates a typed destination.
    ///
    /// - Parameters:
    ///   - route: The route to render.
    ///   - presentation: The requested presentation for that route.
    public init(route: Route, presentation: IRouterPresentation) {
        self.route = route
        self.presentation = presentation
    }
}

/// Options applied to the final destination after redirect resolution.
public struct IRouterNavigationOptions: OptionSet, Hashable, Sendable {
    /// The option-set bit storage.
    public let rawValue: Int

    /// Creates an option set from its raw bits.
    ///
    /// - Parameter rawValue: The bit mask representing enabled options.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Avoids appending a final push that equals the current top route.
    public static let deduplicateTop = Self(rawValue: 1 << 0)
    /// Replaces a direct modal for modal navigation or dismisses it before a push.
    public static let dismissPresented = Self(rawValue: 1 << 1)
}

/// A reason a resolved navigation transaction could not commit.
public enum IRouterNavigationFailure<Route: Hashable & Sendable>: Hashable, Sendable {
    /// Redirect resolution revisited a route-presentation pair.
    case redirectCycle(chain: [IRouterDestination<Route>])
    /// Redirect resolution attempted more steps than the router permits.
    case redirectLimitExceeded(
        chain: [IRouterDestination<Route>],
        limit: Int
    )
    /// The router already owns a direct modal and replacement was not requested.
    case modalAlreadyPresented(current: IRouterDestination<Route>)
    /// The resolved presentation is unavailable on the current platform.
    case unsupportedPresentation(IRouterPresentation)
}

/// The complete result of one navigation transaction.
public enum IRouterNavigationOutcome<Route: Hashable & Sendable>: Hashable, Sendable {
    /// The final destination was atomically applied.
    case committed(IRouterDestination<Route>)
    /// A filter blocked the final attempted destination without mutation.
    case blocked(IRouterDestination<Route>)
    /// A final push matched the stack top and left state unchanged.
    case deduplicated(IRouterDestination<Route>)
    /// A routing invariant or platform rule rejected the transaction without mutation.
    case rejected(IRouterNavigationFailure<Route>)
}

/// The first action performed by hierarchical router dismissal.
public enum IRouterDismissOutcome: Hashable, Sendable {
    /// Removed the receiver's directly presented modal.
    case dismissedPresentedModal
    /// Removed the receiver's top pushed route.
    case popped
    /// Removed the parent modal that owns this child router.
    case dismissedFromParent
    /// No modal or pushed route was available to dismiss.
    case unchanged
}
