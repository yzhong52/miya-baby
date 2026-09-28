import Flutter
import UIKit

/// App entry point. Owns the [WatchBridge] for the app's lifetime and
/// attaches it to the implicit Flutter engine's messenger once the engine
/// is ready, so Dart and the watch can talk through the method channel.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private let watchBridge = WatchBridge()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        // Hand the bridge the engine's messenger: this is what lets the
        // "miya_baby/watch" method channel reach Dart.
        watchBridge.attach(to: engineBridge.applicationRegistrar.messenger())
    }
}
