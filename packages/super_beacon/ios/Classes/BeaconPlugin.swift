import CoreBluetooth
import CoreLocation
import Flutter
import UIKit
import UserNotifications

/// Native event schema shared with Flutter and host application callbacks.
///
/// Location and manufacturer fields are optional because Core Location,
/// CoreBluetooth, authorization, and background state expose different data.
public final class BeaconNativeEvent: NSObject {
  public init(
    type: String,
    timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
    source: String = "system",
    state: String = "unknown",
    regionIdentifier: String? = nil,
    reading: [String: Any]? = nil,
    manufacturerData: [String: Any]? = nil,
    latitude: Double? = nil,
    longitude: Double? = nil,
    accuracy: Double? = nil,
    locationTimestamp: Int64? = nil,
    message: String? = nil,
    details: [String: Any] = [:]
  ) {
    self.type = type
    self.timestamp = timestamp
    self.source = source
    self.state = state
    self.regionIdentifier = regionIdentifier
    self.reading = reading
    self.manufacturerData = manufacturerData
    self.latitude = latitude
    self.longitude = longitude
    self.accuracy = accuracy
    self.locationTimestamp = locationTimestamp
    self.message = message
    self.details = details
  }

  public let type: String
  public let timestamp: Int64
  public let source: String
  public let state: String
  public let regionIdentifier: String?
  public let reading: [String: Any]?
  public let manufacturerData: [String: Any]?
  public let latitude: Double?
  public let longitude: Double?
  public let accuracy: Double?
  public let locationTimestamp: Int64?
  public let message: String?
  public let details: [String: Any]

  public var dictionary: [String: Any] {
    var value: [String: Any] = [
      "type": type,
      "timestamp": timestamp,
      "source": source,
      "state": state,
      "details": details,
    ]
    value["regionIdentifier"] = regionIdentifier
    value["reading"] = reading
    value["manufacturerData"] = manufacturerData
    value["latitude"] = latitude
    value["longitude"] = longitude
    value["accuracy"] = accuracy
    value["locationTimestamp"] = locationTimestamp
    value["message"] = message
    return value
  }
}

private struct NativeNotificationConfiguration {
  let enabled: Bool
  let titleTemplate: String
  let bodyTemplate: String

  init(dictionary: [String: Any]?) {
    enabled = dictionary?["enabled"] as? Bool ?? false
    titleTemplate = dictionary?["titleTemplate"] as? String ?? "Beacon event"
    bodyTemplate = dictionary?["bodyTemplate"] as? String
      ?? "{eventType}: {regionIdentifier}"
  }
}

/// Receives native beacon events without requiring an attached Flutter view.
public protocol BeaconEventHandler: AnyObject {
  /// Handles an event on the callback thread that produced it.
  ///
  /// Implementations should enqueue expensive or asynchronous application work.
  func beaconMonitor(didReceive event: BeaconNativeEvent)
}

/// Process-local registration point for a host application's event handler.
public final class BeaconEventHandlers: NSObject {
  /// Shared handler registry used by the native monitor.
  public static let shared = BeaconEventHandlers()

  /// Current host handler.
  ///
  /// The weak reference avoids extending the application delegate's lifetime.
  public weak var handler: BeaconEventHandler?
}

struct IBeaconAdvertisement {
  let manufacturerID: Int
  let manufacturerPayload: [UInt8]
  let uuid: UUID
  let major: UInt16
  let minor: UInt16
  let txPower: Int8

  init?(data: Data) {
    let values = [UInt8](data)
    guard
      values.count >= 25,
      values[0] == 0x4C,
      values[1] == 0x00,
      values[2] == 0x02,
      values[3] == 0x15
    else {
      return nil
    }
    let uuidHex = values[4..<20].map {
      String(format: "%02X", $0)
    }.joined()
    let uuidValue = "\(uuidHex.prefix(8))-" +
      "\(uuidHex.dropFirst(8).prefix(4))-" +
      "\(uuidHex.dropFirst(12).prefix(4))-" +
      "\(uuidHex.dropFirst(16).prefix(4))-" +
      "\(uuidHex.dropFirst(20))"
    guard let parsedUUID = UUID(uuidString: uuidValue) else {
      return nil
    }
    manufacturerID = Int(values[0]) | (Int(values[1]) << 8)
    manufacturerPayload = Array(values.dropFirst(2))
    uuid = parsedUUID
    major = UInt16(values[20]) << 8 | UInt16(values[21])
    minor = UInt16(values[22]) << 8 | UInt16(values[23])
    txPower = Int8(bitPattern: values[24])
  }
}

