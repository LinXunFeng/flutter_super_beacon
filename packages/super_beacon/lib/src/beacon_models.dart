/// Kinds of lifecycle, region, ranging, and diagnostic events emitted by the
/// plugin.
enum BeaconEventType {
  /// Native monitoring registration completed.
  monitoringStarted,

  /// Native monitoring was stopped.
  monitoringStopped,

  /// The device entered a configured region.
  regionEntered,

  /// The device exited a configured region.
  regionExited,

  /// The platform reported its current state for a region.
  regionStateChanged,

  /// A matching iBeacon ranging sample was received.
  beaconRanged,

  /// CoreBluetooth discovered a raw advertisement on iOS.
  advertisementDiscovered,

  /// The native implementation reported an operational error.
  error,

  /// A newer native event type not recognized by this Dart version.
  unknown,
}

/// Device state relative to a configured region.
enum BeaconRegionState { inside, outside, unknown }

/// Coarse distance classification reported by the native ranging API.
enum BeaconProximity { immediate, near, far, unknown }

/// Native subsystem that produced an event.
enum BeaconEventSource {
  /// Android Bluetooth Low Energy scanning.
  androidBle,

  /// iOS Core Location region monitoring or ranging.
  coreLocation,

  /// Optional iOS CoreBluetooth advertisement scanning.
  coreBluetooth,

  /// Plugin lifecycle or other platform-level activity.
  system,

  /// A source not recognized by this Dart version.
  unknown,
}

/// Raw manufacturer-specific data attached to a Bluetooth advertisement.
final class BeaconManufacturerData {
  /// Creates immutable manufacturer data.
  ///
  /// [manufacturerId] must fit an unsigned 16-bit value and every entry in
  /// [bytes] must fit an unsigned byte. [hex] is generated when omitted.
  BeaconManufacturerData({
    required this.manufacturerId,
    required List<int> bytes,
    String? hex,
  }) : bytes = List<int>.unmodifiable(bytes),
       hex =
           hex ??
           bytes
               .map((value) => value.toRadixString(16).padLeft(2, '0'))
               .join()
               .toUpperCase() {
    if (manufacturerId < 0 || manufacturerId > 0xFFFF) {
      throw ArgumentError.value(
        manufacturerId,
        'manufacturerId',
        'Must be between 0 and 65535.',
      );
    }
    if (bytes.any((value) => value < 0 || value > 0xFF)) {
      throw ArgumentError.value(bytes, 'bytes', 'Values must be bytes.');
    }
  }

  /// Bluetooth SIG company identifier associated with the payload.
  final int manufacturerId;

  /// Complete manufacturer payload as unsigned byte values.
  final List<int> bytes;

  /// Uppercase hexadecimal representation of [bytes].
  final String hex;

  /// Decodes manufacturer data from a platform-channel map.
  factory BeaconManufacturerData.fromMap(Map<String, Object?> map) {
    final rawBytes = map['bytes'];
    return BeaconManufacturerData(
      manufacturerId: _asInt(map['manufacturerId']),
      bytes: rawBytes is List
          ? rawBytes.map((value) => _asInt(value)).toList()
          : const <int>[],
      hex: map['hex']?.toString(),
    );
  }

  /// Encodes this value for platform channels or JSON diagnostics.
  Map<String, Object> toMap() => <String, Object>{
    'manufacturerId': manufacturerId,
    'bytes': bytes,
    'hex': hex,
  };
}

/// Configuration for optional notifications emitted by native enter events.
final class BeaconNotificationConfiguration {
  /// Creates notification configuration with notifications disabled by
  /// default.
  const BeaconNotificationConfiguration({
    this.enabled = false,
    this.channelId = 'super_beacon_events',
    this.channelName = 'Beacon events',
    this.titleTemplate = 'Beacon event',
    this.bodyTemplate = '{eventType}: {regionIdentifier}',
  });

  /// Whether native enter events may display a local notification.
  final bool enabled;

  /// Android notification channel identifier.
  final String channelId;

  /// User-visible Android notification channel name.
  final String channelName;

