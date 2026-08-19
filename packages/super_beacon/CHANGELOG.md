## 0.0.1

- Publish the Flutter plugin as `super_beacon`.
- Add configurable Android and iOS iBeacon monitoring.
- Add Flutter event stream and diagnostic snapshots.
- Add native `BeaconEventHandler` extension points for host applications.
- Expose event source, raw manufacturer ID/bytes/hex, and nullable location snapshots.
- Add optional native enter notifications and persisted 10-second cooldown deduplication.
- Add optional iOS CoreBluetooth advertisement collection with explicit platform capabilities.
- Filter iOS CoreBluetooth advertisements by the configured iBeacon UUID and
  optional major/minor values.
