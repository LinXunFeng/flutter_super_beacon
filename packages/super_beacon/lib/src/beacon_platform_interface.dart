import 'package:super_beacon/src/beacon_method_channel.dart';
import 'package:super_beacon/src/beacon_models.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Contract implemented by platform-specific beacon backends.
///
/// Platform implementations must extend this class rather than implement it so
/// newly added methods can retain their default compatibility behavior.
abstract class BeaconPlatform extends PlatformInterface {
  /// Creates a token-verified platform implementation.
  BeaconPlatform() : super(token: _token);

  static final Object _token = Object();
  static BeaconPlatform _instance = MethodChannelBeaconPlatform();

  /// The platform implementation used by new [BeaconClient] instances.
  static BeaconPlatform get instance => _instance;

  /// Registers the active platform implementation.
  static set instance(BeaconPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Broadcast stream of events delivered by the native platform.
  Stream<BeaconEvent> get events;

  /// Persists the runtime monitoring configuration.
  Future<void> configure({required BeaconConfiguration configuration}) {
    throw UnimplementedError('configure() has not been implemented.');
  }

  /// Requests permissions required by the configured platform features.
  Future<bool> requestPermissions() {
    throw UnimplementedError('requestPermissions() has not been implemented.');
  }

  /// Starts monitoring and reports whether native registration succeeded.
  Future<bool> startMonitoring() {
    throw UnimplementedError('startMonitoring() has not been implemented.');
  }

  /// Stops monitoring while retaining configuration and diagnostics.
  Future<void> stopMonitoring() {
    throw UnimplementedError('stopMonitoring() has not been implemented.');
  }

  /// Reads current native state and persisted diagnostic events.
  Future<BeaconSnapshot> getSnapshot() {
    throw UnimplementedError('getSnapshot() has not been implemented.');
  }

  /// Removes persisted diagnostic events.
  Future<void> clearEvents() {
    throw UnimplementedError('clearEvents() has not been implemented.');
  }
}
