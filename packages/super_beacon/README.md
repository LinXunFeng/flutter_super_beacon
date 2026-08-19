# super_beacon

Configurable iBeacon monitoring for Flutter on Android and iOS.

## Capabilities

- Runtime configuration for UUID, identifier, major, and minor.
- Android PendingIntent BLE scanning and inferred enter/exit events.
- iOS Core Location region monitoring and beacon ranging.
- Broadcast Flutter event stream and persisted diagnostic snapshots.
- Native host callbacks through `BeaconEventHandler`.
- Raw manufacturer ID, bytes, and hex on Android BLE and iOS CoreBluetooth events.
- Nullable recent-location snapshots on enter events.
- Persisted, configurable enter-event cooldown (10 seconds by default).
- Optional native local notifications, disabled by default.
- No networking, account data, or application-specific constants.

## Flutter setup

```dart
import 'package:super_beacon/super_beacon.dart';

final region = BeaconRegion(
  uuid: uuidFromYourConfiguration,
  identifier: identifierFromYourConfiguration,
);

await BeaconClient.instance.configure(
  configuration: BeaconConfiguration(
    regions: <BeaconRegion>[region],
    eventCooldown: const Duration(seconds: 10),
    notifications: const BeaconNotificationConfiguration(enabled: false),
    iosBluetoothScanningEnabled: false,
  ),
);
await BeaconClient.instance.requestPermissions();
await BeaconClient.instance.startMonitoring();

BeaconClient.instance.events.listen((event) {
  // Update Flutter state or forward the event to application code.
});
```

`major` and `minor` are optional. Omitting them monitors all matching beacons
under the configured UUID.

## Android setup

The plugin manifest declares BLE, location, background location, and boot
permissions. `requestPermissions()` requests foreground permissions first and
then requests background location separately. On Android 11+, it opens the app
settings page when `Allow all the time` still needs to be selected; call
`requestPermissions()` again after the user returns to confirm the result.

When notifications are enabled, Android 13+ also requires
`POST_NOTIFICATIONS`. The plugin creates the configured notification channel
and requests this permission from `requestPermissions()`. Enter notifications
are emitted from the native receiver path even when no Flutter UI is attached.
Notification templates support `{eventType}`, `{regionIdentifier}`,
`{timestamp}`, `{date}`, `{latitude}`, and `{longitude}`. `{date}` uses the
device's local time zone and the `yyyy/MM/dd` format.

Register a native handler in the application process:

```kotlin
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        BeaconEventHandlers.handler = BeaconEventHandler { context, event ->
            // Enqueue the host application's own work here.
        }
    }
}
```

The handler can receive events from the scan receiver even when no Flutter page
is visible. Re-register it whenever the Android process starts.

## iOS setup

Add these keys to the host `Info.plist` with application-specific descriptions:

- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSBluetoothAlwaysUsageDescription`
- `UIBackgroundModes` containing `location` when background region events are
  required, and `bluetooth-central` when optional CoreBluetooth collection is
  enabled

Register a native handler from the application delegate:

```swift
final class AppDelegate: FlutterAppDelegate, BeaconEventHandler {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    BeaconEventHandlers.shared.handler = self
    BeaconMonitor.shared.start()
    return super.application(
      application,
      didFinishLaunchingWithOptions: options
    )
  }

  func beaconMonitor(didReceive event: BeaconNativeEvent) {
    // Enqueue the host application's own work here.
  }
}
```

Calling `start()` during application launch restores monitoring from the
persisted runtime configuration and creates the Core Location delegate needed
for native background delivery.

iOS limits the number of monitored regions and controls background delivery.
Applications should design their configured region set accordingly.

Core Location iBeacon callbacks expose UUID/major/minor/proximity but do not
expose raw manufacturer bytes. They are marked with source `coreLocation` and
their `manufacturerData` is null. Set `iosBluetoothScanningEnabled` to true to
also run CoreBluetooth discovery and receive separate
`advertisementDiscovered` events marked `coreBluetooth`; these can contain the
actual manufacturer ID and payload bytes/hex. CoreBluetooth advertisements are
parsed as iBeacon payloads and must match a configured UUID and optional
major/minor values before they are emitted.

CoreBluetooth discovery is not equivalent to Core Location region monitoring.
iOS may throttle, coalesce, or suspend background scans, even with
`bluetooth-central` in `UIBackgroundModes`. If the user force-quits the app,
iOS does not relaunch it for region or Bluetooth events until the app is opened
again. The plugin exposes these facts through `BeaconPlatformCapabilities` and
does not guarantee continuous scanning or force-quit delivery.

When notifications are enabled, `requestPermissions()` requests iOS local
notification authorization. Native enter events can schedule the configured
notification without a Flutter view, provided the app has authorization and
the operating system delivers the region event.

## Events

`BeaconEventType` includes monitoring start/stop, region enter/exit/state,
ranging, CoreBluetooth advertisement discovery, errors, and an `unknown`
fallback for forward compatibility.

Use `getSnapshot()` to inspect monitoring, Bluetooth, location permission, and
persisted events. Use `clearEvents()` to remove only diagnostic events.

Every event includes a source and may include `manufacturerData`, `latitude`,
`longitude`, `accuracy`, and `locationTimestamp`. Location values are the most
recent snapshot available to the native platform when entering; they are null
when permission or a usable location is unavailable. Persisted records use the
same event schema.

`BeaconRecord` is the public alias for this persisted event schema; snapshots
return stored records through `events` for backward-compatible naming.
