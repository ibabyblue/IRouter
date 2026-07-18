# IRouter Example

This application is the runnable companion to IRouter's README and DocC catalog. It links the repository root as a local Swift package, so the labs always exercise the checked-out package source.

## Requirements

- Xcode 16 or newer
- iOS 17 or newer simulator or device
- macOS 14 or newer

IRouter has no external package dependencies, and the Example tests do not require network access.

## Run on iOS

1. Open `IRouterDemo.xcodeproj` in Xcode.
2. Select the shared `IRouterDemo` scheme.
3. Choose an iOS simulator or device and run.

The iOS app presents the labs as tabs.

## Run on macOS

Choose `My Mac` with the same shared scheme and run. The macOS app presents the labs in a split-view sidebar. Full-screen cover commands demonstrate the package's unsupported-presentation outcome because full-screen cover is unavailable on macOS.

## Labs

| Lab | What it demonstrates |
| --- | --- |
| Stack | Typed pushes, top-route deduplication, pop, and pop-to-root |
| Filters | Ordered allow/block/redirect decisions, authentication redirect, and cycle rejection |
| Modals | Sheet and cover presentation, atomic rejection, serialized replacement, child pushes, and interactive dismissal |
| Nested | Child-router stacks, nested modal levels, and hierarchical dismissal |
| Routers | Switching between two independent router instances without recreating `IRouterView` |

Every lab includes a router inspector that exposes the current path, direct modal route and style, child depth, and latest transaction outcome.

## Build and test

Build the app for both supported platforms:

```bash
xcodebuild -quiet build \
  -project IRouterDemo.xcodeproj \
  -scheme IRouterDemo \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild -quiet build \
  -project IRouterDemo.xcodeproj \
  -scheme IRouterDemo \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

The shared scheme includes `IRouterDemoUITests`, which verifies catalog wiring, live modal replacement, interactive dismissal, child-router dismissal, and multiple-router state retention:

```bash
xcodebuild -quiet test \
  -project IRouterDemo.xcodeproj \
  -scheme IRouterDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

Choose another installed iPhone simulator when `iPhone 17 Pro` is unavailable.

## Relationship to DocC

Use the Example to exercise working integrations and the [DocC catalog](../Sources/IRouter/IRouter.docc/IRouter.md) for transaction rules, filter resolution, modal hierarchy, platform behavior, and migration guidance.
