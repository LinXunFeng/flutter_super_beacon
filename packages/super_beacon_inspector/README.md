# super_beacon_inspector

Reusable diagnostics UI for the `super_beacon` Flutter plugin.

```dart
import 'package:super_beacon_inspector/super_beacon_inspector.dart';

final controller = BeaconInspectorController();

BeaconInspectorView(
  controller: controller,
)
```

Register the package localizations on the host application:

```dart
MaterialApp(
  localizationsDelegates:
      BeaconInspectorLocalizations.localizationsDelegates,
  supportedLocales: BeaconInspectorLocalizations.supportedLocales,
)
```

English and Chinese are included. The inspector follows the application's
active locale. The controller can also consume an injected event stream for
tests or custom event sources.

The toolbar merges persisted records into the current event list, copies the
complete event list as JSON, and clears records. Events received while a
refresh is pending are retained, and a known live event is preferred over an
`unknown` persisted form of the same event. Each event exposes its source, raw
manufacturer ID/bytes/hex, nullable location snapshot, reading, message, and
detail map. The status area shows notification/cooldown configuration and
native capability flags.

High-frequency ranging and advertisement events are grouped by beacon or
peripheral in a live-discovery section and update the UI at most twice per
second. Lifecycle, region, and error events remain in the chronological event
history.

Dispose the controller when its owning screen or service is destroyed.
