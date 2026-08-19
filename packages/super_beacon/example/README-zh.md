# super_beacon 示例

运行应用，输入 UUID 和区域标识符，请求权限，然后开始监控。下方的面板会显示持久化的原生事件。

Android 的 `MainApplication` 和 iOS 的 `AppDelegate` 演示了如何注册原生 `BeaconEventHandler`。示例仅记录事件；应用专用请求应由宿主实现。

Flutter 页面可以配置进入区域事件的冷却时间、可选的本地通知，以及可选的 iOS CoreBluetooth 厂商数据扫描。检查器会显示持久化配置、平台能力标志、原始厂商数据、可为空的位置快照，以及完整的事件映射。
