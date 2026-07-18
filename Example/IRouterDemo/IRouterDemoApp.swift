import SwiftUI

/// Launches the cross-platform IRouter Example application.
@main
struct IRouterDemoApp: App {
    /// Creates the primary Example window.
    var body: some Scene {
        WindowGroup("IRouter") {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 980, height: 720)
        #endif
    }
}
