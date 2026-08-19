import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'super_beacon_inspector_localizations_en.dart';
import 'super_beacon_inspector_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of BeaconInspectorLocalizations
/// returned by `BeaconInspectorLocalizations.of(context)`.
///
/// Applications need to include `BeaconInspectorLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/super_beacon_inspector_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: BeaconInspectorLocalizations.localizationsDelegates,
///   supportedLocales: BeaconInspectorLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the BeaconInspectorLocalizations.supportedLocales
/// property.
abstract class BeaconInspectorLocalizations {
  BeaconInspectorLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static BeaconInspectorLocalizations of(BuildContext context) {
    return Localizations.of<BeaconInspectorLocalizations>(
      context,
      BeaconInspectorLocalizations,
    )!;
  }

  static const LocalizationsDelegate<BeaconInspectorLocalizations> delegate =
      _BeaconInspectorLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Native event log'**
  String get title;

  /// No description provided for @eventsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No events} =1{1 event} other{{count} events}}'**
  String eventsCount(int count);

  /// No description provided for @overviewCount.
  ///
  /// In en, this message translates to:
  /// **'{liveCount} live · {eventCount} events'**
  String overviewCount(int liveCount, int eventCount);

  /// No description provided for @liveDiscoveries.
  ///
  /// In en, this message translates to:
  /// **'Live discoveries'**
  String get liveDiscoveries;

  /// No description provided for @eventHistory.
  ///
  /// In en, this message translates to:
  /// **'Event history'**
  String get eventHistory;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @noEvents.
  ///
  /// In en, this message translates to:
  /// **'No native events yet.'**
  String get noEvents;

  /// No description provided for @monitoring.
  ///
  /// In en, this message translates to:
  /// **'Monitoring'**
  String get monitoring;

  /// No description provided for @notMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Not monitoring'**
  String get notMonitoring;

  /// No description provided for @monitoringStatus.
  ///
  /// In en, this message translates to:
  /// **'Monitoring status'**
  String get monitoringStatus;

  /// No description provided for @bluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get bluetooth;

  /// No description provided for @locationPermission.
  ///
  /// In en, this message translates to:
  /// **'Location permission'**
  String get locationPermission;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @configuration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get configuration;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'notifications'**
  String get notifications;

  /// No description provided for @cooldown.
  ///
  /// In en, this message translates to:
  /// **'cooldown'**
  String get cooldown;

  /// No description provided for @iosBluetoothScan.
  ///
  /// In en, this message translates to:
  /// **'iOS Bluetooth scan'**
  String get iosBluetoothScan;

  /// No description provided for @capabilities.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get capabilities;

  /// No description provided for @coreLocationRegionMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Core Location region monitoring'**
  String get coreLocationRegionMonitoring;

  /// No description provided for @bluetoothAdvertisementScanning.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth advertisement scanning'**
  String get bluetoothAdvertisementScanning;

  /// No description provided for @backgroundAdvertisementScanning.
  ///
  /// In en, this message translates to:
  /// **'background advertisement scanning'**
  String get backgroundAdvertisementScanning;

  /// No description provided for @continuousBackgroundScanningGuaranteed.
  ///
  /// In en, this message translates to:
  /// **'continuous background scanning guaranteed'**
  String get continuousBackgroundScanningGuaranteed;

  /// No description provided for @relaunchAfterUserForceQuit.
  ///
  /// In en, this message translates to:
  /// **'relaunch after user force quit'**
  String get relaunchAfterUserForceQuit;

  /// No description provided for @manufacturerDataOnRegionEvents.
  ///
  /// In en, this message translates to:
  /// **'manufacturer data on region events'**
  String get manufacturerDataOnRegionEvents;

  /// No description provided for @capabilitiesSupported.
  ///
  /// In en, this message translates to:
  /// **'{supported} of {total} supported'**
  String capabilitiesSupported(int supported, int total);

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @supported.
  ///
  /// In en, this message translates to:
  /// **'Supported'**
  String get supported;

  /// No description provided for @unsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported'**
  String get unsupported;

  /// No description provided for @rawData.
  ///
  /// In en, this message translates to:
  /// **'Raw data'**
  String get rawData;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @timestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get timestamp;

  /// No description provided for @region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get region;

  /// No description provided for @state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reading;

  /// No description provided for @manufacturerData.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer data'**
  String get manufacturerData;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @monitoringStarted.
  ///
  /// In en, this message translates to:
  /// **'Monitoring started'**
  String get monitoringStarted;

  /// No description provided for @monitoringStopped.
  ///
  /// In en, this message translates to:
  /// **'Monitoring stopped'**
  String get monitoringStopped;

  /// No description provided for @regionEntered.
  ///
  /// In en, this message translates to:
  /// **'Region entered'**
  String get regionEntered;

  /// No description provided for @regionExited.
  ///
  /// In en, this message translates to:
  /// **'Region exited'**
  String get regionExited;

  /// No description provided for @regionStateChanged.
  ///
  /// In en, this message translates to:
  /// **'Region state changed'**
  String get regionStateChanged;

  /// No description provided for @beaconRanged.
  ///
  /// In en, this message translates to:
  /// **'Beacon ranged'**
  String get beaconRanged;

  /// No description provided for @advertisementDiscovered.
  ///
  /// In en, this message translates to:
  /// **'Advertisement discovered'**
  String get advertisementDiscovered;
}

class _BeaconInspectorLocalizationsDelegate
    extends LocalizationsDelegate<BeaconInspectorLocalizations> {
  const _BeaconInspectorLocalizationsDelegate();

  @override
  Future<BeaconInspectorLocalizations> load(Locale locale) {
    return SynchronousFuture<BeaconInspectorLocalizations>(
      lookupBeaconInspectorLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_BeaconInspectorLocalizationsDelegate old) => false;
}

BeaconInspectorLocalizations lookupBeaconInspectorLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return BeaconInspectorLocalizationsEn();
    case 'zh':
      return BeaconInspectorLocalizationsZh();
  }

  throw FlutterError(
    'BeaconInspectorLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