  /// Notification title template.
  final String titleTemplate;

  /// Notification body template.
  ///
  /// Native implementations replace `{eventType}` and `{regionIdentifier}`.
  final String bodyTemplate;

  /// Encodes this configuration for the native platform.
  Map<String, Object> toMap() => <String, Object>{
    'enabled': enabled,
    'channelId': channelId,
    'channelName': channelName,
    'titleTemplate': titleTemplate,
    'bodyTemplate': bodyTemplate,
  };
}

/// Region matched by UUID and optional major and minor components.
final class BeaconRegion {
  /// Creates a validated region.
  ///
  /// [uuid] must use canonical UUID syntax, [identifier] must not be empty,
  /// and major/minor values must fit unsigned 16-bit integers.
  BeaconRegion({
    required this.uuid,
    required this.identifier,
    this.major,
    this.minor,
  }) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!uuidPattern.hasMatch(uuid)) {
      throw ArgumentError.value(uuid, 'uuid', 'Must be a canonical UUID.');
    }
    if (identifier.trim().isEmpty) {
      throw ArgumentError.value(identifier, 'identifier', 'Must not be empty.');
    }
    _validateComponent(value: major, name: 'major');
    _validateComponent(value: minor, name: 'minor');
  }

  /// Proximity UUID matched case-insensitively.
  final String uuid;

  /// Stable application-defined identifier used in events and native storage.
  final String identifier;

  /// Optional major component; `null` matches every major value.
  final int? major;

  /// Optional minor component; `null` matches every minor value.
  final int? minor;

  /// Encodes this region for the native platform.
  Map<String, Object> toMap() {
    final result = <String, Object>{
      'uuid': uuid.toUpperCase(),
      'identifier': identifier,
    };
    final majorValue = major;
    if (majorValue != null) {
      result['major'] = majorValue;
    }
    final minorValue = minor;
    if (minorValue != null) {
      result['minor'] = minorValue;
    }
    return result;
  }

  static void _validateComponent({required int? value, required String name}) {
    if (value != null && (value < 0 || value > 65535)) {
      throw ArgumentError.value(value, name, 'Must be between 0 and 65535.');
    }
  }

  @override
  bool operator ==(Object other) {
    return other is BeaconRegion &&
        other.uuid.toUpperCase() == uuid.toUpperCase() &&
        other.identifier == identifier &&
        other.major == major &&
        other.minor == minor;
  }

  @override
  int get hashCode => Object.hash(uuid.toUpperCase(), identifier, major, minor);
}

/// Runtime configuration persisted and consumed by the native monitor.
final class BeaconConfiguration {
  /// Creates a validated monitoring configuration.
  ///
  /// At least one region is required. [androidExitTimeout] and
  /// [maxStoredEvents] must be positive; [eventCooldown] may be zero to disable
  /// enter-event deduplication.
  BeaconConfiguration({
    required List<BeaconRegion> regions,
    this.androidExitTimeout = const Duration(seconds: 30),
    this.eventCooldown = const Duration(seconds: 10),
    this.notifications = const BeaconNotificationConfiguration(),
    this.iosBluetoothScanningEnabled = false,
    this.maxStoredEvents = 500,
  }) : regions = List<BeaconRegion>.unmodifiable(regions) {
    if (regions.isEmpty) {
      throw ArgumentError.value(regions, 'regions', 'Must not be empty.');
    }
    if (androidExitTimeout <= Duration.zero) {
      throw ArgumentError.value(
        androidExitTimeout,
        'androidExitTimeout',
        'Must be positive.',
      );
    }
    if (maxStoredEvents <= 0) {
      throw ArgumentError.value(
        maxStoredEvents,
        'maxStoredEvents',
        'Must be positive.',
      );
    }
    if (eventCooldown.isNegative) {
      throw ArgumentError.value(
        eventCooldown,
        'eventCooldown',
        'Must not be negative.',
      );
    }
    if (notifications.enabled &&
        (notifications.channelId.trim().isEmpty ||
            notifications.channelName.trim().isEmpty ||
            notifications.titleTemplate.trim().isEmpty ||
            notifications.bodyTemplate.trim().isEmpty)) {
      throw ArgumentError.value(
        notifications,
        'notifications',
        'Enabled notifications require non-empty values.',
      );
    }
  }

