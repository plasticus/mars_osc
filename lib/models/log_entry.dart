class LogEntry {
  final DateTime timestamp;
  final String title;
  final String details;
  final int? solarChange;
  final bool isPositive;

  LogEntry({
    required this.timestamp,
    required this.title,
    required this.details,
    this.solarChange,
    this.isPositive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'details': details,
      'solarChange': solarChange,
      'isPositive': isPositive,
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp']),
      title: json['title'],
      details: json['details'],
      solarChange: json['solarChange'],
      isPositive: json['isPositive'],
    );
  }
}