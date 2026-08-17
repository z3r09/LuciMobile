import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/models/wifi_network.dart';
import 'package:luci_mobile/models/wireless_station.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/state/app_state.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';
import 'package:luci_mobile/design/luci_design_system.dart';

/// WiFi: connected wireless clients with live signal strength (RSSI) and
/// a channel scanner of nearby networks (OpenWrt 22.03+ luci-rpc).
class WifiScreen extends ConsumerStatefulWidget {
  const WifiScreen({super.key});

  @override
  ConsumerState<WifiScreen> createState() => _WifiScreenState();
}

class _WifiScreenState extends ConsumerState<WifiScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = ref.read(appStateProvider);
      app.fetchWirelessStations();
      app.fetchWifiScan();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    return Scaffold(
      appBar: const LuciAppBar(title: 'WiFi'),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [Tab(text: 'Clients'), Tab(text: 'Scan')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ClientsTab(app: app),
                _ScanTab(app: app),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientsTab extends StatelessWidget {
  final AppState app;
  const _ClientsTab({required this.app});

  @override
  Widget build(BuildContext context) {
    final stations = app.allWirelessStations;
    if (app.isWifiLoading && stations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (stations.isEmpty) {
      return Center(
        child: Text(
          'No wireless clients connected.',
          style: LuciTextStyles.cardSubtitle(context),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => app.fetchWirelessStations(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: stations.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
        itemBuilder: (context, i) => _StationTile(station: stations[i]),
      ),
    );
  }
}

class _StationTile extends StatelessWidget {
  final WirelessStation station;
  const _StationTile({required this.station});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = station.hostname?.isNotEmpty == true
        ? station.hostname!
        : station.macAddress;
    return ListTile(
      leading: Icon(
        Icons.wifi,
        color: scheme.primary.withValues(alpha: 0.3 + 0.7 * station.signalBars),
      ),
      title: Text(title, style: LuciTextStyles.cardTitle(context)),
      subtitle: Text(
        '${station.macAddress}  •  ${station.signalLabel}  •  '
        '${station.txRate}↓/${station.rxRate}↑ Mbps  •  ${station.connectedLabel}',
        style: LuciTextStyles.cardSubtitle(context),
      ),
      trailing: _SignalBadge(label: station.signalLabel),
    );
  }
}

class _ScanTab extends StatelessWidget {
  final AppState app;
  const _ScanTab({required this.app});

  @override
  Widget build(BuildContext context) {
    final networks = app.wifiScan;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(LuciSpacing.md),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  app.isWifiLoading ? null : () => app.fetchWifiScan(),
              icon: app.isWifiLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.radar),
              label: const Text('Scan for networks'),
            ),
          ),
        ),
        Expanded(
          child: networks.isEmpty
              ? Center(
                  child: Text(
                    app.isWifiLoading
                        ? 'Scanning…'
                        : 'No networks found. Tap Scan to start.',
                    style: LuciTextStyles.cardSubtitle(context),
                  ),
                )
              : ListView.separated(
                  itemCount: networks.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (context, i) =>
                      _NetworkTile(network: networks[i]),
                ),
        ),
      ],
    );
  }
}

class _NetworkTile extends StatelessWidget {
  final WiFiNetwork network;
  const _NetworkTile({required this.network});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        Icons.wifi,
        color: scheme.primary.withValues(alpha: 0.3 + 0.7 * network.signalBars),
      ),
      title: Text(network.ssid, style: LuciTextStyles.cardTitle(context)),
      subtitle: Text(
        'Channel ${network.channel}  •  ${network.signalLabel}  •  '
        '${network.security}',
        style: LuciTextStyles.cardSubtitle(context),
      ),
      trailing: _SignalBadge(label: network.signalLabel),
    );
  }
}

class _SignalBadge extends StatelessWidget {
  final String label;
  const _SignalBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: scheme.textTheme.labelSmall?.copyWith(color: scheme.primary),
      ),
    );
  }
}
