import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
