// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'super_beacon_inspector_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class BeaconInspectorLocalizationsEn extends BeaconInspectorLocalizations {
  BeaconInspectorLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get title => 'Native event log';

  @override
  String eventsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
      zero: 'No events',
    );
    return '$_temp0';
  }

  @override
  String overviewCount(int liveCount, int eventCount) {
    return '$liveCount live · $eventCount events';
  }

  @override
  String get liveDiscoveries => 'Live discoveries';

  @override
  String get eventHistory => 'Event history';

  @override
  String get refresh => 'Refresh';

  @override
  String get copy => 'Copy';

  @override
  String get clear => 'Clear';

  @override
  String get noEvents => 'No native events yet.';

  @override
  String get monitoring => 'Monitoring';

  @override
  String get notMonitoring => 'Not monitoring';

  @override
  String get monitoringStatus => 'Monitoring status';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get locationPermission => 'Location permission';

  @override
  String get error => 'Error';

  @override
  String get configuration => 'Configuration';

  @override
  String get notifications => 'notifications';

  @override
  String get cooldown => 'cooldown';

  @override
  String get iosBluetoothScan => 'iOS Bluetooth scan';

  @override
  String get capabilities => 'Capabilities';

  @override
  String get coreLocationRegionMonitoring => 'Core Location region monitoring';

  @override
  String get bluetoothAdvertisementScanning =>
      'Bluetooth advertisement scanning';

  @override
  String get backgroundAdvertisementScanning =>
      'background advertisement scanning';

  @override
  String get continuousBackgroundScanningGuaranteed =>
      'continuous background scanning guaranteed';

  @override
  String get relaunchAfterUserForceQuit => 'relaunch after user force quit';

  @override
  String get manufacturerDataOnRegionEvents =>
      'manufacturer data on region events';

  @override
  String capabilitiesSupported(int supported, int total) {
    return '$supported of $total supported';
  }

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get supported => 'Supported';

  @override
  String get unsupported => 'Unsupported';

  @override
  String get rawData => 'Raw data';

  @override
  String get source => 'Source';

  @override
  String get timestamp => 'Timestamp';

  @override
  String get region => 'Region';

  @override
  String get state => 'State';

  @override
  String get reading => 'Reading';

  @override
  String get manufacturerData => 'Manufacturer data';

  @override
  String get location => 'Location';

  @override
  String get message => 'Message';

  @override
  String get system => 'System';

  @override
  String get unknown => 'Unknown';

  @override
  String get monitoringStarted => 'Monitoring started';

  @override
  String get monitoringStopped => 'Monitoring stopped';

  @override
  String get regionEntered => 'Region entered';

  @override
  String get regionExited => 'Region exited';

  @override
  String get regionStateChanged => 'Region state changed';

  @override
  String get beaconRanged => 'Beacon ranged';

  @override
  String get advertisementDiscovered => 'Advertisement discovered';
}