struct NativeRegion {
  let uuid: UUID
  let identifier: String
  let major: UInt16?
  let minor: UInt16?

  init?(dictionary: [String: Any]) {
    guard
      let uuidValue = dictionary["uuid"] as? String,
      let uuid = UUID(uuidString: uuidValue),
      let identifier = dictionary["identifier"] as? String,
      !identifier.isEmpty
    else {
      return nil
    }
    self.uuid = uuid
    self.identifier = identifier
    major = (dictionary["major"] as? NSNumber)?.uint16Value
    minor = (dictionary["minor"] as? NSNumber)?.uint16Value
  }

  var dictionary: [String: Any] {
    var value: [String: Any] = [
      "uuid": uuid.uuidString,
      "identifier": identifier,
    ]
    value["major"] = major
    value["minor"] = minor
    return value
  }

  var beaconRegion: CLBeaconRegion {
    if let major, let minor {
      return CLBeaconRegion(
        uuid: uuid,
        major: CLBeaconMajorValue(major),
        minor: CLBeaconMinorValue(minor),
        identifier: identifier
      )
    }
    if let major {
      return CLBeaconRegion(
        uuid: uuid,
        major: CLBeaconMajorValue(major),
        identifier: identifier
      )
    }
    return CLBeaconRegion(uuid: uuid, identifier: identifier)
  }

  func matches(_ advertisement: IBeaconAdvertisement) -> Bool {
    return uuid == advertisement.uuid &&
      (major == nil || major == advertisement.major) &&
      (minor == nil || minor == advertisement.minor)
  }
}

private final class BeaconStore {
  static let shared = BeaconStore()

  private let defaults = UserDefaults.standard
  private let configurationKey = "flutter_super_beacon_configuration"
  private let eventsKey = "flutter_super_beacon_events"
  private let monitoringKey = "flutter_super_beacon_monitoring"

  var regions: [NativeRegion] {
    guard
      let configuration = defaults.dictionary(forKey: configurationKey),
      let values = configuration["regions"] as? [[String: Any]]
    else {
      return []
    }
    return values.compactMap(NativeRegion.init(dictionary:))
  }

  var maxStoredEvents: Int {
    let configuration = defaults.dictionary(forKey: configurationKey)
    return configuration?["maxStoredEvents"] as? Int ?? 500
  }

  var eventCooldownMilliseconds: Int64 {
    let configuration = defaults.dictionary(forKey: configurationKey)
    return (configuration?["eventCooldownMillis"] as? NSNumber)?.int64Value ?? 10_000
  }

  var notificationConfiguration: NativeNotificationConfiguration {
    let configuration = defaults.dictionary(forKey: configurationKey)
    return NativeNotificationConfiguration(
      dictionary: configuration?["notifications"] as? [String: Any]
    )
  }

  var bluetoothScanningEnabled: Bool {
    let configuration = defaults.dictionary(forKey: configurationKey)
    return configuration?["iosBluetoothScanningEnabled"] as? Bool ?? false
  }

  var monitoring: Bool {
    get { defaults.bool(forKey: monitoringKey) }
    set { defaults.set(newValue, forKey: monitoringKey) }
  }

  var events: [[String: Any]] {
    defaults.array(forKey: eventsKey) as? [[String: Any]] ?? []
  }

  func save(configuration: [String: Any]) -> Bool {
    guard
      let values = configuration["regions"] as? [[String: Any]],
      !values.compactMap(NativeRegion.init(dictionary:)).isEmpty
    else {
      return false
    }
    defaults.set(configuration, forKey: configurationKey)
    return true
  }

  func append(event: BeaconNativeEvent) {
    var values = events
    values.insert(event.dictionary, at: 0)
    defaults.set(Array(values.prefix(maxStoredEvents)), forKey: eventsKey)
  }

  func clearEvents() {
    defaults.removeObject(forKey: eventsKey)
  }

  func shouldEmit(_ event: BeaconNativeEvent) -> Bool {
    guard event.type == "regionEntered", eventCooldownMilliseconds > 0 else {
      return true
    }
    let key = "flutter_super_beacon_cooldown_\(event.type)_\(event.regionIdentifier ?? "")"
    let previous = defaults.object(forKey: key) as? NSNumber
    if let previous {
      let previousTimestamp = previous.int64Value
      if event.timestamp >= previousTimestamp,
         event.timestamp - previousTimestamp < eventCooldownMilliseconds {
        return false
      }
    }
    defaults.set(event.timestamp, forKey: key)
    return true
  }
}

private final class BeaconNotificationManager {
  static let shared = BeaconNotificationManager()

