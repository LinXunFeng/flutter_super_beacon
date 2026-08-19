import 'package:super_beacon/super_beacon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeaconRegion', () {
    test('serializes a fully constrained region', () {
      final region = BeaconRegion(
        uuid: '00112233-4455-6677-8899-AABBCCDDEEFF',
        identifier: 'warehouse-entry',
        major: 12,
        minor: 34,
      );

      expect(region.toMap(), <String, Object>{
        'uuid': '00112233-4455-6677-8899-AABBCCDDEEFF',
        'identifier': 'warehouse-entry',
        'major': 12,
        'minor': 34,
      });
    });

    test('rejects invalid UUID and major values', () {
      expect(
        () => BeaconRegion(uuid: 'invalid', identifier: 'region'),
        throwsArgumentError,
      );
      expect(
        () => BeaconRegion(
          uuid: '00112233-4455-6677-8899-AABBCCDDEEFF',
          identifier: 'region',
          major: 65536,
        ),
        throwsArgumentError,
      );
    });
  });

  test('BeaconEvent parses unknown native values without throwing', () {
    final event = BeaconEvent.fromMap(<String, Object?>{
      'type': 'futureNativeEvent',
      'timestamp': 1234,
      'state': 'inside',
      'details': <String, Object?>{'source': 'test'},
    });

    expect(event.type, BeaconEventType.unknown);
    expect(event.timestamp, DateTime.fromMillisecondsSinceEpoch(1234));
    expect(event.state, BeaconRegionState.inside);
    expect(event.details, <String, Object?>{'source': 'test'});
  });

  test(
    'configuration defaults to disabled notifications and ten second cooldown',
    () {
      final configuration = BeaconConfiguration(
        regions: <BeaconRegion>[
          BeaconRegion(
            uuid: '00112233-4455-6677-8899-AABBCCDDEEFF',
            identifier: 'entry',
          ),
        ],
      );

      expect(configuration.eventCooldown, const Duration(seconds: 10));
      expect(configuration.notifications.enabled, isFalse);
      expect(configuration.toMap()['eventCooldownMillis'], 10000);
    },
  );

  test('event parses manufacturer bytes and nullable location snapshot', () {
    final event = BeaconEvent.fromMap(<String, Object?>{
      'type': 'beaconRanged',
      'source': 'androidBle',
      'timestamp': 2000,
      'manufacturerData': <String, Object?>{
        'manufacturerId': 76,
        'bytes': <int>[1, 171, 255],
        'hex': '01ABFF',
      },
      'latitude': 25.0478,
      'longitude': 121.5319,
      'accuracy': 18.5,
      'locationTimestamp': 1500,
    });

    expect(event.source, BeaconEventSource.androidBle);
    expect(event.manufacturerData?.manufacturerId, 76);
    expect(event.manufacturerData?.bytes, <int>[1, 171, 255]);
    expect(event.manufacturerData?.hex, '01ABFF');
    expect(event.latitude, 25.0478);
    expect(event.longitude, 121.5319);
    expect(event.accuracy, 18.5);
    expect(event.locationTimestamp, DateTime.fromMillisecondsSinceEpoch(1500));
  });

  test('snapshot exposes persisted configuration and platform limits', () {
    final snapshot = BeaconSnapshot.fromMap(<String, Object?>{
      'configuration': <String, Object?>{
        'notificationsEnabled': true,
        'eventCooldownMillis': 2500,
        'iosBluetoothScanningEnabled': true,
      },
      'capabilities': <String, Object?>{
        'coreLocationRegionMonitoring': true,
        'bluetoothAdvertisementScanning': true,
        'backgroundAdvertisementScanning': false,
        'continuousBackgroundScanningGuaranteed': false,
        'relaunchAfterUserForceQuit': false,
        'manufacturerDataOnRegionEvents': false,
      },
    });

    expect(snapshot.configuration.notificationsEnabled, isTrue);
    expect(
      snapshot.configuration.eventCooldown,
      const Duration(milliseconds: 2500),
    );
    expect(snapshot.capabilities.coreLocationRegionMonitoring, isTrue);
    expect(snapshot.capabilities.manufacturerDataOnRegionEvents, isFalse);
  });
}
