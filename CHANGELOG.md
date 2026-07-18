# Changelog

All notable changes to IRouter are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses semantic versioning.

## [0.2.0] - 2026-07-19

### Added

- Added a complete DocC catalog for setup, transactions, filters, redirects, modal hierarchy, SwiftUI integration, platform behavior, and migration.
- Added English documentation comments for package and Example declarations, including private presentation coordination and test helpers.
- Added a dedicated Example guide and catalog reachability UI coverage.

### Changed

- Renamed the repository `demo` directory to `Example` while preserving `IRouterDemo` product, target, and shared-scheme identities.
- Reorganized the root README as the concise installation and discovery entry point.
- Organized previously unreleased migration notes into versioned release history.

## [0.1.1] - 2026-07-15

### Fixed

- Restored native sheet and full-screen-cover presentation animations by keeping modal hosts stable across state changes.
- Preserved selected-router state when reselecting the Routers tab after switching between independent router instances.

## [0.1.0] - 2026-07-15

### Changed

- Replaced independently mutable stack and modal state with a read-only path and one typed modal context per router.
- Replaced navigation boolean parameters and convenience mutations with `IRouterNavigationOptions`, transactional entry points, structured outcomes, and explicit failures.
- Main-actor isolated router state and filter handlers while retaining `Sendable` filter closures.
- Serialized modal dismissal and replacement, retained only the latest rapid replacement, and ignored stale callbacks.
- Rebuilt the Example around stack, filter, modal, nested-router, and multiple-router regression labs.

### Added

- Added iterative redirect resolution, route-presentation cycle detection, and a 32-redirect limit.
- Added hierarchical child routers and identity-safe dismissal of parent-owned modals.
- Expanded tests for transaction values, stack contraction, filters, redirects, modal ownership, hierarchical dismissal, and presentation coordination.

### Breaking

- Replaced `dedup: true` with `options: [.deduplicateTop]`.
- Replaced `flush: true` with `options: [.dismissPresented]`.
- Replaced `dismissAndPush(route)` with `push(route, options: [.dismissPresented])`.
- Replaced `sheetContext` and `coverContext` with read-only `modalContext` and its style.
- Replaced direct path mutation with router navigation and pop APIs.

[0.2.0]: https://github.com/ibabyblue/IRouter/compare/0.1.1...0.2.0
[0.1.1]: https://github.com/ibabyblue/IRouter/compare/0.1.0...0.1.1
[0.1.0]: https://github.com/ibabyblue/IRouter/compare/0.0.4...0.1.0
