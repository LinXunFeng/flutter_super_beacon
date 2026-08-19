import 'dart:async';

import 'package:super_beacon/super_beacon.dart';
import 'package:super_beacon_inspector/super_beacon_inspector.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const SuperBeaconExampleApp());
}

final class ExampleStrings {
  const ExampleStrings();

  String get appTitle => 'Super Beacon Example';
  String get uuidLabel => 'Beacon UUID';
  String get identifierLabel => 'Region identifier';
  String get cooldownLabel => 'Enter cooldown (seconds)';
  String get notificationsLabel => 'Local enter notification';
  String get bluetoothScanLabel => 'iOS manufacturer data scan';
  String get configure => 'Configure';
  String get requestPermissions => 'Request permissions';
  String get start => 'Start monitoring';
  String get stop => 'Stop monitoring';
  String get ready => 'Enter a region configuration.';
  String get configured => 'Configuration saved.';
  String get permissionsRequested => 'Permission request completed.';
  String get monitoringStarted => 'Monitoring started.';
  String get monitoringFailed => 'Monitoring could not start.';
  String get monitoringStopped => 'Monitoring stopped.';
  String get invalidConfiguration => 'Enter a valid UUID and identifier.';
}

final class ExampleController extends ChangeNotifier {
  ExampleController({
    BeaconClient? client,
    BeaconInspectorController? inspectorController,
  }) : _client = client ?? BeaconClient.instance,
       inspectorController = inspectorController ?? BeaconInspectorController();

  final BeaconClient _client;
  final BeaconInspectorController inspectorController;
  final TextEditingController uuidController = TextEditingController();
  final TextEditingController identifierController = TextEditingController();
  final TextEditingController cooldownController = TextEditingController(
    text: '10',
  );
  bool notificationsEnabled = false;
  bool iosBluetoothScanningEnabled = false;
  String status = const ExampleStrings().ready;
  bool busy = false;

  Future<void> handleConfigureClick() async {
    await _run(
      action: () async {
        try {
          final region = BeaconRegion(
            uuid: uuidController.text.trim(),
            identifier: identifierController.text.trim(),
          );
          await _client.configure(
            configuration: BeaconConfiguration(
              regions: <BeaconRegion>[region],
              eventCooldown: Duration(
                seconds: int.tryParse(cooldownController.text.trim()) ?? 10,
              ),
              notifications: BeaconNotificationConfiguration(
                enabled: notificationsEnabled,
                titleTemplate: 'Beacon region entered',
                bodyTemplate: '{regionIdentifier}',
              ),
              iosBluetoothScanningEnabled: iosBluetoothScanningEnabled,
            ),
          );
          status = const ExampleStrings().configured;
        } on ArgumentError {
          status = const ExampleStrings().invalidConfiguration;
        }
      },
    );
  }

  void setNotificationsEnabled({required bool value}) {
    notificationsEnabled = value;
    notifyListeners();
  }

  void setIosBluetoothScanningEnabled({required bool value}) {
    iosBluetoothScanningEnabled = value;
    notifyListeners();
  }

  Future<void> handlePermissionsClick() async {
    await _run(
      action: () async {
        await _client.requestPermissions();
        status = const ExampleStrings().permissionsRequested;
      },
    );
  }

  Future<void> handleStartClick() async {
    await _run(
      action: () async {
        final started = await _client.startMonitoring();
        status = started
            ? const ExampleStrings().monitoringStarted
            : const ExampleStrings().monitoringFailed;
        await inspectorController.refresh();
      },
    );
  }

  Future<void> handleStopClick() async {
    await _run(
      action: () async {
        await _client.stopMonitoring();
        status = const ExampleStrings().monitoringStopped;
        await inspectorController.refresh();
      },
    );
  }

  Future<void> _run({required Future<void> Function() action}) async {
    if (busy) {
      return;
    }
    busy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    uuidController.dispose();
    identifierController.dispose();
    cooldownController.dispose();
    inspectorController.dispose();
    super.dispose();
  }
}