  func requestAuthorization(completion: @escaping (Bool) -> Void) {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge]
    ) { granted, _ in
      completion(granted)
    }
  }

  func show(event: BeaconNativeEvent, configuration: NativeNotificationConfiguration) {
    guard configuration.enabled else { return }
    let content = UNMutableNotificationContent()
    content.title = render(configuration.titleTemplate, event: event)
    content.body = render(configuration.bodyTemplate, event: event)
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: "beacon.\(event.regionIdentifier ?? event.type)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  private func render(_ template: String, event: BeaconNativeEvent) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy/MM/dd"
    let date = formatter.string(
      from: Date(timeIntervalSince1970: TimeInterval(event.timestamp) / 1000)
    )
    return template
      .replacingOccurrences(of: "{eventType}", with: event.type)
      .replacingOccurrences(
        of: "{regionIdentifier}",
        with: event.regionIdentifier ?? ""
      )
      .replacingOccurrences(of: "{timestamp}", with: String(event.timestamp))
      .replacingOccurrences(of: "{date}", with: date)
      .replacingOccurrences(
        of: "{latitude}",
        with: event.latitude.map { String($0) } ?? ""
      )
      .replacingOccurrences(
        of: "{longitude}",
        with: event.longitude.map { String($0) } ?? ""
      )
  }
}

private final class BeaconEventBus {
  static let shared = BeaconEventBus()
  var sink: FlutterEventSink?

  func emit(_ event: BeaconNativeEvent) {
    guard BeaconStore.shared.shouldEmit(event) else { return }
    BeaconStore.shared.append(event: event)
    if event.type == "regionEntered" {
      BeaconNotificationManager.shared.show(
        event: event,
        configuration: BeaconStore.shared.notificationConfiguration
      )
    }
    BeaconEventHandlers.shared.handler?.beaconMonitor(didReceive: event)
    DispatchQueue.main.async { [weak self] in
      self?.sink?(event.dictionary)
    }
  }
}

private final class BeaconBluetoothCollector: NSObject, CBCentralManagerDelegate {
  static let shared = BeaconBluetoothCollector()

  private var manager: CBCentralManager?

  var stateDescription: String {
    guard let manager else { return "unknown" }
    switch manager.state {
    case .poweredOn:
      return "poweredOn"
    case .poweredOff:
      return "poweredOff"
    case .unauthorized:
      return "unauthorized"
    case .unsupported:
      return "unsupported"
    case .resetting:
      return "resetting"
    default:
      return "unknown"
    }
  }

  func start() {
    guard BeaconStore.shared.bluetoothScanningEnabled else { return }
    if manager == nil {
      manager = CBCentralManager(
        delegate: self,
        queue: nil,
        options: [CBCentralManagerOptionShowPowerAlertKey: false]
      )
    } else if manager?.state == .poweredOn {
      scan()
    }
  }

  func stop() {
    manager?.stopScan()
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state == .poweredOn, BeaconStore.shared.bluetoothScanningEnabled {
      scan()
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    guard
      let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
      let beacon = IBeaconAdvertisement(data: data),
      let region = BeaconStore.shared.regions.first(where: {
        $0.matches(beacon)
      })
    else {
      return
    }
    var details: [String: Any] = [
      "peripheralIdentifier": peripheral.identifier.uuidString,
      "rssi": RSSI.intValue,
      "uuid": beacon.uuid.uuidString,
      "major": Int(beacon.major),
      "minor": Int(beacon.minor),
      "txPower": Int(beacon.txPower),
    ]
    if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
      details["localName"] = localName
    }
    if let connectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber {
      details["connectable"] = connectable.boolValue
    }
    BeaconEventBus.shared.emit(
      BeaconNativeEvent(
        type: "advertisementDiscovered",
        source: "coreBluetooth",
        regionIdentifier: region.identifier,
        manufacturerData: [
          "manufacturerId": beacon.manufacturerID,
          "bytes": beacon.manufacturerPayload.map(Int.init),
          "hex": beacon.manufacturerPayload.map {
            String(format: "%02X", $0)
          }.joined(),
        ],
        details: details
      )
    )
  }

  private func scan() {
    manager?.scanForPeripherals(
      withServices: nil,
      options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
    )
  }
}

/// Coordinates Core Location region monitoring and optional Bluetooth scans.
public final class BeaconMonitor: NSObject, CLLocationManagerDelegate {
  /// Shared monitor used by both the plugin and native host integration.
  public static let shared = BeaconMonitor()

  private let locationManager = CLLocationManager()

