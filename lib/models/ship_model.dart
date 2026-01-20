class Ship {
  final String id;
  String nickname;
  final String modelName;
  final String shipClass;

  // Current Stats
  int speed;
  int cargoCapacity;
  int fuelCapacity;
  int shieldLevel;
  int aiLevel;

  // Max Stats (for upgrades)
  final int maxSpeed;
  final int maxCargo;
  final int maxFuel;
  final int maxShield;
  final int maxAI;

  double condition;
  
  // Mission/Task timing
  DateTime? missionStartTime;
  DateTime? missionEndTime;
  
  DateTime? busyUntil;
  String? currentTask; // 'Repairing', 'Upgrading'

  int pendingReward;
  bool isRepairing; // Keeping this for legacy, but will use currentTask moving forward

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
    required this.maxSpeed,
    required this.maxCargo,
    required this.maxFuel,
    required this.maxShield,
    required this.maxAI,
    this.condition = 1.0,
    this.isRepairing = false,
    this.missionStartTime,
    this.missionEndTime,
    this.busyUntil,
    this.currentTask,
    this.pendingReward = 0,
  });
}
