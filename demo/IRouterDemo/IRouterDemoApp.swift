import SwiftUI

@main
struct IRouterDemoApp: App {
    var body: some Scene {
        WindowGroup("IRouter") {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 980, height: 720)
        #endif
    }
}
