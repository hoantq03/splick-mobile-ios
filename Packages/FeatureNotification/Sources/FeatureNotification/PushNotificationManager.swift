import Foundation
import UserNotifications

public class PushNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    public static let shared = PushNotificationManager()
    
    @Published public var isAuthorized: Bool = false
    @Published public var fcmToken: String?
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    public func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
        } catch {
            print("Failed to request push notification authorization: \(error)")
        }
    }
    
    public func syncTokenWithBackend(fcmToken: String) async {
        self.fcmToken = fcmToken
        // In a real app, use a networking client (e.g. Alamofire or URLSession) to POST to backend
        let url = URL(string: "http://localhost:8080/api/v1/notifications/tokens")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["deviceId": UUID().uuidString, "fcmToken": fcmToken]
        request.httpBody = try? JSONEncoder().encode(body)
        
        // Mocking the request execution for MVP demo purposes
        print("Mock: Sent FCM token to Backend successfully")
    }
}
