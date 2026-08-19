# flutter_super_beacon

一个开源的 Flutter monorepo，用于可配置的 iBeacon 监控与诊断。

## ☕ 请我喝一杯咖啡

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/T6T4JKVRP) [![wechat](https://img.shields.io/static/v1?label=WeChat&message=微信收款码&color=brightgreen&style=for-the-badge&logo=WeChat)](https://cdn.jsdelivr.net/gh/FullStackAction/PicBed@resource20220417121922/image/202303181116760.jpeg)

微信技术交流群请看: [【微信群说明】](https://mp.weixin.qq.com/s/JBbMstn0qW6M71hh-BRKzw)

## 👜 包

以下是该仓库中托管的包：

| Package | Pub | Points |
| --- | --- | --- |
| [super_beacon](./packages/super_beacon/) | [![pub package](https://img.shields.io/pub/v/super_beacon.svg)](https://pub.dev/packages/super_beacon) | [![pub points](https://img.shields.io/pub/points/super_beacon)](https://pub.dev/packages/super_beacon/score) |
| [super_beacon_inspector](./packages/super_beacon_inspector/) | [![pub package](https://img.shields.io/pub/v/super_beacon_inspector.svg)](https://pub.dev/packages/super_beacon_inspector) | [![pub points](https://img.shields.io/pub/points/super_beacon_inspector)](https://pub.dev/packages/super_beacon_inspector/score) |

- `super_beacon`：适用于 Android 和 iOS 的 Flutter 插件，支持区域监控、测距、持久化诊断、可选的原生通知、原始厂商数据、可为空的位置信息快照，以及向原生宿主分发事件。
- `super_beacon_inspector`：可复用的 Flutter 诊断控制器和组件。

这些包不包含应用端点、账户标识、固定的 Beacon UUID 或固定的区域标识符。应用需要在运行时提供所有区域参数，并自行决定如何处理原生事件。

## 🧰 工作区

本仓库使用 Dart Workspaces 和 Melos。

```shell
flutter pub get
dart run melos analyze
dart run melos test
```

可运行的应用位于 `packages/super_beacon/example`。

## 🏗️ 架构

```text
宿主配置
       |
       v
BeaconClient ---- MethodChannel ---- Android/iOS 监控器
       |                                  |
       |                                  +--> BeaconEventHandler（原生宿主）
       v
事件流 --------- EventChannel -----------+
       |
       v
super_beacon_inspector
```

原生 `BeaconEventHandler` 回调有意设计为独立于 Flutter UI 状态。宿主可以在该回调中加入自己的请求、本地操作或后台任务。

进入区域事件使用可配置的冷却时间，默认为 10 秒，并由原生平台持久化。可选的本地通知默认关闭；即使没有 Flutter UI，也可以通过原生的进入区域事件路径发送通知。

## ⚠️ 平台限制

- Android 的 PendingIntent BLE 扫描可以在应用进程未运行时分发事件，但会受到操作系统和设备电源策略的限制。Android 强制停止应用后，系统会阻止闹钟、扫描和广播接收器运行，直到用户再次启动应用。
- iOS Core Location 可以提供 iBeacon 区域和测距数据，但不会暴露原始广播厂商字节。这类事件使用 `coreLocation` 来源，且不包含厂商数据。
- 可选的 iOS CoreBluetooth 扫描会在允许扫描时发送独立的 `coreBluetooth` 广播事件，其中包含真实的厂商 ID、字节和十六进制数据。后台发现由系统控制，可能被限流或合并，无法保证持续扫描。
- 当用户明确终止 iOS 应用后，在用户再次打开应用之前，系统不会因区域或蓝牙事件重新启动它。
- 进入区域事件会在存在最近原生位置时附带该位置。由于权限、数据时效性或系统可用性等原因，所有位置字段都可能为空。

## 🖨️ 关于我

- GitHub: [https://github.com/LinXunFeng](https://github.com/LinXunFeng)
- Email: [xunfenghellolo@gmail.com](mailto:xunfenghellolo@gmail.com)
- 博客：
  - 全栈行动：[https://fullstackaction.com](https://fullstackaction.com)
  - 掘金：[https://juejin.cn/user/1820446984512392](https://juejin.cn/user/1820446984512392)

<img height="267.5" width="481.5" src="https://github.com/LinXunFeng/LinXunFeng/raw/master/static/img/FSAQR.png" alt="全栈行动微信公众号二维码" />

## 📄 许可证

Apache License 2.0。请参阅各包中的许可证文件。
