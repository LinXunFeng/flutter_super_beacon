# super_beacon example

Run the app, enter a UUID and region identifier, request permissions, and start
monitoring. The lower panel shows persisted native events.

The Android `MainApplication` and iOS `AppDelegate` demonstrate native
`BeaconEventHandler` registration. They log events only; application-specific
requests belong in the host.

The Flutter screen configures enter-event cooldown, optional local
notifications, and optional iOS CoreBluetooth manufacturer-data scanning. The
inspector shows persisted configuration, platform capability flags, raw
manufacturer data, nullable location snapshots, and complete event maps.
