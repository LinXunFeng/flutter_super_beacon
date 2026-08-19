import 'dart:convert';

import 'package:super_beacon/super_beacon.dart';
import 'package:super_beacon_inspector/l10n/super_beacon_inspector_localizations.dart';
import 'package:super_beacon_inspector/src/super_beacon_inspector_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Diagnostics panel for native state and beacon event payloads.
///
/// The host owns [controller] and remains responsible for disposing it.
class BeaconInspectorView extends StatefulWidget {
  /// Creates an inspector driven by [controller].
  const BeaconInspectorView({required this.controller, super.key});

  /// Controller that supplies snapshots and live events.
  final BeaconInspectorController controller;

  @override
  State<BeaconInspectorView> createState() => _BeaconInspectorViewState();
}

class _BeaconInspectorViewState extends State<BeaconInspectorView> {
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  final Set<BeaconEvent> _expandedEvents = <BeaconEvent>{};

  BeaconInspectorController get controller => widget.controller;
  BeaconInspectorLocalizations get localizations {
    return BeaconInspectorLocalizations.of(context);
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(covariant BeaconInspectorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == controller) {
      return;
    }
    oldWidget.controller.removeListener(_handleChanged);
    _expandedEvents.clear();
    controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) {
      setState(() {
        _expandedEvents.retainAll(controller.events);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final slivers = <Widget>[
      SliverToBoxAdapter(child: _buildToolbar()),
      if (controller.loading) _buildLoadingIndicator(),
      SliverToBoxAdapter(child: _buildStatus()),
      _buildContent(),
    ];
    return CustomScrollView(slivers: slivers);
  }

  Widget _buildLoadingIndicator() {
    const indicator = LinearProgressIndicator(minHeight: 2);
    return const SliverToBoxAdapter(child: indicator);
  }

  Widget _buildToolbar() {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(localizations.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    localizations.overviewCount(
                      controller.liveEvents.length,
                      controller.events.length,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: controller.loading ? null : controller.refresh,
              tooltip: localizations.refresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              onPressed:
                  controller.events.isEmpty && controller.liveEvents.isEmpty
                  ? null
                  : _copyEvents,
              tooltip: localizations.copy,
              icon: const Icon(Icons.copy_all_outlined),
            ),
            IconButton(
              onPressed: controller.loading ? null : controller.clear,
              tooltip: localizations.clear,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (controller.loading && controller.snapshot == null) {
      const progressIndicator = CircularProgressIndicator();
      const loadingState = Center(child: progressIndicator);
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: loadingState,
      );
    }
    final error = controller.error;
    if (error != null) {
      final errorState = _EmptyState(
        icon: Icons.error_outline,
        message: '${localizations.error}: $error',
      );
      return SliverFillRemaining(hasScrollBody: false, child: errorState);
    }
    final events = controller.events;
    final liveEvents = controller.liveEvents;
    if (events.isEmpty && liveEvents.isEmpty) {
      final emptyState = _EmptyState(
        icon: Icons.sensors_off_outlined,
        message: localizations.noEvents,
      );
      return SliverFillRemaining(hasScrollBody: false, child: emptyState);
    }
    final children = <Widget>[];
    if (liveEvents.isNotEmpty) {
      children.add(
        _buildSectionHeader(
          icon: Icons.bluetooth_searching,
          title: localizations.liveDiscoveries,
          count: liveEvents.length,
        ),
      );
      children.addAll(
        liveEvents.map((event) => _buildLiveEventCard(event: event)),
      );
    }
    if (events.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 8));
      }
      children.add(
        _buildSectionHeader(
          icon: Icons.history,
          title: localizations.eventHistory,
          count: events.length,
        ),
      );
      children.addAll(events.map((event) => _buildEventCard(event)));
    }
    final separatedChildren = <Widget>[];
    for (var index = 0; index < children.length; index += 1) {
      if (index > 0) {
        separatedChildren.add(const SizedBox(height: 8));
      }
      separatedChildren.add(children[index]);
    }
    Widget resultWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: separatedChildren,
    );
    resultWidget = Padding(
      padding: const EdgeInsets.all(12),
      child: resultWidget,
    );
    return SliverToBoxAdapter(child: resultWidget);
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required int count,
  }) {
    final theme = Theme.of(context);
    final iconWidget = Icon(
      icon,
      size: 18,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final titleWidget = Text(title, style: theme.textTheme.titleSmall);
    final countWidget = Text(
      count.toString(),
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    Widget resultWidget = Row(
      children: <Widget>[
        iconWidget,
        const SizedBox(width: 8),
        Expanded(child: titleWidget),
        countWidget,
      ],
    );
    resultWidget = Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: resultWidget,
    );
    return resultWidget;
  }

  Widget _buildLiveEventCard({required BeaconEvent event}) {
    final theme = Theme.of(context);
    final color = _eventColor(event.type, theme.colorScheme);
    final eventIcon = Icon(_eventIcon(event.type), color: color, size: 22);
    Widget iconWidget = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: eventIcon,
    );
    final titleWidget = Text(
      _liveEventTitle(event: event),
      style: theme.textTheme.titleSmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final summaryWidget = Text(
      _liveEventSummary(event: event),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    Widget descriptionWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[titleWidget, const SizedBox(height: 3), summaryWidget],
    );
    final signalWidget = _buildSignalValue(event: event);
    final copyButton = IconButton(
      onPressed: () => _copyEvent(event),
      tooltip: localizations.copy,
      icon: const Icon(Icons.copy_outlined, size: 20),
    );
    Widget resultWidget = Row(
      children: <Widget>[
        iconWidget,
        const SizedBox(width: 12),
        Expanded(child: descriptionWidget),
        signalWidget,
        copyButton,
      ],
    );
    resultWidget = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: resultWidget,
    );
    resultWidget = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: resultWidget,
    );
    return resultWidget;
  }

  Widget _buildSignalValue({required BeaconEvent event}) {
    final theme = Theme.of(context);
    final reading = event.reading;
    final rawRssi = event.details['rssi'];
    final rssi = reading?.rssi ?? (rawRssi is num ? rawRssi.toInt() : null);
    if (rssi == null) {
      return const SizedBox.shrink();
    }
    return Text(
      '$rssi dBm',
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }

  String _liveEventTitle({required BeaconEvent event}) {
    final reading = event.reading;
    if (reading != null) {
      return '${reading.major} / ${reading.minor}';
    }
    final localName = event.details['localName']?.toString();
    if (localName != null && localName.isNotEmpty) {
      return localName;
    }
    final peripheralIdentifier = event.details['peripheralIdentifier']
        ?.toString();
    if (peripheralIdentifier != null && peripheralIdentifier.isNotEmpty) {
      return peripheralIdentifier;
    }
    return _eventTypeLabel(event.type);
  }

  String _liveEventSummary({required BeaconEvent event}) {
    final reading = event.reading;
    final values = <String>[_sourceLabel(event.source)];
    if (event.regionIdentifier != null) {
      values.add(event.regionIdentifier!);
    }
    if (reading != null) {
      values.add(reading.uuid);
    } else {
      final manufacturerData = event.manufacturerData;
      if (manufacturerData != null) {
        final identifier = manufacturerData.manufacturerId
            .toRadixString(16)
            .padLeft(4, '0')
            .toUpperCase();
        values.add('0x$identifier');
      }
    }
    values.add(_formatTimestamp(event.timestamp));
    return values.join('  ·  ');
  }

  Widget _buildStatus() {
    final snapshot = controller.snapshot;
    if (snapshot == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final configuration = snapshot.configuration;
    final capabilities = snapshot.capabilities;
    final configurationSummary = <String>[
      _enabledText(configuration.notificationsEnabled),
      '${configuration.eventCooldown.inMilliseconds} ms',
      _enabledText(configuration.iosBluetoothScanningEnabled),
    ].join('  ·  ');
    final supportedCount = <bool>[
      capabilities.coreLocationRegionMonitoring,
      capabilities.bluetoothAdvertisementScanning,
      capabilities.backgroundAdvertisementScanning,
      capabilities.continuousBackgroundScanningGuaranteed,
      capabilities.relaunchAfterUserForceQuit,
      capabilities.manufacturerDataOnRegionEvents,
    ].where((value) => value).length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth >= 640
                    ? (constraints.maxWidth - 32) / 3
                    : constraints.maxWidth >= 400
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: <Widget>[
                    _StatusMetric(
                      width: itemWidth,
                      icon: snapshot.monitoring
                          ? Icons.sensors
                          : Icons.sensors_off_outlined,
                      label: localizations.monitoringStatus,
                      value: snapshot.monitoring
                          ? localizations.monitoring
                          : localizations.notMonitoring,
                      active: snapshot.monitoring,
                    ),
                    _StatusMetric(
                      width: itemWidth,
                      icon: Icons.bluetooth,
                      label: localizations.bluetooth,
                      value: snapshot.bluetoothState,
                    ),
                    _StatusMetric(
                      width: itemWidth,
                      icon: Icons.location_on_outlined,
                      label: localizations.locationPermission,
                      value: snapshot.locationPermission,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            _buildStatusExpansion(
              key: const ValueKey<String>('configuration-section'),
              icon: Icons.tune,
              title: localizations.configuration,
              summary: configurationSummary,
              children: <Widget>[
                _StatusFact(
                  label: localizations.notifications,
                  value: _enabledText(configuration.notificationsEnabled),
                  state: configuration.notificationsEnabled,
                ),
                _StatusFact(
                  label: localizations.cooldown,
                  value: '${configuration.eventCooldown.inMilliseconds} ms',
                ),
                _StatusFact(
                  label: localizations.iosBluetoothScan,
                  value: _enabledText(
                    configuration.iosBluetoothScanningEnabled,
                  ),
                  state: configuration.iosBluetoothScanningEnabled,
                ),
              ],
            ),
            _buildStatusExpansion(
              key: const ValueKey<String>('capabilities-section'),
              icon: Icons.fact_check_outlined,
              title: localizations.capabilities,
              summary: localizations.capabilitiesSupported(supportedCount, 6),
              children: <Widget>[
                _StatusFact(
                  label: localizations.coreLocationRegionMonitoring,
                  value: _supportedText(
                    capabilities.coreLocationRegionMonitoring,
                  ),
                  state: capabilities.coreLocationRegionMonitoring,
                ),
                _StatusFact(
                  label: localizations.bluetoothAdvertisementScanning,
                  value: _supportedText(
                    capabilities.bluetoothAdvertisementScanning,
                  ),
                  state: capabilities.bluetoothAdvertisementScanning,
                ),
                _StatusFact(
                  label: localizations.backgroundAdvertisementScanning,
                  value: _supportedText(
                    capabilities.backgroundAdvertisementScanning,
                  ),
                  state: capabilities.backgroundAdvertisementScanning,
                ),
                _StatusFact(
                  label: localizations.continuousBackgroundScanningGuaranteed,
                  value: _supportedText(
                    capabilities.continuousBackgroundScanningGuaranteed,
                  ),
                  state: capabilities.continuousBackgroundScanningGuaranteed,
                ),
                _StatusFact(
                  label: localizations.relaunchAfterUserForceQuit,
                  value: _supportedText(
                    capabilities.relaunchAfterUserForceQuit,
                  ),
                  state: capabilities.relaunchAfterUserForceQuit,
                ),
                _StatusFact(
                  label: localizations.manufacturerDataOnRegionEvents,
                  value: _supportedText(
                    capabilities.manufacturerDataOnRegionEvents,
                  ),
                  state: capabilities.manufacturerDataOnRegionEvents,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusExpansion({
    required Key key,
    required IconData icon,
    required String title,
    required String summary,
    required List<Widget> children,
  }) {
    return ExpansionTile(
      key: key,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 10),
      minTileHeight: 48,
      leading: Icon(icon, size: 20),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
      shape: const Border(),
      collapsedShape: const Border(),
      children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth >= 600
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 8,
              children: children
                  .map((child) => SizedBox(width: itemWidth, child: child))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEventCard(BeaconEvent event) {
    final theme = Theme.of(context);
    final expanded = _expandedEvents.contains(event);
    final color = _eventColor(event.type, theme.colorScheme);
    final details = _eventDetails(event);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: () {
              setState(() {
                expanded
                    ? _expandedEvents.remove(event)
                    : _expandedEvents.add(event);
              });
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(_eventIcon(event.type), color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _eventTypeLabel(event.type),
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _eventSummary(event),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyEvent(event),
                    tooltip: localizations.copy,
                    icon: const Icon(Icons.copy_outlined, size: 20),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          if (expanded) ...<Widget>[
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (details.isNotEmpty)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = constraints.maxWidth >= 560
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          children: details
                              .map(
                                (detail) => SizedBox(
                                  width: itemWidth,
                                  child: _DetailField(detail: detail),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  if (details.isNotEmpty) const SizedBox(height: 16),
                  Text(
                    localizations.rawData,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      _encoder.convert(event.toMap()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_EventDetail> _eventDetails(BeaconEvent event) {
    final reading = event.reading;
    final manufacturer = event.manufacturerData;
    final details = <_EventDetail>[
      _EventDetail(localizations.source, _sourceLabel(event.source)),
      _EventDetail(localizations.timestamp, _formatTimestamp(event.timestamp)),
    ];
    if (event.regionIdentifier != null) {
      details.add(_EventDetail(localizations.region, event.regionIdentifier!));
    }
    if (event.state != BeaconRegionState.unknown) {
      details.add(_EventDetail(localizations.state, event.state.name));
    }
    if (reading != null) {
      details.add(
        _EventDetail(
          localizations.reading,
          '${reading.major}/${reading.minor}  ·  RSSI ${reading.rssi} dBm  ·  '
          'TX ${reading.txPower} dBm',
        ),
      );
    }
    if (manufacturer != null) {
      details.add(
        _EventDetail(
          localizations.manufacturerData,
          '0x${manufacturer.manufacturerId.toRadixString(16).padLeft(4, '0').toUpperCase()}  ·  '
          '${manufacturer.bytes.length} bytes  ·  ${manufacturer.hex}',
        ),
      );
    }
    if (event.latitude != null && event.longitude != null) {
      details.add(
        _EventDetail(
          localizations.location,
          '${event.latitude!.toStringAsFixed(6)}, '
          '${event.longitude!.toStringAsFixed(6)}'
          '${event.accuracy == null ? '' : '  ·  ±${event.accuracy!.toStringAsFixed(1)} m'}',
        ),
      );
    }
    if (event.message != null && event.message!.isNotEmpty) {
      details.add(_EventDetail(localizations.message, event.message!));
    }
    return details;
  }

  String _eventSummary(BeaconEvent event) {
    final values = <String>[
      _sourceLabel(event.source),
      _formatTimestamp(event.timestamp),
    ];
    if (event.regionIdentifier != null) {
      values.add('${localizations.region}: ${event.regionIdentifier}');
    }
    final reading = event.reading;
    if (reading != null) {
      values.add('${reading.major}/${reading.minor} · ${reading.rssi} dBm');
    } else if (event.message != null && event.message!.isNotEmpty) {
      values.add(event.message!);
    }
    return values.join('  ·  ');
  }

  String _eventTypeLabel(BeaconEventType type) {
    return switch (type) {
      BeaconEventType.monitoringStarted => localizations.monitoringStarted,
      BeaconEventType.monitoringStopped => localizations.monitoringStopped,
      BeaconEventType.regionEntered => localizations.regionEntered,
      BeaconEventType.regionExited => localizations.regionExited,
      BeaconEventType.regionStateChanged => localizations.regionStateChanged,
      BeaconEventType.beaconRanged => localizations.beaconRanged,
      BeaconEventType.advertisementDiscovered =>
        localizations.advertisementDiscovered,
      BeaconEventType.error => localizations.error,
      BeaconEventType.unknown => localizations.unknown,
    };
  }

  String _sourceLabel(BeaconEventSource source) {
    return switch (source) {
      BeaconEventSource.androidBle => 'Android BLE',
      BeaconEventSource.coreLocation => 'Core Location',
      BeaconEventSource.coreBluetooth => 'CoreBluetooth',
      BeaconEventSource.system => localizations.system,
      BeaconEventSource.unknown => localizations.unknown,
    };
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    String threeDigits(int value) => value.toString().padLeft(3, '0');
    return '${twoDigits(local.hour)}:${twoDigits(local.minute)}:'
        '${twoDigits(local.second)}.${threeDigits(local.millisecond)}';
  }

  String _enabledText(bool value) {
    return value ? localizations.enabled : localizations.disabled;
  }

  String _supportedText(bool value) {
    return value ? localizations.supported : localizations.unsupported;
  }

  IconData _eventIcon(BeaconEventType type) {
    return switch (type) {
      BeaconEventType.monitoringStarted => Icons.play_arrow,
      BeaconEventType.monitoringStopped => Icons.stop,
      BeaconEventType.regionEntered => Icons.login,
      BeaconEventType.regionExited => Icons.logout,
      BeaconEventType.regionStateChanged => Icons.my_location,
      BeaconEventType.beaconRanged => Icons.radar,
      BeaconEventType.advertisementDiscovered => Icons.bluetooth_searching,
      BeaconEventType.error => Icons.error_outline,
      BeaconEventType.unknown => Icons.help_outline,
    };
  }

  Color _eventColor(BeaconEventType type, ColorScheme colors) {
    return switch (type) {
      BeaconEventType.monitoringStarted ||
      BeaconEventType.regionEntered => Colors.green.shade700,
      BeaconEventType.monitoringStopped ||
      BeaconEventType.regionExited => Colors.orange.shade800,
      BeaconEventType.error => colors.error,
      BeaconEventType.beaconRanged ||
      BeaconEventType.advertisementDiscovered => Colors.blue.shade700,
      BeaconEventType.regionStateChanged => Colors.teal.shade700,
      BeaconEventType.unknown => colors.onSurfaceVariant,
    };
  }

  Future<void> _copyEvent(BeaconEvent event) {
    return Clipboard.setData(
      ClipboardData(text: _encoder.convert(event.toMap())),
    );
  }

  Future<void> _copyEvents() {
    final allEvents = <BeaconEvent>[
      ...controller.liveEvents,
      ...controller.events,
    ];
    return Clipboard.setData(
      ClipboardData(
        text: _encoder.convert(
          allEvents.map((event) => event.toMap()).toList(),
        ),
      ),
    );
  }
}

final class _StatusMetric extends StatelessWidget {
  const _StatusMetric({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    this.active,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final bool? active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active == null
        ? theme.colorScheme.primary
        : active!
        ? Colors.green.shade700
        : theme.colorScheme.onSurfaceVariant;
    return SizedBox(
      width: width,
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _StatusFact extends StatelessWidget {
  const _StatusFact({required this.label, required this.value, this.state});

  final String label;
  final String value;
  final bool? state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = state == null
        ? Icons.schedule
        : state!
        ? Icons.check_circle_outline
        : Icons.cancel_outlined;
    final color = state == null
        ? theme.colorScheme.onSurfaceVariant
        : state!
        ? Colors.green.shade700
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

final class _EventDetail {
  const _EventDetail(this.label, this.value);

  final String label;
  final String value;
}

final class _DetailField extends StatelessWidget {
  const _DetailField({required this.detail});

  final _EventDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          detail.label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        SelectableText(detail.value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

final class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 36, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
