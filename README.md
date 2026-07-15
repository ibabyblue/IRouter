# IRouter

IRouter is a SwiftUI router for typed stack and modal navigation.

## Requirements

| Toolchain or platform | Minimum |
|---|---|
| iOS | 17.0 |
| macOS | 14.0 |
| Swift | 6.0 |
| Xcode | 16.x |

## Installation

In Xcode, choose **File > Add Package Dependencies** and enter:

```text
https://github.com/ibabyblue/IRouter.git
```

Select version `0.1.0` or later. For a `Package.swift` dependency:

```swift
.package(
    url: "https://github.com/ibabyblue/IRouter.git",
    from: "0.1.0"
)
```

## Quick Start

Routes must conform to both `Hashable` and `Sendable`.

```swift
import IRouter
import SwiftUI

enum AppRoute: Hashable, Sendable {
    case home
    case detail(id: String)
    case settings
    case login
}

@MainActor
struct AppRoot: View {
    @State private var router = IRouter<AppRoute>(root: .home)

    var body: some View {
        IRouterView(router: router) { route in
            switch route {
            case .home:
                HomeView()
            case .detail(let id):
                Text("Detail \(id)")
            case .settings:
                Text("Settings")
            case .login:
                Text("Login")
            }
        }
    }
}

@MainActor
struct HomeView: View {
    @Environment(IRouter<AppRoute>.self) private var router

    var body: some View {
        VStack {
            Button("Detail") {
                router.push(.detail(id: "42"), options: [.deduplicateTop])
            }
            Button("Settings") {
                router.push(.settings, options: [.dismissPresented])
            }
        }
    }
}
```

`IRouter`, its observable state, navigation methods, and filter handlers are
main-actor isolated. An authentication filter can therefore read an
`@MainActor` model synchronously:

```swift
import IRouter
import Observation

@MainActor
@Observable
final class AuthModel {
    var isLoggedIn = false
}

@MainActor
func makeRouter(auth: AuthModel) -> IRouter<AppRoute> {
    IRouter(root: .home, filters: [
        IRouterFilter { route, _ in
            if case .settings = route, !auth.isLoggedIn {
                return .redirect(.login, .sheet)
            }
            return .allow
        },
    ])
}
```

Filters run in registration order. The first `.block` or `.redirect` stops
that pass; a redirect starts filtering again from the first filter.

## Public API

### Router and View

```swift
@MainActor
@Observable
public final class IRouter<Route: Hashable & Sendable> {
    public let root: Route
    public private(set) var path: [Route]
    public private(set) var modalContext: IRouterContext<Route>?

    public init(root: Route, filters: [IRouterFilter<Route>] = [])

    public func navigate(
        to route: Route,
        as presentation: IRouterPresentation,
        options: IRouterNavigationOptions = []
    ) -> IRouterNavigationOutcome<Route>

    public func push(
        _ route: Route,
        options: IRouterNavigationOptions = []
    ) -> IRouterNavigationOutcome<Route>

    public func sheet(
        _ route: Route,
        options: IRouterNavigationOptions = []
    ) -> IRouterNavigationOutcome<Route>

    @available(
        macOS,
        unavailable,
        message: "Full-screen cover is unavailable on macOS"
    )
    public func fullScreenCover(
        _ route: Route,
        options: IRouterNavigationOptions = []
    ) -> IRouterNavigationOutcome<Route>

    public func pop() -> Bool
    public func popToRoot() -> Bool
    public func dismiss() -> IRouterDismissOutcome
}

public struct IRouterView<
    Route: Hashable & Sendable,
    Content: View
>: View {
    public init(
        router: IRouter<Route>,
        @ViewBuilder destination: @escaping (Route) -> Content
    )
}
```

`path` and `modalContext` are read-only outside the package. Use router
navigation and pop methods to change them. `pop()` and `popToRoot()` return
`true` only when they mutate the stack.

### Presentation Values

```swift
public enum IRouterPresentation: Hashable, Sendable {
    case push
    case sheet
    case fullScreenCover
}

public enum IRouterModalStyle: Hashable, Sendable {
    case sheet
    case fullScreenCover
}

public struct IRouterDestination<
    Route: Hashable & Sendable
>: Hashable, Sendable {
    public let route: Route
    public let presentation: IRouterPresentation

    public init(route: Route, presentation: IRouterPresentation)
}

@MainActor
public final class IRouterContext<
    Route: Hashable & Sendable
>: Identifiable {
    public let id: UUID
    public let route: Route
    public let style: IRouterModalStyle
    public let childRouter: IRouter<Route>
}
```

Each router can own at most one direct modal. Its `modalContext` records the
modal route and `style`; the context's `childRouter` owns the modal's stack and
may in turn present one direct modal. Child routers inherit the complete filter
array from their parent.

### Options

```swift
public struct IRouterNavigationOptions: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int)

    public static let deduplicateTop: Self
    public static let dismissPresented: Self
}
```

| Option | Behavior |
|---|---|
| `.deduplicateTop` | For a final push destination, return `.deduplicated` instead of appending when the route already matches `path.last`. It has no effect on modal destinations. |
| `.dismissPresented` | For a committed final push, dismiss the router's direct modal before appending. For a final modal destination, replace the current direct modal. |

