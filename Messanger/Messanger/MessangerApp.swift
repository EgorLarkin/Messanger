import SwiftUI

@main
struct MessengerApp: App {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    ChatListView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
        }
    }
}
