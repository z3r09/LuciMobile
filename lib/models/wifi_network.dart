/// A nearby wireless network returned by `luci-rpc getWifiScan`.
class WiFiNetwork {
  final String ssid;
  final String? bssid;
  final int channel;
  final int signal; // dBm (negative value)
  final int quality; // 0-100
  final String security;
  final String mode;

  const WiFiNetwork({
    required this.ssid,
    this.bssid,
    this.channel = 0,
    this.signal = 0,
    this.quality = 0,
    this.security = 'Open',
    this.mode = 'N/A',
  });

  factory WiFiNetwork.fromJson(Map<String, dynamic> json) {
    final enc = json['encryption'] ?? json['security'] ?? 'Open';
    final ssid = (json['ssid'] ?? '').toString();
    return WiFiNetwork(
      ssid: ssid.isEmpty ? '(Hidden)' : ssid,
      bssid: json['bssid']?.toString(),
      channel: _toInt(json['channel']),
      signal: _toInt(json['signal']),
      quality: _toInt(json['quality']),
      security: enc.toString(),
      mode: json['mode']?.toString() ?? 'N/A',
    );
  }

  static int _toInt(dynamic v) => v is num ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? 0);

  String get signalLabel => signal == 0 ? 'N/A' : '$signal dBm';

  /// Rough visual signal quality derived from RSSI.
  double get signalBars {
    if (signal >= -50) return 1.0;
    if (signal >= -60) return 0.75;
    if (signal >= -70) return 0.5;
    if (signal >= -80) return 0.25;
    return 0.1;
  }
}