Options apply to the final route and presentation after all redirects, not to
the originally requested destination. A blocked or rejected transaction does
not dismiss an existing modal or otherwise partially mutate router state.
For a final push, `.deduplicateTop` is evaluated first; a `.deduplicated`
outcome leaves both the path and any direct modal unchanged.
Without `.dismissPresented`, presenting a second direct modal is rejected.

### Filters

```swift
public struct IRouterFilter<Route: Hashable & Sendable>: Sendable {
    public enum Result: Sendable {
        case allow
        case block
        case redirect(Route, IRouterPresentation)
    }

    public init(
        _ handler: @MainActor @Sendable @escaping
            (Route, IRouterPresentation) -> Result
    )
}
```

Redirects are resolved iteratively. Repeating a route-presentation pair is
rejected as a cycle. At most 32 redirects are followed; the 33rd redirect is
rejected with the full attempted chain and limit.

### Outcomes and Failures

```swift
public enum IRouterNavigationOutcome<
    Route: Hashable & Sendable
>: Hashable, Sendable {
    case committed(IRouterDestination<Route>)
    case blocked(IRouterDestination<Route>)
    case deduplicated(IRouterDestination<Route>)
    case rejected(IRouterNavigationFailure<Route>)
}

public enum IRouterNavigationFailure<
    Route: Hashable & Sendable
>: Hashable, Sendable {
    case redirectCycle(chain: [IRouterDestination<Route>])
    case redirectLimitExceeded(
        chain: [IRouterDestination<Route>],
        limit: Int
    )
    case modalAlreadyPresented(current: IRouterDestination<Route>)
    case unsupportedPresentation(IRouterPresentation)
}
```

| Outcome | Meaning |
|---|---|
| `.committed(destination)` | The final destination was applied. |
| `.blocked(destination)` | A filter blocked that destination; state is unchanged. |
| `.deduplicated(destination)` | A final push matched the current top route; state is unchanged. |
| `.rejected(failure)` | A routing invariant or platform rule rejected the transaction; state is unchanged. |

| Failure | Meaning |
|---|---|
| `.redirectCycle(chain:)` | Redirect resolution revisited a route-presentation pair. |
| `.redirectLimitExceeded(chain:limit:)` | Redirect resolution attempted more than 32 redirects. |
| `.modalAlreadyPresented(current:)` | The router already owns a direct modal and replacement was not requested. |
| `.unsupportedPresentation(presentation)` | The resolved presentation is unavailable on the current platform. |

### Dismissal

```swift
public enum IRouterDismissOutcome: Hashable, Sendable {
    case dismissedPresentedModal
    case popped
    case dismissedFromParent
    case unchanged
}
```

`dismiss()` performs exactly the first applicable step:

1. Remove the receiver's direct modal and return `.dismissedPresentedModal`.
2. Otherwise pop the receiver's top path element and return `.popped`.
3. Otherwise, for a child router, dismiss its owning parent modal and return `.dismissedFromParent`.
4. Otherwise leave state unchanged and return `.unchanged`.

A stale child router cannot dismiss a newer replacement modal.

## SwiftUI Behavior

`IRouterView` owns the `NavigationStack`, injects its router through the SwiftUI
environment, and presents the router's modal content with the context's child
router.

Modal replacement is serialized against SwiftUI presentation callbacks. If a
visible modal is replaced with `.dismissPresented`, the current presentation
finishes dismissing before the replacement is presented. Rapid replacements
coalesce to the latest requested context, and stale callbacks cannot clear a
newer presentation.

The stack binding accepts only path contraction that preserves the existing
prefix. System back buttons, system pop gestures, and interactive modal
dismissal therefore synchronize router state. Forward navigation through
`NavigationLink(value:)` is unsupported because it attempts to grow the bound
path outside the router transaction APIs; use `push`, `sheet`, or
`fullScreenCover` instead.

When switching between multiple router instances, pass the selected router
directly to `IRouterView`. Do not attach `.id(selection)` to `IRouterView` to
force recreation: that also tears down its `NavigationStack` during the
surrounding SwiftUI update and can reset or crash the active tab.

```swift
IRouterView(router: selectedRouter) { route in
    destination(for: route)
}
```

On macOS, `fullScreenCover(_:)` is unavailable at compile time. A dynamic call
through `navigate(to:as:options:)` with `.fullScreenCover` compiles but returns
`.rejected(.unsupportedPresentation(.fullScreenCover))` without mutation.

## Migration From 0.0.4

The state and navigation APIs are source-breaking. Apply these mappings:

| 0.0.4 | New API |
|---|---|
| `dedup: true` | `options: [.deduplicateTop]` |
| `flush: true` | `options: [.dismissPresented]` |
| `dismissAndPush(route)` | `push(route, options: [.dismissPresented])` |
| `sheetContext` / `coverContext` | Read-only `modalContext` and `style` |
| Direct `path` mutation | Router navigation and pop APIs |

Navigation now returns an `IRouterNavigationOutcome`, filters use a main-actor
handler, modal state is hierarchical, and redirect failures are reported
instead of recursing indefinitely.

## Demo

Open `demo/IRouterDemo.xcodeproj` to exercise stack transactions, filter
outcomes and redirect failures, modal replacement, nested child routers, and
independent router instances.

## License

IRouter is available under the MIT license. See [LICENSE](LICENSE).
