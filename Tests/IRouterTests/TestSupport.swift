import Foundation
@testable import IRouter

enum TestRoute: Hashable, Sendable {
    case home
    case detail(Int)
    case settings
    case login
    case modal(String)
    case redirect(Int)
}

@MainActor
final class TestAuthState {
    var isLoggedIn = false
}
