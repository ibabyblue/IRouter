import SwiftUI
import iRouter

struct SettingsView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        List {
            Text("You are logged in!")
            Button("Logout") {
                AuthState.shared.isLoggedIn = false
                router.popToRoot()
            }
        }
        .navigationTitle("Settings")
    }
}

struct LoginView: View {
    @Environment(IRouter<AppRoute>.self) var router

    var body: some View {
        VStack(spacing: 24) {
            Text("Login Required")
                .font(.title)
            Button("Login") {
                AuthState.shared.isLoggedIn = true
                router.dismissAndPush(.settings)
            }
            Button("Cancel") {
                router.dismiss()
            }
        }
        .navigationTitle("Login")
    }
}
