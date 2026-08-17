/// A wireless client currently associated with the router.
/// Returned by `luci-rpc getWirelessStations` (OpenWrt 22.03+).
class WirelessStation {
  final String macAddress;
  final int signal; // dBm (negative value)
  final int noise; // dBm
  final int txRate; // Mbps
  final int rxRate; // Mbps
  final int connectedTime; // seconds
  final String? hostname;

  const WirelessStation({
    required this.macAddress,
    this.signal = 0,
    this.noise = 0,
    this.txRate = 0,
    this.rxRate = 0,
    this.connectedTime = 0,
    this.hostname,
  });

  factory WirelessStation.fromJson(dynamic raw) {
    if (raw is String) {
      return WirelessStation(macAddress: raw);
    }
    final json = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return WirelessStation(
      macAddress: (json['mac'] ?? json['macaddr'] ?? json['station'] ?? 'Unknown').toString(),
      signal: _toInt(json['signal']),
      noise: _toInt(json['noise']),
      txRate: _toInt(json['txrate']),
      rxRate: _toInt(json['rxrate']),
      connectedTime: _toInt(json['connected']),
      hostname: json['hostname']?.toString(),
    );
  }

  static int _toInt(dynamic v) => v is num ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? 0);

  String get signalLabel => signal == 0 ? 'N/A' : '$signal dBm';

  /// Rough visual signal strength derived from RSSI.
  double get signalBars {
    if (signal >= -50) return 1.0;
    if (signal >= -60) return 0.75;
    if (signal >= -70) return 0.5;
    if (signal >= -80) return 0.25;
    return 0.1;
  }

  String get connectedLabel {
    if (connectedTime <= 0) return 'N/A';
    final d = Duration(seconds: connectedTime);
    final mins = d.inMinutes;
    if (mins < 1) return '<1m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}
