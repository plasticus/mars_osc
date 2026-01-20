import 'dart:math';
import '../models/mission_model.dart';
import '../models/ship_model.dart';

class MissionService {
  final Random _random = Random();

  final Map<String, List<double>> _classDistances = {
    'Mule': [1.0, 3.0],
    'Sprinter': [1.5, 5.0],
    'Tanker': [5.0, 15.0],
    'Miner': [2.0, 8.0],
    'Harvester': [10.0, 30.0],
  };

  Mission getLocalScrapRun() {
    return Mission(
      id: "scrap_run_${DateTime.now().millisecondsSinceEpoch}",
      title: "Local Scrap Run (Mule)",
      description: "A simple run to the nearest debris field. Reliable but low pay.",
      requiredClass: "Mule",
      distanceAU: 0.50,
      minShieldLevel: 1,
      minCargo: 1,
      rewardSolars: 50,
      baseDurationMinutes: 1,
    );
  }

  List<Mission> generateMissions(int relayLevel, int broadcastingLevel, List<Ship> fleet) {
    int count = _getMissionCount(broadcastingLevel);
    List<Mission> newMissions = [];

    // 1. Generate missions tailored to the user's current ships
    for (var ship in fleet) {
      newMissions.add(_generateMissionForShip(ship));
    }

    // 2. Fill the rest with random missions based on relayLevel
    int remaining = count - newMissions.length;
    for (int i = 0; i < remaining; i++) {
      String shipClass = _getRandomClass(relayLevel);
      double distance = double.parse(_getRandomDistance(shipClass).toStringAsFixed(2));

      int baseReward = (distance * (100 + _random.nextInt(100))).toInt();
      if (shipClass == 'Harvester') baseReward *= 3;

      newMissions.add(Mission(
        id: "rand_${DateTime.now().millisecondsSinceEpoch}_$i",
        title: "$shipClass Contract #${_random.nextInt(9999)}",
        description: "Standard industrial contract for the $shipClass class.",
        requiredClass: shipClass,
        distanceAU: distance,
        minShieldLevel: _random.nextInt(relayLevel + 1),
        minCargo: (shipClass == 'Mule') ? 10 + _random.nextInt(10) : 1 + _random.nextInt(5),
        rewardSolars: baseReward,
        baseDurationMinutes: max(1, (distance * 2).toInt()),
      ));
    }

    if (!newMissions.any((m) => m.title.contains("Local Scrap Run"))) {
      newMissions.add(getLocalScrapRun());
    }

    return newMissions;
  }

  Mission _generateMissionForShip(Ship ship) {
    double rawDistance = _getRandomDistance(ship.shipClass);
    double distance = double.parse(min(rawDistance, ship.fuelCapacity * 10.0).toStringAsFixed(2));
    
    int baseReward = (distance * (150 + _random.nextInt(100))).toInt();
    if (ship.shipClass == 'Harvester') baseReward *= 3;

    return Mission(
      id: "tailored_${ship.id}_${DateTime.now().millisecondsSinceEpoch}",
      title: "${ship.shipClass} Spec #${_random.nextInt(9999)}",
      description: "Direct contract for ship: ${ship.nickname}.",
      requiredClass: ship.shipClass,
      distanceAU: distance,
      minShieldLevel: ship.shieldLevel,
      minCargo: ship.cargoCapacity,
      rewardSolars: baseReward,
      baseDurationMinutes: max(1, (distance * 2).toInt()),
    );
  }

  int _getMissionCount(int level) {
    if (level == 1) return 5;
    if (level == 2) return 10;
    if (level == 3) return 20;
    return 40;
  }

  String _getRandomClass(int scanLevel) {
    List<String> available = ['Mule', 'Sprinter'];
    if (scanLevel >= 2) available.add('Tanker');
    if (scanLevel >= 3) available.add('Miner');
    if (scanLevel >= 4) available.add('Harvester');
    return available[_random.nextInt(available.length)];
  }

  double _getRandomDistance(String shipClass) {
    List<double> range = _classDistances[shipClass] ?? [1.0, 5.0];
    return range[0] + _random.nextDouble() * (range[1] - range[0]);
  }
}
