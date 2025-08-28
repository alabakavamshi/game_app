import UIKit
import Flutter
import Firebase
import FirebaseAuth
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Register for remote notifications
        if #available(iOS 10.0, *) {
            // For iOS 10+
            UNUserNotificationCenter.current().delegate = self
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { _, _ in }
            )
        } else {
            // For iOS < 10
            let settings: UIUserNotificationSettings =
            UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        
        application.registerForRemoteNotifications()
        
        // Register plugins
        GeneratedPluginRegistrant.register(with: self)
        
        // Set Firebase Auth delegate
        Auth.auth().settings?.isAppVerificationDisabledForTesting = false // Set to true ONLY for testing
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // Handle incoming notifications
    override func application(_ application: UIApplication,
                             didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                             fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Handle Firebase Cloud Messaging notifications
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
    }
    
    // Handle URL callbacks
    override func application(_ app: UIApplication,
                             open url: URL,
                             options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Handle Firebase Auth URL callbacks
        if Auth.auth().canHandle(url) {
            return true
        }
        return super.application(app, open: url, options: options)
    }
    
    // Handle APNS token registration
    override func application(_ application: UIApplication,
                             didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass device token to Firebase Auth for phone verification
        Auth.auth().setAPNSToken(deviceToken, type: .prod) // Use .sandbox for development
        
        // Forward to other handlers if needed
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
    
    // Handle notification center delegate methods
    @available(iOS 10.0, *)
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                        willPresent notification: UNNotification,
                                        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Handle notifications while app is in foreground
        completionHandler([[.alert, .sound, .badge]])
    }
    
    @available(iOS 10.0, *)
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                        didReceive response: UNNotificationResponse,
                                        withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification interactions
        completionHandler()
    }
}