// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'super_beacon_inspector_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class BeaconInspectorLocalizationsZh extends BeaconInspectorLocalizations {
  BeaconInspectorLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get title => '原生事件日志';

  @override
  String eventsCount(int count) {
    return '$count 条事件';
  }

  @override
  String overviewCount(int liveCount, int eventCount) {
    return '实时 $liveCount · 事件 $eventCount';
  }

  @override
  String get liveDiscoveries => '实时发现';

  @override
  String get eventHistory => '事件记录';

  @override
  String get refresh => '刷新';

  @override
  String get copy => '复制';

  @override
  String get clear => '清空';

  @override
  String get noEvents => '暂无原生事件。';

  @override
  String get monitoring => '正在监听';

  @override
  String get notMonitoring => '未监听';

  @override
  String get monitoringStatus => '监听状态';

  @override
  String get bluetooth => '蓝牙';

  @override
  String get locationPermission => '位置权限';

  @override
  String get error => '错误';

  @override
  String get configuration => '配置';

  @override
  String get notifications => '通知';

  @override
  String get cooldown => '冷却时间';

  @override
  String get iosBluetoothScan => 'iOS 蓝牙扫描';

  @override
  String get capabilities => '平台能力';

  @override
  String get coreLocationRegionMonitoring => 'Core Location 区域监听';

  @override
  String get bluetoothAdvertisementScanning => '蓝牙广播扫描';

  @override
  String get backgroundAdvertisementScanning => '后台广播扫描';

  @override
  String get continuousBackgroundScanningGuaranteed => '保证持续后台扫描';

  @override
  String get relaunchAfterUserForceQuit => '用户强制退出后重新启动';

  @override
  String get manufacturerDataOnRegionEvents => '区域事件包含厂商数据';

  @override
  String capabilitiesSupported(int supported, int total) {
    return '支持 $supported/$total 项';
  }

  @override
  String get enabled => '已启用';

  @override
  String get disabled => '未启用';

  @override
  String get supported => '支持';

  @override
  String get unsupported => '不支持';

  @override
  String get rawData => '原始数据';

  @override
  String get source => '来源';

  @override
  String get timestamp => '时间';

  @override
  String get region => '区域';

  @override
  String get state => '状态';

  @override
  String get reading => '测距数据';

  @override
  String get manufacturerData => '厂商数据';

  @override
  String get location => '位置';

  @override
  String get message => '消息';

  @override
  String get system => '系统';

  @override
  String get unknown => '未知';

  @override
  String get monitoringStarted => '开始监听';

  @override
  String get monitoringStopped => '停止监听';

  @override
  String get regionEntered => '进入区域';

  @override
  String get regionExited => '离开区域';

  @override
  String get regionStateChanged => '区域状态变化';

  @override
  String get beaconRanged => 'Beacon 测距';

  @override
  String get advertisementDiscovered => '发现蓝牙广播';
}