  override private init() {
    super.init()
    locationManager.delegate = self
    locationManager.pausesLocationUpdatesAutomatically = false
  }

  /// Requests always-on location authorization when location services exist.
  @discardableResult
  public func requestPermissions() -> Bool {
    guard CLLocationManager.locationServicesEnabled() else {
      return false
    }
    locationManager.requestAlwaysAuthorization()
    return true
  }

  /// Restores monitoring from persisted runtime configuration.
  ///
  /// Returns false when no regions are configured or location services are
  /// unavailable. Background delivery remains subject to iOS policy.
  @discardableResult
  public func start() -> Bool {
    let regions = BeaconStore.shared.regions
    guard !regions.isEmpty, CLLocationManager.locationServicesEnabled() else {
      return false
    }
    regions.forEach { region in
      let beaconRegion = region.beaconRegion
      beaconRegion.notifyOnEntry = true
      beaconRegion.notifyOnExit = true
      locationManager.startMonitoring(for: beaconRegion)
      locationManager.requestState(for: beaconRegion)
    }
    requestRecentLocationIfAuthorized()
    BeaconBluetoothCollector.shared.start()
    BeaconStore.shared.monitoring = true
    BeaconEventBus.shared.emit(
      BeaconNativeEvent(type: "monitoringStarted")
    )
    return true
  }

  /// Stops region monitoring, ranging, and optional CoreBluetooth collection.
  public func stop() {
    locationManager.monitoredRegions.forEach { region in
      guard region is CLBeaconRegion else { return }
      locationManager.stopMonitoring(for: region)
    }
    stopAllRanging()
    BeaconBluetoothCollector.shared.stop()
    BeaconStore.shared.monitoring = false
    BeaconEventBus.shared.emit(
      BeaconNativeEvent(type: "monitoringStopped")
    )
  }

  public func locationManager(
    _ manager: CLLocationManager,
    didEnterRegion region: CLRegion
  ) {
    guard let beaconRegion = region as? CLBeaconRegion else { return }
    requestRecentLocationIfAuthorized()
    emitRegion(type: "regionEntered", state: "inside", region: beaconRegion)
    startRanging(region: beaconRegion)
  }

  public func locationManager(
    _ manager: CLLocationManager,
    didExitRegion region: CLRegion
  ) {
    guard let beaconRegion = region as? CLBeaconRegion else { return }
    emitRegion(type: "regionExited", state: "outside", region: beaconRegion)
    stopRanging(region: beaconRegion)
  }

  public func locationManager(
    _ manager: CLLocationManager,
    didDetermineState state: CLRegionState,
    for region: CLRegion
  ) {
    guard let beaconRegion = region as? CLBeaconRegion else { return }
    let value: String
    switch state {
    case .inside:
      value = "inside"
      startRanging(region: beaconRegion)
    case .outside:
      value = "outside"
    default:
      value = "unknown"
    }
    emitRegion(type: "regionStateChanged", state: value, region: beaconRegion)
  }

  @available(iOS 13.0, *)
  public func locationManager(
    _ manager: CLLocationManager,
    didRange beacons: [CLBeacon],
    satisfying constraint: CLBeaconIdentityConstraint
  ) {
    emitReadings(beacons)
  }

  public func locationManager(
    _ manager: CLLocationManager,
    didRangeBeacons beacons: [CLBeacon],
    in region: CLBeaconRegion
  ) {
    emitReadings(beacons)
  }

  public func locationManager(
    _ manager: CLLocationManager,
    monitoringDidFailFor region: CLRegion?,
    withError error: Error
  ) {
    BeaconEventBus.shared.emit(
      BeaconNativeEvent(
        type: "error",
        regionIdentifier: region?.identifier,
        message: error.localizedDescription
      )
    )
  }

  private func emitRegion(
    type: String,
    state: String,
    region: CLBeaconRegion
  ) {
    let location = locationManager.location
    BeaconEventBus.shared.emit(
      BeaconNativeEvent(
        type: type,
        source: "coreLocation",
        state: state,
        regionIdentifier: region.identifier,
        latitude: location?.coordinate.latitude,
        longitude: location?.coordinate.longitude,
        accuracy: location?.horizontalAccuracy,
        locationTimestamp: location.map {
          Int64($0.timestamp.timeIntervalSince1970 * 1000)
        }
      )
    )
  }

