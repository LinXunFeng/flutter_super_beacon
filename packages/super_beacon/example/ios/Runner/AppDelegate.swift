import Flutter
import UIKit
import super_beacon

@main
@objc class AppDelegate: FlutterAppDelegate, BeaconEventHandler {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    BeaconEventHandlers.shared.handler = self
    BeaconMonitor.shared.start()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }

  func beaconMonitor(didReceive event: BeaconNativeEvent) {
    NSLog("Beacon event: %@", event.dictionary.description)
    // The host can enqueue its own API request here.
  }
}
