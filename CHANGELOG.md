# Changelog

## Unreleased

### Breaking

- Replaced independently mutable stack and modal state with a read-only `path`
  and one typed `modalContext` per router. Nested modal levels now belong to
  inherited child routers.
- Replaced navigation boolean parameters and convenience mutations with
  `IRouterNavigationOptions`, transactional entry points, structured outcomes,
  and explicit failure values.
- Main-actor isolated router state and filter handlers. Filter closures remain
  `Sendable` and can synchronously inspect main-actor application models.
- Added iterative redirect resolution, route-presentation cycle detection, and
  a 32-redirect limit. Options apply to the final redirected destination.
- Serialized SwiftUI modal dismissal and replacement. Rapid replacements retain
  only the latest requested presentation, and stale callbacks cannot clear it.
- Rebuilt the Demo around stack, filter, modal replacement, nested-router, and
  multiple-router regression scenarios on iOS and macOS.
- Expanded the test matrix for navigation values, stack contraction, filters,
  redirects, modal transactions, hierarchical dismissal, presentation
  serialization, and live Demo presentation flows.
