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
  double? missionDistance; // Stored for wear calc
  
  DateTime? busyUntil;
  String? currentTask; // 'Repairing', 'Upgrading'

  int pendingReward;
  String? pendingResource; // 'Ore', 'Gas', 'Crystals'
  int pendingResourceAmount;

  bool isRepairing;
  bool hasBeenRenamed;

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
    this.hasBeenRenamed = false,
    this.missionStartTime,
    this.missionEndTime,
    this.missionDistance,
    this.busyUntil,
    this.currentTask,
    this.pendingReward = 0,
    this.pendingResource,
    this.pendingResourceAmount = 0,
  });

  bool get isMaxed => 
      speed >= maxSpeed &&
      cargoCapacity >= maxCargo &&
      fuelCapacity >= maxFuel &&
      shieldLevel >= maxShield &&
      aiLevel >= maxAI;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'modelName': modelName,
      'shipClass': shipClass,
      'speed': speed,
      'cargoCapacity': cargoCapacity,
      'fuelCapacity': fuelCapacity,
      'shieldLevel': shieldLevel,
      'aiLevel': aiLevel,
      'maxSpeed': maxSpeed,
      'maxCargo': maxCargo,
      'maxFuel': maxFuel,
      'maxShield': maxShield,
      'maxAI': maxAI,
      'condition': condition,
      'missionStartTime': missionStartTime?.toIso8601String(),
      'missionEndTime': missionEndTime?.toIso8601String(),
      'missionDistance': missionDistance,
      'busyUntil': busyUntil?.toIso8601String(),
      'currentTask': currentTask,
      'pendingReward': pendingReward,
      'pendingResource': pendingResource,
      'pendingResourceAmount': pendingResourceAmount,
      'isRepairing': isRepairing,
      'hasBeenRenamed': hasBeenRenamed,
    };
  }

  factory Ship.fromJson(Map<String, dynamic> json) {
    return Ship(
      id: json['id'],
      nickname: json['nickname'],
      modelName: json['modelName'],
      shipClass: json['shipClass'],
      speed: json['speed'],
      cargoCapacity: json['cargoCapacity'],
      fuelCapacity: json['fuelCapacity'],
      shieldLevel: json['shieldLevel'],
      aiLevel: json['aiLevel'],
      maxSpeed: json['maxSpeed'],
      maxCargo: json['maxCargo'],
      maxFuel: json['maxFuel'],
      maxShield: json['maxShield'],
      maxAI: json['maxAI'],
      condition: json['condition'].toDouble(),
      missionStartTime: json['missionStartTime'] != null ? DateTime.parse(json['missionStartTime']) : null,
      missionEndTime: json['missionEndTime'] != null ? DateTime.parse(json['missionEndTime']) : null,
      missionDistance: json['missionDistance']?.toDouble(),
      busyUntil: json['busyUntil'] != null ? DateTime.parse(json['busyUntil']) : null,
      currentTask: json['currentTask'],
      pendingReward: json['pendingReward'],
      pendingResource: json['pendingResource'],
      pendingResourceAmount: json['pendingResourceAmount'] ?? 0,
      isRepairing: json['isRepairing'] ?? false,
      hasBeenRenamed: json['hasBeenRenamed'] ?? false,
    );
  }
}
