# flutter_super_beacon

An open-source Flutter monorepo for configurable iBeacon monitoring and
diagnostics.

## Packages

- `super_beacon`: Android and iOS Flutter plugin for region monitoring, ranging,
  persisted diagnostics, optional native notifications, raw manufacturer data,
  nullable location snapshots, and native host event delivery.
- `super_beacon_inspector`: reusable Flutter diagnostics controller and widget.

The packages contain no application endpoint, account identity, fixed beacon
UUID, or fixed region identifier. Applications provide all region values at
runtime and decide what to do with native events.

## Workspace

This repository uses Dart Workspaces and Melos.

```shell
flutter pub get
dart run melos analyze
dart run melos test
```

The runnable application is in `packages/super_beacon/example`.

## Architecture

```text
Host configuration
       |
       v
BeaconClient ---- MethodChannel ---- Android/iOS monitor
       |                                  |
       |                                  +--> BeaconEventHandler (host native)
       v
event stream ---- EventChannel -----------+
       |
       v
super_beacon_inspector
```

Native `BeaconEventHandler` callbacks are intentionally independent of Flutter
UI state. A host may enqueue its own request, local action, or background work
from that callback.

Enter events use a configurable cooldown that defaults to 10 seconds and is
persisted by the native platform. Optional local notifications are disabled by
default and can be emitted by the native enter-event path without a Flutter UI.

## Platform limits

- Android PendingIntent BLE scanning can deliver while the app process is not
  running, subject to OS and device power policies. Android force-stop blocks
  alarms, scans, and receivers until the user launches the app again.
- iOS Core Location provides iBeacon region/ranging values but does not expose
  raw advertisement manufacturer bytes. Those events use the `coreLocation`
  source and have no manufacturer data.
- Optional iOS CoreBluetooth scanning emits separate `coreBluetooth`
  advertisement events with real manufacturer ID/bytes/hex while scanning is
  allowed. Background discovery is system-controlled, may be throttled or
  coalesced, and is not a continuous scanner guarantee.
- When an iOS app is explicitly terminated by the user, the system does not
  relaunch it for region or Bluetooth events until the user opens it again.
- Enter events attach the most recent native location when one is available.
  Permission, freshness, or system availability may leave all location fields
  null.

## License

Apache License 2.0. See package license files.
