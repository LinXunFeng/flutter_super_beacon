import 'dart:async';

import 'package:super_beacon/super_beacon.dart';
import 'package:flutter/foundation.dart';

/// Owns the snapshot and bounded event list displayed by an inspector view.
///
/// The controller listens for live events immediately. Call [refresh] to seed
/// it with events that were persisted before the controller was created.
final class BeaconInspectorController extends ChangeNotifier {
  /// Creates a controller and subscribes to [events] or [BeaconClient.events].
  ///
  /// [maxEvents] bounds the in-memory list and must be greater than zero. The
  /// caller must invoke [dispose] when the controller is no longer used.
  BeaconInspectorController({
    Stream<BeaconEvent>? events,
    BeaconClient? client,
    this.maxEvents = 100,
    this.maxLiveEvents = 20,
    this.liveUpdateInterval = const Duration(milliseconds: 500),
  }) : _client = client ?? BeaconClient.instance {
    if (maxEvents <= 0) {
      throw ArgumentError.value(maxEvents, 'maxEvents', 'Must be positive.');
    }
    if (maxLiveEvents <= 0) {
      throw ArgumentError.value(
        maxLiveEvents,
        'maxLiveEvents',
        'Must be positive.',
      );
    }
    if (liveUpdateInterval.isNegative) {
      throw ArgumentError.value(
        liveUpdateInterval,
        'liveUpdateInterval',
        'Must not be negative.',
      );
    }
    _subscription = (events ?? _client.events).listen(_handleEvent);
  }

  final BeaconClient _client;

  /// Maximum number of newest events retained in memory.
  final int maxEvents;

  /// Maximum number of distinct live beacon samples retained in memory.
  final int maxLiveEvents;

  /// Minimum interval between UI notifications for high-frequency samples.
  final Duration liveUpdateInterval;

  final List<BeaconEvent> _events = <BeaconEvent>[];
  final Map<String, BeaconEvent> _liveEvents = <String, BeaconEvent>{};
  final List<BeaconEvent> _eventsDuringRefresh = <BeaconEvent>[];
  StreamSubscription<BeaconEvent>? _subscription;
  Timer? _liveNotificationTimer;
  BeaconSnapshot? _snapshot;
  bool _loading = false;
  Object? _error;

  /// Newest-first, unmodifiable view of the retained events.
  List<BeaconEvent> get events => List<BeaconEvent>.unmodifiable(_events);

  /// Latest high-frequency sample for each observed beacon or peripheral.
  ///
  /// Ranging and advertisement events are aggregated here instead of being
  /// appended to [events]. Values are ordered by their most recent update.
  List<BeaconEvent> get liveEvents {
    return List<BeaconEvent>.unmodifiable(_liveEvents.values.toList().reversed);
  }

  /// Most recently loaded native snapshot, or `null` before the first refresh.
  BeaconSnapshot? get snapshot => _snapshot;

  /// Whether a snapshot refresh is in progress.
  bool get loading => _loading;

  /// Error from the most recent refresh, cleared when another refresh starts.
  Object? get error => _error;

  /// Reloads native state and merges persisted events into the current list.
  Future<void> refresh() async {
    final retainedEvents = List<BeaconEvent>.of(_events);
    final retainedLiveEvents = List<BeaconEvent>.of(_liveEvents.values);
    _loading = true;
    _error = null;
    _eventsDuringRefresh.clear();
    notifyListeners();
    try {
      _snapshot = await _client.getSnapshot();
      final eventsDuringRefresh = List<BeaconEvent>.of(_eventsDuringRefresh);
      _events.clear();
      _liveEvents.clear();
      final snapshot = _snapshot;
      if (snapshot != null) {
        for (final event in snapshot.events.reversed) {
          _storeEvent(event: event);
        }
      }
      for (final event in retainedEvents.reversed) {
        _storeEvent(event: event);
      }
      for (final event in retainedLiveEvents) {
        _storeEvent(event: event);
      }
      // Native events can arrive while the snapshot method call is pending.
      // Replay them after replacing the lists so refresh cannot discard them.
      for (final event in eventsDuringRefresh) {
        _storeEvent(event: event);
      }
    } catch (error) {
      _error = error;
    } finally {
      _eventsDuringRefresh.clear();
      _loading = false;
      notifyListeners();
    }
  }

