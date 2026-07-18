# Modal and Nested Routers

Model modal presentation as a hierarchy of routers with one direct modal per level.

## Own one direct modal

A router's read-only ``IRouter/modalContext`` is either `nil` or one ``IRouterContext``. The context records:

- A stable identity for presentation callbacks.
- The route rendered by the modal.
- Its ``IRouterModalStyle``.
- A child router rooted at the modal route.

```swift
let outcome = router.sheet(.settings)

if let context = router.modalContext {
    print(context.route)
    print(context.style)
}
```

Presenting another direct modal without ``IRouterNavigationOptions/dismissPresented`` returns a modal-already-presented rejection and preserves the visible context.

## Replace a visible modal

Request replacement explicitly:

```swift
router.sheet(.profile, options: [.dismissPresented])
```

The router commits the desired context immediately. ``IRouterView`` serializes that desired state against SwiftUI: it dismisses the visible presentation using the native animation, retains only the latest rapid replacement, and presents it after the matching dismissal callback.

Stale callbacks are matched by context identity and style, so an older dismissal cannot clear or complete a newer presentation.

## Navigate inside a modal

``IRouterView`` renders modal content through the context's child router. The same destination builder handles the child root, pushed routes, and further modal routes.

Calling `push` from modal content changes only that child router's path. Calling `sheet` or `fullScreenCover` on the child creates the next nested modal level instead of competing with the parent's direct modal.

## Dismiss one level at a time

Calling ``IRouter/dismiss()`` on a child router first removes its own direct modal, then pops its own stack, and only then dismisses the parent-owned modal that contains it.

A child router captures the identity of its owning parent context. If the parent replaces that context, the stale child can no longer dismiss the newer modal.

## Handle interactive dismissal

When a user dismisses a sheet interactively, the presentation binding reports the matching context identity to the owning router. The router clears only that context. A stale binding update is ignored.

This identity handshake keeps SwiftUI presentation state and router-owned modal state consistent without exposing mutable bindings to package clients.
