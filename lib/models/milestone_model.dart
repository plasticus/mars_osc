class Milestone {
  final String id;
  final String title;
  final String description;
  final String? winnerName;
  final DateTime? wonAt;

  // A helper to determine if it's been claimed
  bool get isClaimed => winnerName != null && winnerName!.isNotEmpty;

  Milestone({
    required this.id,
    required this.title,
    required this.description,
    this.winnerName,
    this.wonAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'winnerName': winnerName,
    'wonAt': wonAt?.toIso8601String(),
  };

  factory Milestone.fromJson(Map<String, dynamic> json) {
    return Milestone(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      winnerName: json['winnerName'],
      wonAt: json['wonAt'] != null ? DateTime.parse(json['wonAt']) : null,
    );
  }
}