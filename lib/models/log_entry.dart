class LogEntry {
  final DateTime timestamp;
  final String title;
  final String details;
  final int solarChange;
  final bool isPositive;
  final int oreSold;
  final int gasSold;
  final int crystalsSold;
  final double distance;
  final int tradeDepotLevel;

  LogEntry({
    required this.timestamp,
    required this.title,
    required this.details,
    this.solarChange = 0,
    this.isPositive = false,
    this.oreSold = 0,
    this.gasSold = 0,
    this.crystalsSold = 0,
    this.tradeDepotLevel = 1,
    this.distance = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'title': title,
    'details': details,
    'solarChange': solarChange,
    'isPositive': isPositive,
    'oreSold': oreSold,
    'gasSold': gasSold,
    'crystalsSold': crystalsSold,
    'tradeDepotLevel': tradeDepotLevel,
    'distance': distance,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp']),
      title: json['title'],
      details: json['details'],
      solarChange: json['solarChange'] ?? 0,
      isPositive: json['isPositive'] ?? false,
      oreSold: json['oreSold'] ?? 0,
      gasSold: json['gasSold'] ?? 0,
      crystalsSold: json['crystalsSold'] ?? 0,
      tradeDepotLevel: json['tradeDepotLevel'] ?? 1,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0, // ✅ ADD THIS LINE
    );
  }
}