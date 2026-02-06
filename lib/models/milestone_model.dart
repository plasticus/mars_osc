import 'package:flutter/material.dart';

class Milestone {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String? winnerName;
  final DateTime? wonAt;

  // A helper to determine if it's been claimed
  bool get isClaimed => winnerName != null && winnerName!.isNotEmpty;

  Milestone({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.winnerName,
    this.wonAt,
  });

  static IconData getIconFromString(String? name) {
    switch (name) {
      case 'bug_report': return Icons.bug_report;
      case 'badge': return Icons.badge;
      case 'monetization_on': return Icons.monetization_on;
      case 'account_balance': return Icons.account_balance;
      case 'local_shipping': return Icons.local_shipping;
      case 'anchor': return Icons.anchor;
      case 'bolt': return Icons.bolt;
      case 'precision_manufacturing': return Icons.precision_manufacturing;
      case 'ev_station': return Icons.ev_station;
      case 'auto_awesome': return Icons.auto_awesome;
      case 'groups': return Icons.groups;
      case 'explore': return Icons.explore;
      case 'layers': return Icons.layers;
      case 'air': return Icons.air;
      case 'diamond': return Icons.diamond;
      case 'castle': return Icons.castle;
      default: return Icons.help_outline;
    }
  }

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
      // Add this line to satisfy the constructor
      icon: Icons.emoji_events,
      winnerName: json['winnerName'],
      wonAt: json['wonAt'] != null ? DateTime.parse(json['wonAt']) : null,
    );
  }
}