import 'dart:async';

import 'package:super_beacon/super_beacon.dart';
import 'package:super_beacon_inspector/super_beacon_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller keeps newest events within its configured limit', () async {
    final events = StreamController<BeaconEvent>.broadcast(sync: true);
    final controller = BeaconInspectorController(
      events: events.stream,
      maxEvents: 2,
    );

    events.add(_event(timestamp: 1));
    events.add(_event(timestamp: 2));
    events.add(_event(timestamp: 3));
    await pumpEventQueue();

    expect(
      controller.events.map((event) => event.timestamp.millisecondsSinceEpoch),
      <int>[3, 2],
    );

    controller.dispose();
    await events.close();
  });

  test('controller separates and aggregates high-frequency samples', () async {
    final events = StreamController<BeaconEvent>.broadcast(sync: true);
    final controller = BeaconInspectorController(events: events.stream);

    events
      ..add(_rangingEvent(timestamp: 1, rssi: -70))
      ..add(_rangingEvent(timestamp: 2, rssi: -55))
      ..add(_event(timestamp: 3));
    await pumpEventQueue();

    expect(controller.events, hasLength(1));
    expect(controller.events.single.type, BeaconEventType.regionStateChanged);
    expect(controller.liveEvents, hasLength(1));
    expect(controller.liveEvents.single.reading?.rssi, -55);

    controller.dispose();
    await events.close();
  });

  testWidgets('controller batches high-frequency notifications', (
    tester,
  ) async {
    final events = StreamController<BeaconEvent>.broadcast(sync: true);
    final controller = BeaconInspectorController(events: events.stream);
    var notificationCount = 0;
    controller.addListener(() => notificationCount += 1);

    events
      ..add(_rangingEvent(timestamp: 1, rssi: -70))
      ..add(_rangingEvent(timestamp: 2, rssi: -65))
      ..add(_rangingEvent(timestamp: 3, rssi: -60));
    expect(notificationCount, 0);

    await tester.pump(const Duration(milliseconds: 500));

    expect(notificationCount, 1);

    controller.dispose();
    await events.close();
  });

  test('refresh keeps events received while the snapshot is loading', () async {
    final events = StreamController<BeaconEvent>.broadcast(sync: true);
    final snapshotCompleter = Completer<BeaconSnapshot>();
    final platform = _DeferredSnapshotPlatform(
      events: events.stream,
      snapshot: snapshotCompleter.future,
    );
    final controller = BeaconInspectorController(
      client: BeaconClient(platform: platform),
    );

    final refreshFuture = controller.refresh();
    events.add(_event(timestamp: 2));
    snapshotCompleter.complete(
      _snapshot(
        events: <BeaconEvent>[
          BeaconEvent(
            type: BeaconEventType.unknown,
            timestamp: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      ),
    );
    await refreshFuture;

    expect(controller.events.map((event) => event.type), <BeaconEventType>[
      BeaconEventType.regionStateChanged,
      BeaconEventType.unknown,
    ]);

    controller.dispose();
    await events.close();
  });

  test('refresh does not duplicate an event present in the snapshot', () async {
    final events = StreamController<BeaconEvent>.broadcast(sync: true);
    final snapshotCompleter = Completer<BeaconSnapshot>();
    final platform = _DeferredSnapshotPlatform(
      events: events.stream,
      snapshot: snapshotCompleter.future,
    );
    final controller = BeaconInspectorController(
      client: BeaconClient(platform: platform),
    );
    final event = _event(timestamp: 2);

    final refreshFuture = controller.refresh();
    events.add(event);
    snapshotCompleter.complete(_snapshot(events: <BeaconEvent>[event]));
    await refreshFuture;

    expect(controller.events, hasLength(1));
    expect(controller.events.single.type, BeaconEventType.regionStateChanged);

    controller.dispose();
    await events.close();
  });

  test(
    'refresh keeps the known form of an event from the live stream',
    () async {
      final events = StreamController<BeaconEvent>.broadcast(sync: true);
      final knownEvent = _event(timestamp: 2);
      final unknownEvent = BeaconEvent(
        type: BeaconEventType.unknown,
        timestamp: knownEvent.timestamp,
        source: knownEvent.source,
        state: knownEvent.state,
        regionIdentifier: knownEvent.regionIdentifier,
      );
      final platform = _DeferredSnapshotPlatform(
        events: events.stream,
        snapshot: Future<BeaconSnapshot>.value(
          _snapshot(events: <BeaconEvent>[unknownEvent]),
        ),
      );
      final controller = BeaconInspectorController(
        client: BeaconClient(platform: platform),
      );

      events.add(knownEvent);
      await pumpEventQueue();
      await controller.refresh();

      expect(controller.events, hasLength(1));
      expect(controller.events.single.type, BeaconEventType.regionStateChanged);

      controller.dispose();
      await events.close();
    },
  );
}

BeaconEvent _event({required int timestamp}) {
  return BeaconEvent(
    type: BeaconEventType.regionStateChanged,
    timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
  );
}

BeaconEvent _rangingEvent({required int timestamp, required int rssi}) {
  return BeaconEvent(
    type: BeaconEventType.beaconRanged,
    timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
    source: BeaconEventSource.androidBle,
    regionIdentifier: 'office',
    reading: BeaconReading(
      uuid: '00112233-4455-6677-8899-AABBCCDDEEFF',
      major: 1,
      minor: 2,
      rssi: rssi,
      txPower: -59,
      proximity: BeaconProximity.unknown,
    ),
  );
}

BeaconSnapshot _snapshot({required List<BeaconEvent> events}) {
  return BeaconSnapshot(
    monitoring: true,
    bluetoothState: 'poweredOn',
    locationPermission: 'granted',
    configuration: const BeaconConfigurationSnapshot(
      notificationsEnabled: false,
      eventCooldown: Duration(seconds: 10),
      iosBluetoothScanningEnabled: false,
    ),
    capabilities: const BeaconPlatformCapabilities(
      coreLocationRegionMonitoring: false,
      bluetoothAdvertisementScanning: true,
      backgroundAdvertisementScanning: true,
      continuousBackgroundScanningGuaranteed: false,
      relaunchAfterUserForceQuit: false,
      manufacturerDataOnRegionEvents: true,
    ),
    events: events,
  );
}

final class _DeferredSnapshotPlatform extends BeaconPlatform {
  _DeferredSnapshotPlatform({required this.events, required this.snapshot});

  @override
  final Stream<BeaconEvent> events;

  final Future<BeaconSnapshot> snapshot;

  @override
  Future<BeaconSnapshot> getSnapshot() => snapshot;
}
