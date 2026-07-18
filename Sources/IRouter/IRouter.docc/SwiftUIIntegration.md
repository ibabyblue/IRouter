# SwiftUI Integration

Keep router-owned state synchronized with system navigation and presentation behavior.

## Let the router own forward navigation

``IRouterView`` builds a `NavigationStack` from ``IRouter/path`` and registers the destination builder for route values. Use ``IRouter/push(_:options:)`` for forward navigation.

The stack binding accepts only path contraction that preserves the current prefix. System back buttons and pop gestures can therefore shorten router state, while `NavigationLink(value:)` cannot grow the bound path outside a router transaction.

## Read the current router from the environment

Every router level is injected by concrete type:

```swift
@Environment(IRouter<AppRoute>.self) private var router
```

Modal content receives its context's child router, not the parent router. This makes dismissal and nested navigation operate at the visible hierarchy level.

## Preserve stable modal hosts

`IRouterView` attaches one stable sheet host and, where supported, one stable full-screen-cover host for its lifetime. Replacing their binding context rather than recreating the host preserves native presentation and dismissal animations.

Presentation coordination distinguishes:

- The context supplied to SwiftUI.
- The visible context identity.
- The context currently dismissing.
- The latest pending replacement.

These states serialize replacement and reject stale callbacks without leaking coordinator details into public API.

## Switch between router instances

Pass the selected router directly to one `IRouterView`:

```swift
IRouterView(router: selectedRouter) { route in
    destination(for: route)
}
```

Do not attach `.id(selection)` to force recreation. Recreating the router host also tears down its `NavigationStack` during the surrounding SwiftUI update and may reset or destabilize the selected router state.

## Respond to system dismissal

Interactive modal dismissal clears only the matching router context. System stack contraction updates the path only when the new value is a shorter prefix. Programmatic state remains protected by the same transactional invariants as button-driven navigation.
