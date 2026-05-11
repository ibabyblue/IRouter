import SwiftUI
import iRouter

struct FlushDemo {
    // Simulates a push notification tap that should navigate to a specific detail,
    // clearing any existing sheets or covers first.
    static func handleNotification(router: IRouter<AppRoute>) {
        router.push(.detail(id: "notification-99"), flush: true)
    }
}