  /// Clears native persisted events and the controller's in-memory list.
  Future<void> clear() async {
    await _client.clearEvents();
    _events.clear();
    _liveEvents.clear();
    _notifyImmediately();
  }

  void _handleEvent(BeaconEvent event) {
    if (_loading) {
      _eventsDuringRefresh.add(event);
    }
    _storeEvent(event: event);
    if (_isLiveEvent(event)) {
      _scheduleLiveNotification();
      return;
    }
    _notifyImmediately();
  }

  void _storeEvent({required BeaconEvent event}) {
    if (_isLiveEvent(event)) {
      final key = _liveEventKey(event: event);
      _liveEvents
        ..remove(key)
        ..[key] = event;
      if (_liveEvents.length > maxLiveEvents) {
        _liveEvents.remove(_liveEvents.keys.first);
      }
      return;
    }
    final duplicateIndex = _events.indexWhere(
      (storedEvent) => _isSameEvent(first: storedEvent, second: event),
    );
    if (duplicateIndex >= 0) {
      final storedEvent = _events[duplicateIndex];
      if (event.type == BeaconEventType.unknown &&
          storedEvent.type != BeaconEventType.unknown) {
        return;
      }
      _events.removeAt(duplicateIndex);
    }
    _events.insert(0, event);
    _trimEvents();
  }

  bool _isLiveEvent(BeaconEvent event) {
    return event.type == BeaconEventType.beaconRanged ||
        event.type == BeaconEventType.advertisementDiscovered;
  }

  String _liveEventKey({required BeaconEvent event}) {
    final reading = event.reading;
    if (reading != null) {
      return 'beacon:${reading.uuid.toUpperCase()}:'
          '${reading.major}:${reading.minor}';
    }
    final peripheralIdentifier = event.details['peripheralIdentifier'];
    if (peripheralIdentifier != null) {
      return 'peripheral:$peripheralIdentifier';
    }
    final manufacturerData = event.manufacturerData;
    if (manufacturerData != null) {
      return 'manufacturer:${manufacturerData.manufacturerId}:'
          '${manufacturerData.hex}';
    }
    return '${event.type.name}:${event.source.name}:'
        '${event.regionIdentifier ?? ''}';
  }

  String _eventIdentity({required BeaconEvent event}) {
    final reading = event.reading;
    final manufacturerData = event.manufacturerData;
    return <Object?>[
      event.timestamp.microsecondsSinceEpoch,
      event.source.name,
      event.state.name,
      event.regionIdentifier,
      reading?.uuid.toUpperCase(),
      reading?.major,
      reading?.minor,
      manufacturerData?.manufacturerId,
      manufacturerData?.hex,
      event.message,
    ].join('|');
  }

  bool _isSameEvent({required BeaconEvent first, required BeaconEvent second}) {
    if (_eventIdentity(event: first) != _eventIdentity(event: second)) {
      return false;
    }
    return first.type == second.type ||
        first.type == BeaconEventType.unknown ||
        second.type == BeaconEventType.unknown;
  }

  void _scheduleLiveNotification() {
    if (liveUpdateInterval == Duration.zero) {
      notifyListeners();
      return;
    }
    if (_liveNotificationTimer?.isActive == true) {
      return;
    }
    _liveNotificationTimer = Timer(liveUpdateInterval, () {
      _liveNotificationTimer = null;
      notifyListeners();
    });
  }

  void _notifyImmediately() {
    _liveNotificationTimer?.cancel();
    _liveNotificationTimer = null;
    notifyListeners();
  }

  void _trimEvents() {
    if (_events.length > maxEvents) {
      _events.removeRange(maxEvents, _events.length);
    }
  }

  @override
  void dispose() {
    _liveNotificationTimer?.cancel();
    _liveNotificationTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