  /// Regions monitored by the native platform.
  final List<BeaconRegion> regions;

  /// Time without a matching Android scan before an exit is inferred.
  final Duration androidExitTimeout;

  /// Minimum interval between persisted enter events for the same region.
  final Duration eventCooldown;

  /// Optional native notification behavior.
  final BeaconNotificationConfiguration notifications;

  /// Whether iOS also scans advertisements through CoreBluetooth.
  ///
  /// This is separate from Core Location monitoring and does not guarantee
  /// continuous background scanning.
  final bool iosBluetoothScanningEnabled;

  /// Maximum number of diagnostic events retained by native storage.
  final int maxStoredEvents;

  /// Encodes this configuration for the native platform.
  Map<String, Object> toMap() {
    return <String, Object>{
      'regions': regions.map((region) => region.toMap()).toList(),
      'androidExitTimeoutMillis': androidExitTimeout.inMilliseconds,
      'eventCooldownMillis': eventCooldown.inMilliseconds,
      'notifications': notifications.toMap(),
      'iosBluetoothScanningEnabled': iosBluetoothScanningEnabled,
      'maxStoredEvents': maxStoredEvents,
    };
  }
}

/// One ranged iBeacon observation.
final class BeaconReading {
  /// Creates a ranging observation from normalized native values.
  const BeaconReading({
    required this.uuid,
    required this.major,
    required this.minor,
    required this.rssi,
    required this.txPower,
    required this.proximity,
    this.accuracy,
  });

  /// Beacon proximity UUID.
  final String uuid;

  /// Beacon major value.
  final int major;

  /// Beacon minor value.
  final int minor;

  /// Received signal strength in dBm.
  final int rssi;

  /// Calibrated transmitter power reported by the beacon.
  final int txPower;

  /// Coarse distance classification.
  final BeaconProximity proximity;

  /// Platform-estimated distance in meters, when available.
  final double? accuracy;

  /// Decodes a reading from a platform-channel map.
  factory BeaconReading.fromMap(Map<String, Object?> map) {
    return BeaconReading(
      uuid: map['uuid']?.toString() ?? '',
      major: _asInt(map['major']),
      minor: _asInt(map['minor']),
      rssi: _asInt(map['rssi']),
      txPower: _asInt(map['txPower']),
      proximity: _enumByName(
        values: BeaconProximity.values,
        name: map['proximity']?.toString(),
        fallback: BeaconProximity.unknown,
      ),
      accuracy: _asDoubleOrNull(map['accuracy']),
    );
  }

  /// Encodes this reading for JSON diagnostics.
  Map<String, Object?> toMap() => <String, Object?>{
    'uuid': uuid,
    'major': major,
    'minor': minor,
    'rssi': rssi,
    'txPower': txPower,
    'proximity': proximity.name,
    'accuracy': accuracy,
  };
}

/// Normalized event shared by live delivery and persisted diagnostics.
final class BeaconEvent {
  /// Creates an immutable event.
  BeaconEvent({
    required this.type,
    required this.timestamp,
    this.source = BeaconEventSource.unknown,
    this.state = BeaconRegionState.unknown,
    this.regionIdentifier,
    this.reading,
    this.manufacturerData,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.locationTimestamp,
    this.message,
    Map<String, Object?> details = const <String, Object?>{},
  }) : details = Map<String, Object?>.unmodifiable(details);

  /// Event category.
  final BeaconEventType type;

  /// Time at which the native platform created the event.
  final DateTime timestamp;

  /// Native subsystem that produced the event.
  final BeaconEventSource source;

  /// Region state associated with the event, if applicable.
  final BeaconRegionState state;

  /// Application-defined identifier of the matching region.
  final String? regionIdentifier;

  /// Ranging values, present for beacon ranging events.
  final BeaconReading? reading;

  /// Raw advertisement data when exposed by the native subsystem.
  final BeaconManufacturerData? manufacturerData;

