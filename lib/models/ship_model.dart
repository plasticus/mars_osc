class Ship {
  final String id;
  String nickname;
  final String modelName;
  final String shipClass;

  int speed;
  int cargoCapacity;
  int fuelCapacity;
  int shieldLevel;
  int aiLevel;

  double condition;
  DateTime? missionStartTime;
  DateTime? missionEndTime;
  int pendingReward; // Added this to track payout
  bool isRepairing;

  Ship({
    required this.id,
    required this.nickname,
    required this.modelName,
    required this.shipClass,
    required this.speed,
    required this.cargoCapacity,
    required this.fuelCapacity,
    required this.shieldLevel,
    required this.aiLevel,
    this.condition = 1.0,
    this.isRepairing = false,
    this.missionStartTime,
    this.missionEndTime,
    this.pendingReward = 0,
  });
}
