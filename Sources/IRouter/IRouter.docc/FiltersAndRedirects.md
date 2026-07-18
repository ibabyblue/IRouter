# Filters and Redirects

Apply synchronous main-actor navigation policy before a transaction commits.

## Register an ordered filter chain

Pass ``IRouterFilter`` values when creating a router:

```swift
@MainActor
@Observable
final class AuthModel {
    var isLoggedIn = false
}

@MainActor
func makeRouter(auth: AuthModel) -> IRouter<AppRoute> {
    IRouter(root: .home, filters: [
        IRouterFilter { route, presentation in
            if case .settings = route, !auth.isLoggedIn {
                return .redirect(.login, .sheet)
            }
            return .allow
        },
    ])
}
```

Router and filter execution are main-actor isolated, so a filter may synchronously inspect a main-actor application model. The closure remains `Sendable` for Swift 6 correctness.

## Understand one filter pass

Filters run in registration order:

- `allow` continues to the next filter.
- `block` returns a blocked outcome without mutation.
- `redirect(route, presentation)` stops the current pass and starts a new pass from the first filter.

The first block or redirect is terminal for that pass. A route commits only after every filter allows the same route-presentation pair.

## Keep redirects finite

IRouter resolves redirects iteratively instead of recursively. It records each ``IRouterDestination`` attempted by the transaction.

Revisiting the same route-presentation pair returns ``IRouterNavigationFailure/redirectCycle(chain:)`` with the attempted chain. This catches self redirects and multi-node cycles:

```swift
IRouterFilter { route, presentation in
    switch route {
    case .legacySettings:
        .redirect(.settings, presentation)
    default:
        .allow
    }
}
```

At most 32 redirects may be followed. The next redirect returns ``IRouterNavigationFailure/redirectLimitExceeded(chain:limit:)``. Both failure paths preserve the original router state.

## Apply options after redirects

Navigation options are carried through resolution and evaluated only against the final destination. For example, a request redirected from push to sheet uses modal replacement rules, while a request redirected from sheet to push uses stack deduplication rules.

This ordering keeps the transaction atomic: a blocked or rejected redirected destination cannot dismiss an existing modal or partially change the path.

## Inherit policy in modal levels

Every modal ``IRouterContext`` creates a child router with the parent's complete filter array. Nested stack and modal navigation therefore follows the same policy at every level.
