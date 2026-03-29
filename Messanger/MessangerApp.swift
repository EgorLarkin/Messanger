import SwiftUI
import UserNotifications

@main
struct MessangerApp: App {
    @StateObject private var authManager = AuthManager.shared
    
    init() {
        NotificationService.shared.requestPermission()
    }
    
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
