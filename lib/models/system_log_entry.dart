/// A single line from the OpenWrt system log (`ubus call log read`).
class SystemLogEntry {
  final int time; // unix seconds
  final String message;

  const SystemLogEntry({required this.time, required this.message});

  factory SystemLogEntry.fromJson(Map<String, dynamic> json) {
    final msg = json['msg'] ?? json['message'] ?? json['text'] ?? '';
    return SystemLogEntry(
      time: (json['time'] is num) ? (json['time'] as num).toInt() : 0,
      message: msg.toString(),
    );
  }

  String? get formattedTime {
    if (time <= 0) return null;
    final date = DateTime.fromMillisecondsSinceEpoch(time * 1000).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }
}
