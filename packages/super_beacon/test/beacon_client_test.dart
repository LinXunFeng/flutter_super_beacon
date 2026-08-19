import 'package:super_beacon/super_beacon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  test(
    'client delegates configuration and monitoring to the platform',
    () async {
      final platform = _FakeBeaconPlatform();
      final client = BeaconClient(platform: platform);
      final region = BeaconRegion(
        uuid: '00112233-4455-6677-8899-AABBCCDDEEFF',
        identifier: 'lobby',
      );

      await client.configure(
        configuration: BeaconConfiguration(regions: <BeaconRegion>[region]),
      );
      final started = await client.startMonitoring();

      expect(platform.configuration?.regions, <BeaconRegion>[region]);
      expect(platform.startCalls, 1);
      expect(started, isTrue);
    },
  );
}

class _FakeBeaconPlatform extends BeaconPlatform
    with MockPlatformInterfaceMixin {
  BeaconConfiguration? configuration;
  int startCalls = 0;

  @override
  Stream<BeaconEvent> get events => const Stream<BeaconEvent>.empty();

  @override
  Future<void> configure({required BeaconConfiguration configuration}) async {
    this.configuration = configuration;
  }

  @override
  Future<bool> startMonitoring() async {
    startCalls += 1;
    return true;
  }
}
