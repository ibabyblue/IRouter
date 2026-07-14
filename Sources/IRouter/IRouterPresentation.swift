import Foundation

public enum IRouterPresentation: Hashable, Sendable {
    case push
    case sheet
    case fullScreenCover
}

public enum IRouterModalStyle: Hashable, Sendable {
    case sheet
    case fullScreenCover

    var presentation: IRouterPresentation {
        switch self {
        case .sheet: .sheet
        case .fullScreenCover: .fullScreenCover
        }
    }
}

public struct IRouterDestination<Route: Hashable & Sendable>: Hashable, Sendable {
    public let route: Route
    public let presentation: IRouterPresentation

    public init(route: Route, presentation: IRouterPresentation) {
        self.route = route
        self.presentation = presentation
    }
}

public struct IRouterNavigationOptions: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let deduplicateTop = Self(rawValue: 1 << 0)
    public static let dismissPresented = Self(rawValue: 1 << 1)
}

public enum IRouterNavigationFailure<Route: Hashable & Sendable>: Hashable, Sendable {
    case redirectCycle(chain: [IRouterDestination<Route>])
    case redirectLimitExceeded(
        chain: [IRouterDestination<Route>],
        limit: Int
    )
    case modalAlreadyPresented(current: IRouterDestination<Route>)
    case unsupportedPresentation(IRouterPresentation)
}

public enum IRouterNavigationOutcome<Route: Hashable & Sendable>: Hashable, Sendable {
    case committed(IRouterDestination<Route>)
    case blocked(IRouterDestination<Route>)
    case deduplicated(IRouterDestination<Route>)
    case rejected(IRouterNavigationFailure<Route>)
}

public enum IRouterDismissOutcome: Hashable, Sendable {
    case dismissedPresentedModal
    case popped
    case dismissedFromParent
    case unchanged
}
