# Transactional Navigation

Resolve one final destination before applying one atomic router-state mutation.

## Choose a presentation

Convenience methods cover common destinations:

```swift
let pushOutcome = router.push(.detail(id: "42"))
let sheetOutcome = router.sheet(.settings)

#if !os(macOS)
let coverOutcome = router.fullScreenCover(.onboarding)
#endif
```

Use ``IRouter/navigate(to:as:options:)`` when the presentation is selected dynamically:

```swift
let outcome = router.navigate(
    to: route,
    as: presentation,
    options: options
)
```

Every request begins as an ``IRouterDestination``. Filters may redirect it to another route or presentation before options and commit rules are evaluated.

## Apply options to the final destination

``IRouterNavigationOptions/deduplicateTop`` affects only a final push. When the resolved route equals the current top route, the transaction returns `deduplicated` without changing the path or dismissing a modal.

``IRouterNavigationOptions/dismissPresented`` has presentation-specific behavior:

- A final push removes the router's direct modal before appending the route.
- A final modal replaces the router's current direct modal.

Without `dismissPresented`, a second direct modal is rejected atomically. Options apply after every redirect, not to the originally requested route.

```swift
router.push(.detail(id: "42"), options: [.deduplicateTop])
router.sheet(.settings, options: [.dismissPresented])
```

## Inspect outcomes

Each navigation method returns ``IRouterNavigationOutcome``:

```swift
switch router.push(.settings) {
case .committed(let destination):
    log("Committed \(destination)")
case .blocked(let destination):
    log("Blocked \(destination)")
case .deduplicated(let destination):
    log("Already at \(destination)")
case .rejected(let failure):
    log("Rejected \(failure)")
}
```

`blocked`, `deduplicated`, and `rejected` outcomes leave router state unchanged. Failures identify redirect cycles, redirect-limit exhaustion, existing direct modals, and platform-unavailable presentations.

## Contract the stack

``IRouter/pop()`` removes one pushed route and ``IRouter/popToRoot()`` removes the entire pushed path. Each returns `true` only when it mutates the stack:

```swift
if !router.pop() {
    // The router was already at its root.
}
```

## Dismiss hierarchically

``IRouter/dismiss()`` performs exactly the first available action:

1. Remove the receiver's direct modal.
2. Pop the receiver's top pushed route.
3. Ask the parent router to dismiss the modal that owns this child router.
4. Return unchanged.

The returned ``IRouterDismissOutcome`` records which action occurred. See <doc:ModalAndNestedRouters> for modal hierarchy details.
