import Flutter
import UIKit
import Photos
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    // Clear badge on cold launch (applicationDidBecomeActive also fires,
    // but calling here ensures it's cleared before Flutter engine boots).
    clearBadge(application)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    clearBadge(application)
  }

  private func clearBadge(_ application: UIApplication) {
    // Synchronous clear — immediate, works on all iOS versions.
    application.applicationIconBadgeNumber = 0
    // Modern async API for iOS 16+ (belt-and-suspenders).
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0, withCompletionHandler: nil)
    }
  }
}
