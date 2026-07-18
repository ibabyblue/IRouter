# Migrating from 0.0.4

Adopt the transactional state and navigation API introduced in IRouter 0.1.0 and documented for 0.2.0.

## Replace mutation flags with options

Use these source mappings:

| 0.0.4 | Transactional API |
| --- | --- |
| `dedup: true` | `options: [.deduplicateTop]` |
| `flush: true` | `options: [.dismissPresented]` |
| `dismissAndPush(route)` | `push(route, options: [.dismissPresented])` |
| `sheetContext` / `coverContext` | Read-only `modalContext` and `style` |
| Direct `path` mutation | Router navigation and pop APIs |

## Handle structured outcomes

Navigation methods now return ``IRouterNavigationOutcome`` instead of silently applying or ignoring work. Handle blocked policy, deduplication, and explicit rejection when callers need feedback.

```swift
let outcome = router.push(.settings, options: [.dismissPresented])

guard case .committed = outcome else {
    return
}
```

## Move filter access to the main actor

``IRouterFilter`` handlers are main-actor isolated and `Sendable`. Main-actor application state can be read synchronously without creating asynchronous navigation races.

Redirects now restart the complete filter chain, detect repeated route-presentation pairs, and stop after the documented limit.

## Treat modal state as hierarchical

Each router owns one direct ``IRouter/modalContext``. That context owns a child router for navigation inside the modal and for further nested presentation.

Replace direct modal-context mutation with ``IRouter/sheet(_:options:)``, ``IRouter/fullScreenCover(_:options:)``, and ``IRouter/dismiss()``. Use ``IRouterNavigationOptions/dismissPresented`` when replacement is intentional.

## Keep stack updates transactional

``IRouter/path`` is externally read-only. Use `push`, `pop`, and `popToRoot`. System back navigation remains synchronized through ``IRouterView``.
