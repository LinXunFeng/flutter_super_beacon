# flutter_super_beacon

An open-source Flutter monorepo for configurable iBeacon monitoring and
diagnostics.

## ☕ Support me

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/T6T4JKVRP) [![wechat](https://img.shields.io/static/v1?label=WeChat&message=WeChat&nbsp;Pay&color=brightgreen&style=for-the-badge&logo=WeChat)](https://cdn.jsdelivr.net/gh/FullStackAction/PicBed@resource20220417121922/image/202303181116760.jpeg)

Chat: [Join WeChat group](https://mp.weixin.qq.com/s/JBbMstn0qW6M71hh-BRKzw)

## 👜 Packages

These are the packages hosted in this repository:

| Package | Pub | Points |
| --- | --- | --- |
| [super_beacon](./packages/super_beacon/) | [![pub package](https://img.shields.io/pub/v/super_beacon.svg)](https://pub.dev/packages/super_beacon) | [![pub points](https://img.shields.io/pub/points/super_beacon)](https://pub.dev/packages/super_beacon/score) |
| [super_beacon_inspector](./packages/super_beacon_inspector/) | [![pub package](https://img.shields.io/pub/v/super_beacon_inspector.svg)](https://pub.dev/packages/super_beacon_inspector) | [![pub points](https://img.shields.io/pub/points/super_beacon_inspector)](https://pub.dev/packages/super_beacon_inspector/score) |

- `super_beacon`: Android and iOS Flutter plugin for region monitoring, ranging,
  persisted diagnostics, optional native notifications, raw manufacturer data,
  nullable location snapshots, and native host event delivery.
- `super_beacon_inspector`: reusable Flutter diagnostics controller and widget.

The packages contain no application endpoint, account identity, fixed beacon
UUID, or fixed region identifier. Applications provide all region values at
runtime and decide what to do with native events.

## 🧰 Workspace

This repository uses Dart Workspaces and Melos.

```shell
flutter pub get
dart run melos analyze
dart run melos test
```

The runnable application is in `packages/super_beacon/example`.

## 🏗️ Architecture

```text
Host configuration
       |
       v
BeaconClient ---- MethodChannel ---- Android/iOS monitor
       |                                  |
       |                                  +--> BeaconEventHandler (host native)
       v
event stream ---- EventChannel -----------+
       |
       v
super_beacon_inspector
```

Native `BeaconEventHandler` callbacks are intentionally independent of Flutter
UI state. A host may enqueue its own request, local action, or background work
from that callback.

Enter events use a configurable cooldown that defaults to 10 seconds and is
persisted by the native platform. Optional local notifications are disabled by
default and can be emitted by the native enter-event path without a Flutter UI.

## ⚠️ Platform limits

- Android PendingIntent BLE scanning can deliver while the app process is not
  running, subject to OS and device power policies. Android force-stop blocks
  alarms, scans, and receivers until the user launches the app again.
- iOS Core Location provides iBeacon region/ranging values but does not expose
  raw advertisement manufacturer bytes. Those events use the `coreLocation`
  source and have no manufacturer data.
- Optional iOS CoreBluetooth scanning emits separate `coreBluetooth`
  advertisement events with real manufacturer ID/bytes/hex while scanning is
  allowed. Background discovery is system-controlled, may be throttled or
  coalesced, and is not a continuous scanner guarantee.
- When an iOS app is explicitly terminated by the user, the system does not
  relaunch it for region or Bluetooth events until the user opens it again.
- Enter events attach the most recent native location when one is available.
  Permission, freshness, or system availability may leave all location fields
  null.

## 🖨️ About Me

- GitHub: [https://github.com/LinXunFeng](https://github.com/LinXunFeng)
- Email: [xunfenghellolo@gmail.com](mailto:xunfenghellolo@gmail.com)
- Blogs:
  - Full Stack Action: [https://fullstackaction.com](https://fullstackaction.com)
  - Juejin: [https://juejin.cn/user/1820446984512392](https://juejin.cn/user/1820446984512392)

<img height="267.5" width="481.5" src="https://github.com/LinXunFeng/LinXunFeng/raw/master/static/img/FSAQR.png" alt="Full Stack Action WeChat official account QR code" />

## 📄 License

Apache License 2.0. See package license files.
