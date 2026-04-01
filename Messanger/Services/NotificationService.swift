import Foundation
import UIKit
import UserNotifications
import Combine

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    private let center = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        center.delegate = self
    }
    
    func requestPermission() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Уведомления разрешены")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("❌ Уведомления запрещены: \(error?.localizedDescription ?? "неизвестно")")
            }
        }
    }
    
    func showMessageNotification(from: String, text: String, chatId: String) {
        let content = UNMutableNotificationContent()
        content.title = from
        content.body = text
        content.sound = .default
        content.badge = 1
        content.threadIdentifier = chatId
        
        let request = UNNotificationRequest(
            identifier: "msg_\(chatId)_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                print("❌ Ошибка уведомления: \(error)")
            }
        }
    }
    
    func clearBadge() {
        // iOS 17+ способ
        if #available(iOS 17.0, *) {
            center.getDeliveredNotifications { notifications in
                let ids = notifications.map { $0.request.identifier }
                self.center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🔔 Тап по уведомлению")
        completionHandler()
    }
}
