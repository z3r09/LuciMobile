import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:luci_mobile/main.dart';
import 'package:luci_mobile/state/app_state.dart';
import 'package:luci_mobile/widgets/luci_app_bar.dart';
import 'package:luci_mobile/design/luci_design_system.dart';

/// Reads the OpenWrt system log via `ubus call log read`.
class SystemLogScreen extends ConsumerStatefulWidget {
  const SystemLogScreen({super.key});

  @override
  ConsumerState<SystemLogScreen> createState() => _SystemLogScreenState();
}

class _SystemLogScreenState extends ConsumerState<SystemLogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appStateProvider).fetchSystemLog();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStateProvider);
    final log = app.systemLog;
    return Scaffold(
      appBar: const LuciAppBar(title: 'System Log'),
      body: RefreshIndicator(
        onRefresh: () => ref.read(appStateProvider).fetchSystemLog(),
        child: log.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 220),
                  Center(
                    child: Text(
                      app.isSystemLogLoading ? 'Loading log…' : 'No log entries',
                      style: LuciTextStyles.cardSubtitle(context),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: log.length,
                itemBuilder: (context, i) {
                  final entry = log[i];
                  return ListTile(
                    dense: true,
                    minVerticalPadding: LuciSpacing.xs,
                    leading: Text(
                      entry.formattedTime ?? '',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    title: Text(
                      entry.message,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
