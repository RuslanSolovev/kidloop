import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Регистрируем MethodChannel для уведомлений
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: "kidloop/notifications",
                binaryMessenger: controller.binaryMessenger
            )

            channel.setMethodCallHandler { [weak self] call, result in
                switch call.method {
                case "createChannels":
                    self?.createNotificationChannels()
                    result(true)

                case "requestPermissions":
                    self?.requestNotificationPermission(result: result)

                case "showNotification":
                    let args = call.arguments as? [String: Any] ?? [:]
                    let id = args["id"] as? Int ?? 0
                    let channelId = args["channelId"] as? String ?? "chat"
                    let title = args["title"] as? String ?? ""
                    let body = args["body"] as? String ?? ""
                    let payload = args["payload"] as? String ?? ""
                    self?.showNotification(
                        id: id,
                        channelId: channelId,
                        title: title,
                        body: body,
                        payload: payload
                    )
                    result(true)

                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        // Назначаем делегат для уведомлений
        UNUserNotificationCenter.current().delegate = self

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Создание категорий уведомлений
    func createNotificationChannels() {
        let center = UNUserNotificationCenter.current()

        let chatCategory = UNNotificationCategory(
            identifier: "chat",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let gameCategory = UNNotificationCategory(
            identifier: "game",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let tradeCategory = UNNotificationCategory(
            identifier: "trade",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([chatCategory, gameCategory, tradeCategory])
    }

    // Запрос разрешений на уведомления
    func requestNotificationPermission(result: @escaping FlutterResult) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                result(true)
            } else {
                result(false)
            }
        }
    }

    // Показ локального уведомления
    func showNotification(id: Int, channelId: String, title: String, body: String, payload: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = channelId
        content.userInfo = ["payload": payload]

        let request = UNNotificationRequest(
            identifier: "kidloop_\(id)",
            content: content,
            trigger: nil // Показать сразу
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification error: \(error.localizedDescription)")
            }
        }
    }

    // Обработка клика по уведомлению
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let payload = userInfo["payload"] as? String {
            if let controller = window?.rootViewController as? FlutterViewController {
                let channel = FlutterMethodChannel(
                    name: "kidloop/notifications",
                    binaryMessenger: controller.binaryMessenger
                )
                channel.invokeMethod("notificationTap", arguments: payload)
            }
        }
        completionHandler()
    }

    // Показ уведомлений когда приложение на переднем плане
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
}