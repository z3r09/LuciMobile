/// Aggregated system status pulled from OpenWrt's `system.board` and
/// `system.info` ubus objects (available on OpenWrt 22.03+ / 23.05 / 24.10).
class SystemInfo {
  final String? hostname;
  final String? model;
  final String? firmwareVersion;
  final String? kernel;
  final String? boardName;
  final String? system;
  final int uptimeSeconds;
  final List<double> loadAverage;
  final int memoryTotal; // bytes
  final int memoryFree; // bytes
  final int memoryBuffered; // bytes
  final int memoryCached; // bytes
  final int memoryShared; // bytes

  const SystemInfo({
    this.hostname,
    this.model,
    this.firmwareVersion,
    this.kernel,
    this.boardName,
    this.system,
    this.uptimeSeconds = 0,
    this.loadAverage = const [],
    this.memoryTotal = 0,
    this.memoryFree = 0,
    this.memoryBuffered = 0,
    this.memoryCached = 0,
    this.memoryShared = 0,
  });

  factory SystemInfo.fromBoardAndInfo(
    Map<String, dynamic>? boardInfo,
    Map<String, dynamic>? sysInfo,
  ) {
    final release = boardInfo?['release'];
    final releaseMap = release is Map
        ? Map<String, dynamic>.from(release)
        : <String, dynamic>{};
    var firmware = releaseMap['description']?.toString();
    if (firmware == null || firmware.isEmpty) {
      final dist = releaseMap['distribution']?.toString() ?? '';
      final ver = releaseMap['version']?.toString() ?? '';
      firmware = '$dist $ver'.trim();
    }

    final memory = sysInfo?['memory'];
    final memoryMap = memory is Map
        ? Map<String, dynamic>.from(memory)
        : <String, dynamic>{};

    final load = sysInfo?['load'];
    final loadList = load is List
        ? load.whereType<num>().map((e) => e.toDouble()).toList()
        : <double>[];

    return SystemInfo(
      hostname: boardInfo?['hostname']?.toString(),
      model: boardInfo?['model']?.toString(),
      firmwareVersion: (firmware == null || firmware.isEmpty) ? null : firmware,
      kernel: boardInfo?['kernel']?.toString(),
      boardName: boardInfo?['board_name']?.toString(),
      system: boardInfo?['system']?.toString(),
      uptimeSeconds: _toInt(sysInfo?['uptime']),
      loadAverage: loadList,
      memoryTotal: _toInt(memoryMap['total']),
      memoryFree: _toInt(memoryMap['free']),
      memoryBuffered: _toInt(memoryMap['buffered']),
      memoryCached: _toInt(memoryMap['cached']),
      memoryShared: _toInt(memoryMap['shared']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  bool get hasData => hostname != null || model != null;

  int get memoryUsed {
    final used = memoryTotal - memoryFree;
    return used < 0 ? 0 : used;
  }

  double get memoryUsagePercent =>
      memoryTotal <= 0 ? 0 : (memoryUsed / memoryTotal).clamp(0.0, 1.0);

  double get load1 => loadAverage.isNotEmpty ? loadAverage[0] : 0;
  double get load5 => loadAverage.length > 1 ? loadAverage[1] : 0;
  double get load15 => loadAverage.length > 2 ? loadAverage[2] : 0;

  String get loadLabel {
    final parts = loadAverage.map((e) => e.toStringAsFixed(2)).toList();
    return parts.isEmpty ? 'N/A' : parts.join(' / ');
  }

  String get formattedUptime {
    if (uptimeSeconds <= 0) return 'N/A';
    final d = Duration(seconds: uptimeSeconds);
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0 || days > 0) parts.add('${hours}h');
    parts.add('${minutes}m');
    return parts.join(' ');
  }

  static String formatBytes(num bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    final val = size >= 100 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
    return '$val ${units[i]}';
  }
}
