# super_beacon_inspector

适用于 `super_beacon` Flutter 插件的可复用诊断 UI。

```dart
import 'package:super_beacon_inspector/super_beacon_inspector.dart';

final controller = BeaconInspectorController();

BeaconInspectorView(
  controller: controller,
)
```

在宿主应用中注册组件提供的本地化配置：

```dart
MaterialApp(
  localizationsDelegates:
      BeaconInspectorLocalizations.localizationsDelegates,
  supportedLocales: BeaconInspectorLocalizations.supportedLocales,
)
```

组件内置英文和中文，并自动跟随应用当前语言。控制器也可以使用注入的事件流，以支持测试或自定义事件来源。

工具栏会把持久化记录合并到当前事件列表，也可以将完整事件列表复制为 JSON 或清除记录。刷新期间收到的事件不会丢失；同一事件同时存在已知类型和 `unknown` 持久化形式时，会优先保留已知类型。每个事件会展示其来源、原始厂商 ID/字节/十六进制数据、可为空的位置快照、读数、消息和详细信息映射。状态区域会显示通知和冷却时间配置，以及原生平台能力标志。

高频测距和蓝牙广播事件会按 Beacon 或外设聚合到“实时发现”区域，界面每秒最多刷新两次。监听生命周期、区域变化和错误事件仍按时间顺序保留在“事件记录”中。

当拥有该控制器的页面或服务销毁时，请释放控制器。