  /// Latitude from the most recent native location snapshot.
  final double? latitude;

  /// Longitude from the most recent native location snapshot.
  final double? longitude;

  /// Horizontal accuracy of the location snapshot in meters.
  final double? accuracy;

  /// Time at which the attached location snapshot was captured.
  final DateTime? locationTimestamp;

  /// Human-readable native diagnostic message.
  final String? message;

  /// Extensible native metadata retained for forward compatibility.
  final Map<String, Object?> details;

  /// Decodes an event from a platform-channel or persisted map.
  factory BeaconEvent.fromMap(Map<String, Object?> map) {
    final readingValue = map['reading'];
    final manufacturerDataValue = map['manufacturerData'];
    final detailsValue = map['details'];
    return BeaconEvent(
      type: _enumByName(
        values: BeaconEventType.values,
        name: map['type']?.toString(),
        fallback: BeaconEventType.unknown,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(_asInt(map['timestamp'])),
      source: _enumByName(
        values: BeaconEventSource.values,
        name: map['source']?.toString(),
        fallback: BeaconEventSource.unknown,
      ),
      state: _enumByName(
        values: BeaconRegionState.values,
        name: map['state']?.toString(),
        fallback: BeaconRegionState.unknown,
      ),
      regionIdentifier: map['regionIdentifier']?.toString(),
      reading: readingValue is Map
          ? BeaconReading.fromMap(Map<String, Object?>.from(readingValue))
          : null,
      manufacturerData: manufacturerDataValue is Map
          ? BeaconManufacturerData.fromMap(
              Map<String, Object?>.from(manufacturerDataValue),
            )
          : null,
      latitude: _asDoubleOrNull(map['latitude']),
      longitude: _asDoubleOrNull(map['longitude']),
      accuracy: _asDoubleOrNull(map['accuracy']),
      locationTimestamp: _asDateTimeOrNull(map['locationTimestamp']),
      message: map['message']?.toString(),
      details: detailsValue is Map
          ? Map<String, Object?>.from(detailsValue)
          : const <String, Object?>{},
    );
  }

  /// Encodes this event for JSON diagnostics.
  Map<String, Object?> toMap() => <String, Object?>{
    'type': type.name,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'source': source.name,
    'state': state.name,
    'regionIdentifier': regionIdentifier,
    'reading': reading?.toMap(),
    'manufacturerData': manufacturerData?.toMap(),
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'locationTimestamp': locationTimestamp?.millisecondsSinceEpoch,
    'message': message,
    'details': details,
  };
}

/// Backward-compatible name for a persisted [BeaconEvent].
typedef BeaconRecord = BeaconEvent;

/// Point-in-time native monitoring state and persisted diagnostics.
final class BeaconSnapshot {
  /// Creates an immutable snapshot.
  BeaconSnapshot({
    required this.monitoring,
    required this.bluetoothState,
    required this.locationPermission,
    required this.configuration,
    required this.capabilities,
    required List<BeaconEvent> events,
  }) : events = List<BeaconEvent>.unmodifiable(events);

  /// Whether native monitoring is currently registered.
  final bool monitoring;

  /// Platform-specific Bluetooth state name.
  final String bluetoothState;

  /// Platform-specific location authorization state name.
  final String locationPermission;

  /// Persisted configuration values relevant to diagnostics.
  final BeaconConfigurationSnapshot configuration;

  /// Explicit guarantees and limitations of the current platform.
  final BeaconPlatformCapabilities capabilities;

  /// Persisted events in native storage order, newest first.
  final List<BeaconEvent> events;

  /// Persisted events exposed under the legacy record terminology.
  List<BeaconRecord> get records => events;

