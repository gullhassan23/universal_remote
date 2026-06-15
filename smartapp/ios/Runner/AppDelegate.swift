import Flutter
import UIKit

#if DEBUG
/// Enables Firebase Analytics DebugView when launching via `flutter run`, VS Code, or Xcode.
/// Must run before Firebase initializes (before plugin registration).
private func enableFirebaseAnalyticsDebugMode() {
  let defaults = UserDefaults.standard
  defaults.set(true, forKey: "/google/measurement/debug_mode")
  defaults.set(true, forKey: "/google/firebase/debug_mode")
  defaults.synchronize()

  var args = ProcessInfo.processInfo.arguments
  if !args.contains("-FIRAnalyticsDebugEnabled") {
    args.append("-FIRAnalyticsDebugEnabled")
  }
  if !args.contains("-FIRDebugEnabled") {
    args.append("-FIRDebugEnabled")
  }
  ProcessInfo.processInfo.setValue(args, forKey: "arguments")

  NSLog("[Firebase] Analytics DebugView enabled (debug build)")
}
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #if DEBUG
    enableFirebaseAnalyticsDebugMode()
    #endif

    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.example.smartapp/android_tv_remote",
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "acquireMulticastLock":
          // Android-only concept; iOS doesn't need it.
          result(true)

        case "releaseMulticastLock":
          // Android-only concept; no-op on iOS.
          result(true)

        case "generateCertificates":
          // TODO(iOS): implement Android TV Remote v2 certificate generation on iOS.
          result([
            "success": false,
            "error": "iOS not implemented"
          ])

        case "connectAndPair":
          // TODO(iOS): implement TLS pairing flow + remote connection.
          result(false)

        case "sendKeyCode":
          // TODO(iOS): implement key sending to connected remote session.
          result(false)

        case "disconnect":
          // TODO(iOS): close sockets/session when implemented.
          result(nil)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    // Start APNs registration early so FCM can obtain a token (avoids apns-token-not-set races).
    // Ensure Firebase Console → Project settings → Cloud Messaging has an APNs Auth Key;
    // Debug builds use sandbox (RunnerDebug.entitlements), Release/TestFlight use production.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