class SuperBeaconExampleApp extends StatelessWidget {
  const SuperBeaconExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const strings = ExampleStrings();
    Widget resultWidget = const SuperBeaconExamplePage();
    resultWidget = MaterialApp(
      debugShowCheckedModeBanner: false,
      title: strings.appTitle,
      theme: ThemeData(useMaterial3: true),
      localizationsDelegates:
          BeaconInspectorLocalizations.localizationsDelegates,
      supportedLocales: BeaconInspectorLocalizations.supportedLocales,
      home: resultWidget,
    );
    return resultWidget;
  }
}

class SuperBeaconExamplePage extends StatefulWidget {
  const SuperBeaconExamplePage({super.key});

  @override
  State<SuperBeaconExamplePage> createState() => _SuperBeaconExamplePageState();
}

class _SuperBeaconExamplePageState extends State<SuperBeaconExamplePage> {
  final ExampleStrings strings = const ExampleStrings();
  late final ExampleController controller;

  @override
  void initState() {
    super.initState();
    controller = ExampleController();
    controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_handleChanged);
    controller.dispose();
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget resultWidget = _buildBody();
    resultWidget = Scaffold(appBar: _buildAppBar(), body: resultWidget);
    return resultWidget;
  }

  PreferredSizeWidget _buildAppBar() {
    Widget title = Text(strings.appTitle);
    final PreferredSizeWidget resultWidget = AppBar(title: title);
    return resultWidget;
  }

  Widget _buildBody() {
    Widget resultWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildConfigurationPanel(),
        Expanded(child: _buildInspector()),
      ],
    );
    resultWidget = SafeArea(child: resultWidget);
    return resultWidget;
  }

  Widget _buildConfigurationPanel() {
    Widget resultWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildUuidField(),
        const SizedBox(height: 8),
        _buildIdentifierField(),
        const SizedBox(height: 8),
        _buildCooldownField(),
        _buildConfigurationSwitches(),
        const SizedBox(height: 12),
        _buildActions(),
        const SizedBox(height: 8),
        _buildStatus(),
      ],
    );
    resultWidget = Padding(
      padding: const EdgeInsets.all(16),
      child: resultWidget,
    );
    return resultWidget;
  }

  Widget _buildCooldownField() {
    return TextField(
      controller: controller.cooldownController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: strings.cooldownLabel,
      ),
    );
  }

  Widget _buildConfigurationSwitches() {
    return Column(
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.notificationsLabel),
          value: controller.notificationsEnabled,
          onChanged: (value) {
            controller.setNotificationsEnabled(value: value);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.bluetoothScanLabel),
          value: controller.iosBluetoothScanningEnabled,
          onChanged: (value) {
            controller.setIosBluetoothScanningEnabled(value: value);
          },
        ),
      ],
    );
  }

  Widget _buildUuidField() {
    Widget resultWidget = TextField(
      controller: controller.uuidController,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: strings.uuidLabel,
      ),
    );
    return resultWidget;
  }

  Widget _buildIdentifierField() {
    Widget resultWidget = TextField(
      controller: controller.identifierController,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: strings.identifierLabel,
      ),
    );
    return resultWidget;
  }

  Widget _buildActions() {
    Widget resultWidget = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _buildActionButton(
          label: strings.configure,
          icon: Icons.settings,
          action: controller.handleConfigureClick,
        ),
        _buildActionButton(
          label: strings.requestPermissions,
          icon: Icons.security,
          action: controller.handlePermissionsClick,
        ),
        _buildActionButton(
          label: strings.start,
          icon: Icons.play_arrow,
          action: controller.handleStartClick,
        ),
        _buildActionButton(
          label: strings.stop,
          icon: Icons.stop,
          action: controller.handleStopClick,
        ),
      ],
    );
    return resultWidget;
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Future<void> Function() action,
  }) {
    final iconWidget = Icon(icon);
    final labelWidget = Text(label);
    Widget resultWidget = FilledButton.icon(
      onPressed: controller.busy ? null : action,
      icon: iconWidget,
      label: labelWidget,
    );
    return resultWidget;
  }

  Widget _buildStatus() {
    Widget resultWidget = Text(controller.status);
    return resultWidget;
  }

  Widget _buildInspector() {
    Widget resultWidget = BeaconInspectorView(
      controller: controller.inspectorController,
    );
    return resultWidget;
  }
}