  /// Decodes a snapshot from a platform-channel map.
  factory BeaconSnapshot.fromMap(Map<String, Object?> map) {
    final eventValues = map['events'];
    final events = <BeaconEvent>[];
    if (eventValues is List) {
      for (final value in eventValues) {
        if (value is Map) {
          events.add(BeaconEvent.fromMap(Map<String, Object?>.from(value)));
        }
      }
    }
    return BeaconSnapshot(
      monitoring: map['monitoring'] == true,
      bluetoothState: map['bluetoothState']?.toString() ?? 'unknown',
      locationPermission: map['locationPermission']?.toString() ?? 'unknown',
      configuration: BeaconConfigurationSnapshot.fromMap(
        map['configuration'] is Map
            ? Map<String, Object?>.from(map['configuration']! as Map)
            : const <String, Object?>{},
      ),
      capabilities: BeaconPlatformCapabilities.fromMap(
        map['capabilities'] is Map
            ? Map<String, Object?>.from(map['capabilities']! as Map)
            : const <String, Object?>{},
      ),
      events: events,
    );
  }
}

/// Persisted configuration values returned in a [BeaconSnapshot].
final class BeaconConfigurationSnapshot {
  /// Creates a configuration summary.
  const BeaconConfigurationSnapshot({
    required this.notificationsEnabled,
    required this.eventCooldown,
    required this.iosBluetoothScanningEnabled,
  });

  /// Whether native enter notifications are enabled.
  final bool notificationsEnabled;

  /// Configured enter-event deduplication interval.
  final Duration eventCooldown;

  /// Whether optional iOS CoreBluetooth scanning is enabled.
  final bool iosBluetoothScanningEnabled;

  /// Decodes a configuration summary from a platform-channel map.
  factory BeaconConfigurationSnapshot.fromMap(Map<String, Object?> map) {
    return BeaconConfigurationSnapshot(
      notificationsEnabled: map['notificationsEnabled'] == true,
      eventCooldown: Duration(milliseconds: _asInt(map['eventCooldownMillis'])),
      iosBluetoothScanningEnabled: map['iosBluetoothScanningEnabled'] == true,
    );
  }
}

/// Platform feature support and background-delivery guarantees.
///
/// These values describe platform capabilities, not current permissions.
final class BeaconPlatformCapabilities {
  /// Creates a complete platform capability description.
  const BeaconPlatformCapabilities({
    required this.coreLocationRegionMonitoring,
    required this.bluetoothAdvertisementScanning,
    required this.backgroundAdvertisementScanning,
    required this.continuousBackgroundScanningGuaranteed,
    required this.relaunchAfterUserForceQuit,
    required this.manufacturerDataOnRegionEvents,
  });

  /// Whether Core Location-style region monitoring is available.
  final bool coreLocationRegionMonitoring;

  /// Whether raw Bluetooth advertisements can be collected.
  final bool bluetoothAdvertisementScanning;

  /// Whether the platform may collect advertisements in the background.
  final bool backgroundAdvertisementScanning;

  /// Whether uninterrupted background scanning is guaranteed.
  final bool continuousBackgroundScanningGuaranteed;

  /// Whether monitoring can relaunch an app explicitly terminated by the user.
  final bool relaunchAfterUserForceQuit;

  /// Whether region events can include raw manufacturer data.
  final bool manufacturerDataOnRegionEvents;

  /// Decodes capabilities from a platform-channel map.
  factory BeaconPlatformCapabilities.fromMap(Map<String, Object?> map) {
    return BeaconPlatformCapabilities(
      coreLocationRegionMonitoring: map['coreLocationRegionMonitoring'] == true,
      bluetoothAdvertisementScanning:
          map['bluetoothAdvertisementScanning'] == true,
      backgroundAdvertisementScanning:
          map['backgroundAdvertisementScanning'] == true,
      continuousBackgroundScanningGuaranteed:
          map['continuousBackgroundScanningGuaranteed'] == true,
      relaunchAfterUserForceQuit: map['relaunchAfterUserForceQuit'] == true,
      manufacturerDataOnRegionEvents:
          map['manufacturerDataOnRegionEvents'] == true,
    );
  }
}

int _asInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asDoubleOrNull(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

DateTime? _asDateTimeOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  final milliseconds = _asInt(value);
  return milliseconds == 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(milliseconds);
}

T _enumByName<T extends Enum>({
  required List<T> values,
  required String? name,
  required T fallback,
}) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}
