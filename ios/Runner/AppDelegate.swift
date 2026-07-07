import Flutter
import UIKit
import external_display

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Let external_display register plugins on the secondary engine it spins up
    // for the mirrored display (running the `externalDisplayMain` entrypoint).
    ExternalDisplayPlugin.registerGeneratedPlugin = registerGeneratedPlugin
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  func registerGeneratedPlugin(controller: FlutterViewController) {
    GeneratedPluginRegistrant.register(with: controller)
  }
}
