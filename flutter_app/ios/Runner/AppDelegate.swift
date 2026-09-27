import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let watchBridge = WatchBridge()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        if let controller = window?.rootViewController as? FlutterViewController {
            watchBridge.attach(to: controller)
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
