import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/models/system_info.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/state/app_state.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';
import 'package:luci_mobile/design/luci_design_system.dart';

/// Live system overview: device, firmware, kernel, uptime, load,
/// memory usage plus quick service-control actions.
/// Uses data already available from `system.board` / `system.info` /
/// `luci-rpc.getRealtimeStats` on modern OpenWrt.
class SystemStatusScreen extends ConsumerStatefulWidget {
  const SystemStatusScreen({super.key});

  @override
  ConsumerState<SystemStatusScreen> createState() => _SystemStatusScreenState();
}

class _SystemStatusScreenState extends ConsumerState<SystemStatusScreen> {
  Timer? _realtimeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = ref.read(appStateProvider);
      app.fetchSystemInfo();
      app.fetchRealtimeStats();
    });
    // Keep the free-memory + load numbers fresh.
    _realtimeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(appStateProvider).fetchRealtimeStats();
    });
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final info = app.systemInfo;
    return Scaffold(
      appBar: const LuciAppBar(title: 'System'),
      body: RefreshIndicator(
        onRefresh: () async {
          final a = ref.read(appStateProvider);
          await a.fetchSystemInfo();
          await a.fetchRealtimeStats();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(LuciSpacing.md),
          children: [
            if (app.isSystemInfoLoading)
              const LinearProgressIndicator()
            else if (info == null || !info.hasData)
              const _EmptyCard('No system data available. Pull to refresh.')
            else ...[
              _SystemInfoCard(info: info),
              _MemoryCard(info: info, realtime: app.realtimeStats),
              _ActionsCard(
                onRestartService: _showServiceRestartDialog,
                onReloadWireless: _reloadWireless,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showServiceRestartDialog() async {
    final controller = TextEditingController(text: 'firewall');
    final service = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Service'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Service (dnsmasq, firewall, network, odhcpd)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (service == null || service.isEmpty || !mounted) return;
    final ok = await ref.read(appStateProvider).restartService(service);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Restart sent for $service' : 'Failed to restart $service'),
      ),
    );
  }

  Future<void> _reloadWireless() async {
    final ok = await ref.read(appStateProvider).reloadWireless();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Wireless reloaded' : 'Failed to reload wireless')),
    );
  }
}

class _SystemInfoCard extends StatelessWidget {
  final SystemInfo info;
  const _SystemInfoCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: LuciSpacing.sm),
      shape: RoundedRectangleBorder(borderRadius: LuciCardStyles.standardRadius),
      child: Padding(
        padding: const EdgeInsets.all(LuciSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow('Hostname', info.hostname ?? 'N/A'),
            _InfoRow('Model', info.model ?? 'N/A'),
            _InfoRow(
              'Firmware',
              info.firmwareVersion ?? 'N/A',
              bold: true,
              color: Theme.of(context).colorScheme.primary,
            ),
            _InfoRow('Kernel', info.kernel ?? 'N/A'),
            _InfoRow('Uptime', info.formattedUptime),
            _InfoRow('Load (1/5/15m)', info.loadLabel),
          ],
        ),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final SystemInfo info;
  final Map<String, dynamic>? realtime;
  const _MemoryCard({required this.info, this.realtime});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final used = info.memoryUsed;
    final total = info.memoryTotal;
    double percent = info.memoryUsagePercent;
    String freeText;
    if (realtime?['memfree'] is num && total > 0) {
      final free = (realtime!['memfree'] as num).toInt();
      percent = ((total - free) / total).clamp(0.0, 1.0);
      freeText = '${SystemInfo.formatBytes(free)} free';
    } else {
      freeText = '${SystemInfo.formatBytes(info.memoryFree)} free';
    }
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: LuciSpacing.sm),
      shape: RoundedRectangleBorder(borderRadius: LuciCardStyles.standardRadius),
      child: Padding(
        padding: const EdgeInsets.all(LuciSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Memory',
              style: LuciTextStyles.cardTitle(context).copyWith(fontSize: 15),
            ),
            const SizedBox(height: LuciSpacing.sm),
            LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: scheme.surfaceContainerHighest,
            ),
            const SizedBox(height: LuciSpacing.sm),
            Text(
              '${SystemInfo.formatBytes(used)} used of '
              '${SystemInfo.formatBytes(total)}  •  $freeText',
              style: LuciTextStyles.cardSubtitle(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  final VoidCallback onRestartService;
  final VoidCallback onReloadWireless;
  const _ActionsCard({
    required this.onRestartService,
    required this.onReloadWireless,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: LuciSpacing.sm),
      shape: RoundedRectangleBorder(borderRadius: LuciCardStyles.standardRadius),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.engineering_outlined, color: scheme.primary),
            title: Text('Restart Service',
                style: LuciTextStyles.cardTitle(context)),
            subtitle: Text('Firewall, DNS, DHCP, network…',
                style: LuciTextStyles.cardSubtitle(context)),
            trailing: const Icon(Icons.chevron_right),
            onTap: onRestartService,
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          ListTile(
            leading: Icon(Icons.wifi_tethering, color: scheme.primary),
            title: Text('Reload Wireless',
                style: LuciTextStyles.cardTitle(context)),
            subtitle: Text('Apply wireless config without dropping LAN',
                style: LuciTextStyles.cardSubtitle(context)),
            trailing: const Icon(Icons.chevron_right),
            onTap: onReloadWireless,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _InfoRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LuciSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: LuciTextStyles.detailLabel(context)),
          ),
          const SizedBox(width: LuciSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: bold
                  ? LuciTextStyles.detailValue(context).copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    )
                  : LuciTextStyles.detailValue(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 160),
      child: Center(
        child: Text(message, style: LuciTextStyles.cardSubtitle(context)),
      ),
    );
  }
}

