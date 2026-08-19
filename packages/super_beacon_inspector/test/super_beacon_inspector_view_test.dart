import 'dart:async';

import 'package:super_beacon/super_beacon.dart';
import 'package:super_beacon_inspector/super_beacon_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the application locale', (tester) async {
    final controller = BeaconInspectorController(
      events: const Stream<BeaconEvent>.empty(),
    );

    Widget resultWidget = BeaconInspectorView(controller: controller);
    resultWidget = MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates:
          BeaconInspectorLocalizations.localizationsDelegates,
      supportedLocales: BeaconInspectorLocalizations.supportedLocales,
      home: resultWidget,
    );
    await tester.pumpWidget(resultWidget);

    expect(find.text('原生事件日志'), findsOneWidget);
    expect(find.text('暂无原生事件。'), findsOneWidget);
    expect(find.byTooltip('刷新'), findsOneWidget);
    expect(find.byTooltip('复制'), findsOneWidget);
    expect(find.byTooltip('清空'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('separates status and keeps raw event data collapsed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final event = BeaconEvent(
      type: BeaconEventType.regionEntered,
      timestamp: DateTime(2026, 8, 19, 10, 30, 12, 345),
      source: BeaconEventSource.androidBle,
      state: BeaconRegionState.inside,
      regionIdentifier: 'office',
      reading: const BeaconReading(
        uuid: '00112233-4455-6677-8899-AABBCCDDEEFF',
        major: 1,
        minor: 2,
        rssi: -62,
        txPower: -59,
        proximity: BeaconProximity.near,
      ),
      manufacturerData: BeaconManufacturerData(
        manufacturerId: 0x004C,
        bytes: <int>[0x02, 0x15],
      ),
    );
    final platform = _SnapshotPlatform(
      snapshot: BeaconSnapshot(
        monitoring: true,
        bluetoothState: 'poweredOn',
        locationPermission: 'always',
        configuration: const BeaconConfigurationSnapshot(
          notificationsEnabled: false,
          eventCooldown: Duration(seconds: 10),
          iosBluetoothScanningEnabled: false,
        ),
        capabilities: const BeaconPlatformCapabilities(
          coreLocationRegionMonitoring: true,
          bluetoothAdvertisementScanning: true,
          backgroundAdvertisementScanning: false,
          continuousBackgroundScanningGuaranteed: false,
          relaunchAfterUserForceQuit: false,
          manufacturerDataOnRegionEvents: true,
        ),
        events: <BeaconEvent>[event],
      ),
    );
    final controller = BeaconInspectorController(
      client: BeaconClient(platform: platform),
    );
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates:
            BeaconInspectorLocalizations.localizationsDelegates,
        supportedLocales: BeaconInspectorLocalizations.supportedLocales,
        home: Scaffold(body: BeaconInspectorView(controller: controller)),
      ),
    );

    expect(find.text('监听状态'), findsOneWidget);
    expect(find.text('蓝牙'), findsOneWidget);
    expect(find.text('位置权限'), findsOneWidget);
    expect(find.text('配置'), findsOneWidget);
    expect(find.text('平台能力'), findsOneWidget);
    expect(find.text('进入区域'), findsOneWidget);
    expect(find.text('原始数据'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('进入区域'));
    await tester.pumpAndSettle();

    expect(find.text('原始数据'), findsOneWidget);
    expect(find.text('测距数据'), findsOneWidget);
    expect(find.text('厂商数据'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('scrolls the toolbar and status with the event list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final events = List<BeaconEvent>.generate(
      20,
      (index) => BeaconEvent(
        type: BeaconEventType.regionEntered,
        timestamp: DateTime(2026, 8, 19, 10, 30, index),
        source: BeaconEventSource.androidBle,
        regionIdentifier: 'office-$index',
      ),
    );
    final platform = _SnapshotPlatform(snapshot: _snapshot(events: events));
    final controller = BeaconInspectorController(
      client: BeaconClient(platform: platform),
    );
    await controller.refresh();

    Widget resultWidget = BeaconInspectorView(controller: controller);
    resultWidget = Scaffold(body: resultWidget);
    resultWidget = MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates:
          BeaconInspectorLocalizations.localizationsDelegates,
      supportedLocales: BeaconInspectorLocalizations.supportedLocales,
      home: resultWidget,
    );
    await tester.pumpWidget(resultWidget);

    expect(find.text('原生事件日志'), findsOneWidget);

    await tester.dragFrom(const Offset(180, 550), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('原生事件日志'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('shows high-frequency samples outside the event history', (
    tester,
  ) async {
    final rangedEvent = BeaconEvent(
      type: BeaconEventType.beaconRanged,
      timestamp: DateTime(2026, 8, 19, 10, 30),
      source: BeaconEventSource.androidBle,
      regionIdentifier: 'office',
      reading: const BeaconReading(
        uuid: '00112233-4455-6677-8899-AABBCCDDEEFF',
        major: 1,
        minor: 2,
        rssi: -62,
        txPower: -59,
        proximity: BeaconProximity.near,
      ),
    );
    final historyEvent = BeaconEvent(
      type: BeaconEventType.regionEntered,
      timestamp: DateTime(2026, 8, 19, 10, 29),
      source: BeaconEventSource.androidBle,
      regionIdentifier: 'office',
    );
    final platform = _SnapshotPlatform(
      snapshot: _snapshot(events: <BeaconEvent>[rangedEvent, historyEvent]),
    );
    final controller = BeaconInspectorController(
      client: BeaconClient(platform: platform),
    );
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates:
            BeaconInspectorLocalizations.localizationsDelegates,
        supportedLocales: BeaconInspectorLocalizations.supportedLocales,
        home: Scaffold(body: BeaconInspectorView(controller: controller)),
      ),
    );

    expect(find.text('实时发现'), findsOneWidget);
    expect(find.text('事件记录'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('进入区域'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

BeaconSnapshot _snapshot({required List<BeaconEvent> events}) {
  return BeaconSnapshot(
    monitoring: true,
    bluetoothState: 'poweredOn',
    locationPermission: 'always',
    configuration: const BeaconConfigurationSnapshot(
      notificationsEnabled: false,
      eventCooldown: Duration(seconds: 10),
      iosBluetoothScanningEnabled: false,
    ),
    capabilities: const BeaconPlatformCapabilities(
      coreLocationRegionMonitoring: true,
      bluetoothAdvertisementScanning: true,
      backgroundAdvertisementScanning: false,
      continuousBackgroundScanningGuaranteed: false,
      relaunchAfterUserForceQuit: false,
      manufacturerDataOnRegionEvents: true,
    ),
    events: events,
  );
}

final class _SnapshotPlatform extends BeaconPlatform {
  _SnapshotPlatform({required this.snapshot});

  final BeaconSnapshot snapshot;

  @override
  Stream<BeaconEvent> get events => const Stream<BeaconEvent>.empty();

  @override
  Future<BeaconSnapshot> getSnapshot() async => snapshot;
}
