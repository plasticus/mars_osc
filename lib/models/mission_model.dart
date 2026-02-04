import '../utils/game_formulas.dart';

class Mission {
  final String id;
  final String title;
  final String description;
  final String requiredClass;
  
  final double distanceAU;
  final int minShieldLevel;
  final int minCargo;
  
  final int rewardSolars;
  final String? rewardResource;
  final int rewardResourceAmount;

  final int baseDurationMinutes;

  Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredClass,
    required this.distanceAU,
    required this.minShieldLevel,
    required this.minCargo,
    required this.rewardSolars,
    this.rewardResource,
    this.rewardResourceAmount = 0,
    required this.baseDurationMinutes,
  });

  // 1. TO JSON (Save to disk)
  Map<String, dynamic> toJson() => {
      'id': id,
      'title': title,
      'description': description,
      'requiredClass': requiredClass,
      'distanceAU': distanceAU,
      'minShieldLevel': minShieldLevel,
      'minCargo': minCargo,
      'rewardSolars': rewardSolars,
      'rewardResource': rewardResource,
      'rewardResourceAmount': rewardResourceAmount,
      'baseDurationMinutes': baseDurationMinutes,
    };

  // 2. FROM JSON (Load from disk)
  factory Mission.fromJson(Map<String, dynamic> json) {
      return Mission(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        requiredClass: json['requiredClass'],
        distanceAU: (json['distanceAU'] as num).toDouble(),
        minShieldLevel: json['minShieldLevel'],
        minCargo: json['minCargo'],
        rewardSolars: json['rewardSolars'],
        rewardResource: json['rewardResource'],
        rewardResourceAmount: json['rewardResourceAmount'] ?? 0,
        baseDurationMinutes: json['baseDurationMinutes'] ?? 0,
      );
  }

  String? getMissingRequirement(dynamic ship) {
    if (ship.shipClass != requiredClass) return "Needs $requiredClass class";

    if (!GameFormulas.canRunMission(distanceAU, ship.fuelCapacity, ship.aiLevel)) {
      return "Insufficient Range (Fuel/AI)";
    }

    if (ship.shieldLevel < minShieldLevel) return "Shields too weak";
    if (ship.cargoCapacity < minCargo) return "Cargo bay too small";
    if (ship.condition < 0.25) return "Ship requires repairs";
    return null;
  }
}