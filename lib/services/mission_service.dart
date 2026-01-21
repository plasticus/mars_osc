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
      minShieldLevel: 0,
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
      newMissions.add(_generateMissionForShip(ship, relayLevel));
    }

    // 2. Fill the rest with random missions
    int remaining = count - newMissions.length;
    for (int i = 0; i < remaining; i++) {
      String shipClass = _getRandomClass(relayLevel);
      double distance = double.parse(_getRandomDistance(shipClass).toStringAsFixed(2));

      int minShield = _random.nextInt(relayLevel + 1); 
      int minCargo = _generateCargoRequirement(shipClass, relayLevel);
      
      var rewards = _calculateRewards(shipClass, distance, minCargo);

      newMissions.add(Mission(
        id: "rand_${DateTime.now().millisecondsSinceEpoch}_$i",
        title: "$shipClass Contract #${_random.nextInt(9999)}",
        description: _getDescription(shipClass),
        requiredClass: shipClass,
        distanceAU: distance,
        minShieldLevel: minShield,
        minCargo: minCargo,
        rewardSolars: rewards['solars'] as int,
        rewardResource: rewards['resource'] as String?,
        rewardResourceAmount: rewards['amount'] as int,
        baseDurationMinutes: max(1, (distance * 2).toInt()),
      ));
    }

    if (!newMissions.any((m) => m.title.contains("Local Scrap Run"))) {
      newMissions.add(getLocalScrapRun());
    }

    return newMissions;
  }

  Mission _generateMissionForShip(Ship ship, int relayLevel) {
    double rawDistance = _getRandomDistance(ship.shipClass);
    double distance = double.parse(min(rawDistance, ship.fuelCapacity * 10.0).toStringAsFixed(2));
    
    var rewards = _calculateRewards(ship.shipClass, distance, ship.cargoCapacity);

    return Mission(
      id: "tailored_${ship.id}_${DateTime.now().millisecondsSinceEpoch}",
      title: "${ship.shipClass} Spec #${_random.nextInt(9999)}",
      description: "Direct contract for ship: ${ship.nickname}.",
      requiredClass: ship.shipClass,
      distanceAU: distance,
      minShieldLevel: ship.shieldLevel,
      minCargo: ship.cargoCapacity,
      rewardSolars: rewards['solars'] as int,
      rewardResource: rewards['resource'] as String?,
      rewardResourceAmount: rewards['amount'] as int,
      baseDurationMinutes: max(1, (distance * 2).toInt()),
    );
  }

  Map<String, dynamic> _calculateRewards(String shipClass, double distance, int cargoLoad) {
    // Base Calculation
    int value = (distance * 100).toInt() + (cargoLoad * 20);
    int variance = _random.nextInt(50);
    int totalValue = value + variance;

    if (shipClass == 'Miner') {
      return {
        'solars': 0,
        'resource': 'Ore',
        'amount': max(5, (totalValue / 10).toInt()), // Ore is worth ~10 Solars
      };
    } else if (shipClass == 'Tanker') {
      // Tankers can do hauling (Solars) OR gas harvesting
      if (_random.nextBool()) {
        return {
          'solars': 0,
          'resource': 'Gas',
          'amount': max(2, (totalValue / 25).toInt()), // Gas is worth ~25 Solars
        };
      }
    } else if (shipClass == 'Harvester') {
      return {
        'solars': 0,
        'resource': 'Crystals',
        'amount': max(1, (totalValue / 100).toInt()), // Crystals worth ~100 Solars
      };
    }

    // Default: Cash Contract
    return {
      'solars': totalValue,
      'resource': null,
      'amount': 0,
    };
  }

  String _getDescription(String shipClass) {
    switch (shipClass) {
      case 'Miner': return "Asteroid belt mining operation.";
      case 'Tanker': return "Nebula gas siphon run.";
      case 'Harvester': return "Deep rift anomaly harvest.";
      default: return "Standard cargo delivery contract.";
    }
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

  int _generateCargoRequirement(String shipClass, int techLevel) {
    int base = 1;
    int variance = 1;

    switch (shipClass) {
      case 'Mule':
        variance = 5 + (techLevel * 3); 
        break;
      case 'Sprinter':
        variance = 2 + techLevel;
        break;
      case 'Tanker':
        variance = 3 + techLevel;
        break;
      case 'Miner':
        base = 2;
        variance = 4 + (techLevel * 2);
        break;
      case 'Harvester':
        base = 1;
        variance = 3 + techLevel;
        break;
    }
    return min(20, base + _random.nextInt(variance));
  }
}
