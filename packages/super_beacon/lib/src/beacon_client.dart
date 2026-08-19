import 'package:super_beacon/src/beacon_models.dart';
import 'package:super_beacon/src/beacon_platform_interface.dart';

/// High-level entry point for configuring and observing beacon monitoring.
///
/// Use [instance] for normal application integration. A custom [BeaconPlatform]
/// can be injected when testing code that depends on this client.
final class BeaconClient {
  /// Creates a client backed by [platform], or by the registered platform
  /// implementation when [platform] is omitted.
  BeaconClient({BeaconPlatform? platform})
    : _platform = platform ?? BeaconPlatform.instance;

  /// Shared client backed by the platform plugin.
  static final BeaconClient instance = BeaconClient();

  final BeaconPlatform _platform;

  /// Broadcast stream of live native events.
  ///
  /// Persisted events emitted before a listener was attached are available via
  /// [getSnapshot].
  Stream<BeaconEvent> get events => _platform.events;

  /// Persists [configuration] on the native platform.
  ///
  /// Call this before [startMonitoring]. A later native process launch can
  /// restore monitoring from this persisted configuration.
  Future<void> configure({required BeaconConfiguration configuration}) {
    return _platform.configure(configuration: configuration);
  }

  /// Requests the platform permissions needed by the current configuration.
  ///
  /// Returns whether the permission request could be initiated or completed
  /// successfully. Operating-system policy may still restrict background work.
  Future<bool> requestPermissions() {
    return _platform.requestPermissions();
  }

  /// Starts native monitoring using the last persisted configuration.
  ///
  /// Returns `false` when configuration, permissions, or platform services are
  /// unavailable.
  Future<bool> startMonitoring() {
    return _platform.startMonitoring();
  }

  /// Stops native monitoring without deleting its configuration or events.
  Future<void> stopMonitoring() {
    return _platform.stopMonitoring();
  }

  /// Returns the current native state and persisted diagnostic events.
  Future<BeaconSnapshot> getSnapshot() {
    return _platform.getSnapshot();
  }

  /// Deletes persisted diagnostic events only.
  ///
  /// Monitoring state and configuration are left unchanged.
  Future<void> clearEvents() {
    return _platform.clearEvents();
  }
}
