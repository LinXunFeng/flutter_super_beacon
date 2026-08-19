import 'package:super_beacon/src/beacon_models.dart';
import 'package:super_beacon/src/beacon_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Default [BeaconPlatform] implementation backed by Flutter platform channels.
final class MethodChannelBeaconPlatform extends BeaconPlatform {
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(
    'com.lxf/super_beacon/methods',
  );

  @visibleForTesting
  final EventChannel eventChannel = const EventChannel(
    'com.lxf/super_beacon/events',
  );

  Stream<BeaconEvent>? _events;

  @override
  Stream<BeaconEvent> get events {
    // Cache one broadcast stream so multiple Flutter listeners share the same
    // native EventChannel subscription.
    return _events ??= eventChannel.receiveBroadcastStream().map((value) {
      if (value is! Map) {
        // Preserve unexpected native payloads for diagnostics instead of
        // failing the entire event stream with a cast error.
        return BeaconEvent(
          type: BeaconEventType.unknown,
          timestamp: DateTime.now(),
          details: <String, Object?>{'rawValue': value},
        );
      }
      return BeaconEvent.fromMap(Map<String, Object?>.from(value));
    }).asBroadcastStream();
  }

  @override
  Future<void> configure({required BeaconConfiguration configuration}) async {
    await methodChannel.invokeMethod<void>('configure', configuration.toMap());
  }

  @override
  Future<bool> requestPermissions() async {
    return await methodChannel.invokeMethod<bool>('requestPermissions') ??
        false;
  }

  @override
  Future<bool> startMonitoring() async {
    return await methodChannel.invokeMethod<bool>('startMonitoring') ?? false;
  }

  @override
  Future<void> stopMonitoring() async {
    await methodChannel.invokeMethod<void>('stopMonitoring');
  }

  @override
  Future<BeaconSnapshot> getSnapshot() async {
    final result = await methodChannel.invokeMapMethod<String, Object?>(
      'getSnapshot',
    );
    return BeaconSnapshot.fromMap(result ?? const <String, Object?>{});
  }

  @override
  Future<void> clearEvents() async {
    await methodChannel.invokeMethod<void>('clearEvents');
  }
}