  private func emitReadings(_ beacons: [CLBeacon]) {
    beacons.forEach { beacon in
      let region = BeaconStore.shared.regions.first { value in
        value.uuid == beacon.uuid &&
          (value.major == nil || value.major == beacon.major.uint16Value) &&
          (value.minor == nil || value.minor == beacon.minor.uint16Value)
      }
      let proximity: String
      switch beacon.proximity {
      case .immediate:
        proximity = "immediate"
      case .near:
        proximity = "near"
      case .far:
        proximity = "far"
      default:
        proximity = "unknown"
      }
      BeaconEventBus.shared.emit(
        BeaconNativeEvent(
          type: "beaconRanged",
          source: "coreLocation",
          state: "inside",
          regionIdentifier: region?.identifier,
          reading: [
            "uuid": beacon.uuid.uuidString,
            "major": beacon.major.intValue,
            "minor": beacon.minor.intValue,
            "rssi": beacon.rssi,
            "txPower": 0,
            "proximity": proximity,
            "accuracy": beacon.accuracy,
          ]
        )
      )
    }
  }

  private func startRanging(region: CLBeaconRegion) {
    if #available(iOS 13.0, *) {
      locationManager.startRangingBeacons(satisfying: region.beaconIdentityConstraint)
    } else {
      locationManager.startRangingBeacons(in: region)
    }
  }

  private func stopRanging(region: CLBeaconRegion) {
    if #available(iOS 13.0, *) {
      locationManager.stopRangingBeacons(satisfying: region.beaconIdentityConstraint)
    } else {
      locationManager.stopRangingBeacons(in: region)
    }
  }

  private func stopAllRanging() {
    BeaconStore.shared.regions.forEach { region in
      stopRanging(region: region.beaconRegion)
    }
  }

  private func requestRecentLocationIfAuthorized() {
    switch CLLocationManager.authorizationStatus() {
    case .authorizedAlways, .authorizedWhenInUse:
      locationManager.requestLocation()
    default:
      break
    }
  }

  public func locationManager(
    _ manager: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {}

  public func locationManager(
    _ manager: CLLocationManager,
    didFailWithError error: Error
  ) {}
}

/// Flutter channel adapter for the shared native beacon monitor.
public final class BeaconPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: "com.lxf/super_beacon/methods",
      binaryMessenger: registrar.messenger()
    )
    let eventChannel = FlutterEventChannel(
      name: "com.lxf/super_beacon/events",
      binaryMessenger: registrar.messenger()
    )
    let instance = BeaconPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configure":
      guard
        let arguments = call.arguments as? [String: Any],
        BeaconStore.shared.save(configuration: arguments)
      else {
        result(
          FlutterError(
            code: "invalid_configuration",
            message: "Invalid beacon configuration",
            details: nil
          )
        )
        return
      }
      result(nil)
    case "requestPermissions":
      let locationRequested = BeaconMonitor.shared.requestPermissions()
      if BeaconStore.shared.notificationConfiguration.enabled {
        BeaconNotificationManager.shared.requestAuthorization { granted in
          DispatchQueue.main.async {
            result(locationRequested && granted)
          }
        }
      } else {
        result(locationRequested)
      }
    case "startMonitoring":
      result(BeaconMonitor.shared.start())
    case "stopMonitoring":
      BeaconMonitor.shared.stop()
      result(nil)
    case "getSnapshot":
      result(snapshot())
    case "clearEvents":
      BeaconStore.shared.clearEvents()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    BeaconEventBus.shared.sink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    BeaconEventBus.shared.sink = nil
    return nil
  }

  private func snapshot() -> [String: Any] {
    let authorization: String
    switch CLLocationManager.authorizationStatus() {
    case .authorizedAlways:
      authorization = "always"
    case .authorizedWhenInUse:
      authorization = "whenInUse"
    case .denied:
      authorization = "denied"
    case .restricted:
      authorization = "restricted"
    default:
      authorization = "notDetermined"
    }
    return [
      "monitoring": BeaconStore.shared.monitoring,
      "bluetoothState": BeaconBluetoothCollector.shared.stateDescription,
      "locationPermission": authorization,
      "configuration": [
        "notificationsEnabled": BeaconStore.shared.notificationConfiguration.enabled,
        "eventCooldownMillis": BeaconStore.shared.eventCooldownMilliseconds,
        "iosBluetoothScanningEnabled": BeaconStore.shared.bluetoothScanningEnabled,
      ],
      "capabilities": [
        "coreLocationRegionMonitoring": true,
        "bluetoothAdvertisementScanning": true,
        "backgroundAdvertisementScanning": false,
        "continuousBackgroundScanningGuaranteed": false,
        "relaunchAfterUserForceQuit": false,
        "manufacturerDataOnRegionEvents": false,
      ],
      "events": BeaconStore.shared.events,
    ]
  }
}
