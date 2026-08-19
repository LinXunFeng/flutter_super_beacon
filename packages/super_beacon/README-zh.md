# super_beacon

适用于 Android 和 iOS 的可配置 iBeacon 监控 Flutter 插件。

## 功能

- 在运行时配置 UUID、标识符、major 和 minor。
- Android PendingIntent BLE 扫描，以及推断得出的进入/离开区域事件。
- iOS Core Location 区域监控和 Beacon 测距。
- Flutter 广播事件流和持久化诊断快照。
- 通过 `BeaconEventHandler` 调用原生宿主回调。
- Android BLE 和 iOS CoreBluetooth 事件中的原始厂商 ID、字节和十六进制数据。
- 进入区域事件中可为空的最近位置快照。
- 持久化且可配置的进入区域事件冷却时间（默认为 10 秒）。
- 可选的原生本地通知，默认关闭。
- 不包含网络请求、账户数据或应用专用常量。

## Flutter 配置

```dart
import 'package:super_beacon/super_beacon.dart';

final region = BeaconRegion(
  uuid: uuidFromYourConfiguration,
  identifier: identifierFromYourConfiguration,
);

await BeaconClient.instance.configure(
  configuration: BeaconConfiguration(
    regions: <BeaconRegion>[region],
    eventCooldown: const Duration(seconds: 10),
    notifications: const BeaconNotificationConfiguration(enabled: false),
    iosBluetoothScanningEnabled: false,
  ),
);
await BeaconClient.instance.requestPermissions();
await BeaconClient.instance.startMonitoring();

BeaconClient.instance.events.listen((event) {
  // 更新 Flutter 状态，或将事件转发给应用代码。
});
```

`major` 和 `minor` 为可选参数。省略它们时，将监控配置 UUID 下所有匹配的 Beacon。

## Android 配置

插件清单声明了 BLE、位置、后台位置和开机启动权限。宿主应用必须自行实现运行时权限交互。根据目标 SDK 和应用商店政策，Android 10 及以上版本的后台位置权限可能需要通过单独的系统设置步骤授予。

启用通知后，Android 13 及以上版本还需要 `POST_NOTIFICATIONS` 权限。插件会创建配置的通知渠道，并通过 `requestPermissions()` 请求该权限。即使没有挂载 Flutter UI，进入区域通知也会从原生接收器路径发出。

在应用进程中注册原生处理器：

```kotlin
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        BeaconEventHandlers.handler = BeaconEventHandler { context, event ->
            // 在此加入宿主应用自己的任务。
        }
    }
}
```

即使没有显示 Flutter 页面，处理器也可以接收来自扫描接收器的事件。每次 Android 进程启动时都需要重新注册处理器。

## iOS 配置

在宿主应用的 `Info.plist` 中添加以下键，并提供符合应用实际用途的说明：

- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSBluetoothAlwaysUsageDescription`
- 当需要后台区域事件时，在 `UIBackgroundModes` 中加入 `location`；启用可选的 CoreBluetooth 数据收集时，加入 `bluetooth-central`

在应用委托中注册原生处理器：

```swift
final class AppDelegate: FlutterAppDelegate, BeaconEventHandler {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    BeaconEventHandlers.shared.handler = self
    BeaconMonitor.shared.start()
    return super.application(
      application,
      didFinishLaunchingWithOptions: options
    )
  }

  func beaconMonitor(didReceive event: BeaconNativeEvent) {
    // 在此加入宿主应用自己的任务。
  }
}
```

在应用启动期间调用 `start()`，会从持久化的运行时配置恢复监控，并创建原生后台事件分发所需的 Core Location 委托。

iOS 会限制可监控区域的数量，并控制后台事件分发。应用应据此设计配置的区域集合。

Core Location iBeacon 回调会提供 UUID、major、minor 和 proximity，但不会暴露原始厂商字节。这些事件标记为 `coreLocation` 来源，且其 `manufacturerData` 为 null。将 `iosBluetoothScanningEnabled` 设为 true，可以同时运行 CoreBluetooth 发现并接收标记为 `coreBluetooth` 的独立 `advertisementDiscovered` 事件；这类事件可以包含实际的厂商 ID、载荷字节和十六进制数据。CoreBluetooth 广播必须能解析为 iBeacon，并匹配已配置的 UUID 以及可选的 major/minor，才会产生事件。

CoreBluetooth 发现不等同于 Core Location 区域监控。即使 `UIBackgroundModes` 中包含 `bluetooth-central`，iOS 也可能限制、合并或暂停后台扫描。如果用户强制退出应用，在用户再次打开应用之前，iOS 不会因区域或蓝牙事件重新启动它。插件通过 `BeaconPlatformCapabilities` 暴露这些限制，并不保证持续扫描或应用被强制退出后的事件分发。

启用通知后，`requestPermissions()` 会请求 iOS 本地通知授权。如果应用已获得授权且操作系统分发了区域事件，即使没有 Flutter 视图，原生进入区域事件也可以发送配置的通知。

## 事件

`BeaconEventType` 包含监控开始/停止、进入/离开区域、区域状态、测距、CoreBluetooth 广播发现、错误，以及用于向前兼容的 `unknown` 回退类型。

使用 `getSnapshot()` 可以查看监控状态、蓝牙和位置权限，以及持久化事件。使用 `clearEvents()` 只会删除诊断事件。

每个事件都包含来源，并可能包含 `manufacturerData`、`latitude`、`longitude`、`accuracy` 和 `locationTimestamp`。位置值是进入区域时原生平台可用的最新快照；如果没有权限或可用位置，则为 null。持久化记录使用相同的事件结构。

`BeaconRecord` 是该持久化事件结构的公共别名；为保持命名向后兼容，快照通过 `events` 返回存储的记录。
