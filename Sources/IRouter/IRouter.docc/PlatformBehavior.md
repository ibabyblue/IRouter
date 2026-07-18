# Platform Behavior

Use one typed routing model while respecting iOS and macOS presentation capabilities.

## Supported systems

IRouter supports iOS 17 and macOS 14 or newer with Swift 6. The package exports one library product and has no external dependencies.

`NavigationStack`, sheets, filters, redirects, outcomes, child routers, and hierarchical dismissal share the same public semantics across supported platforms.

## Handle full-screen covers

The convenience ``IRouter/fullScreenCover(_:options:)`` API is unavailable on macOS at compile time.

A dynamic request through ``IRouter/navigate(to:as:options:)`` may still contain ``IRouterPresentation/fullScreenCover``. On macOS, the router returns ``IRouterNavigationFailure/unsupportedPresentation(_:)`` without mutating the path or modal context.

```swift
let outcome = router.navigate(
    to: .onboarding,
    as: selectedPresentation
)
```

Applications that choose presentation dynamically should handle the rejected outcome or avoid selecting full-screen cover on macOS.

## Keep destination builders portable

The same destination builder can serve iOS and macOS. Gate platform-specific controls at the call site while keeping route identity and transaction handling shared.

## Present Example navigation appropriately

The Example uses an iOS `TabView` and a macOS `NavigationSplitView` to expose the same five labs. This difference belongs to Example navigation, not to the router package API.
