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

  Mission getLocalCourierRun() {
    return Mission(
      id: "courier_run_${DateTime.now().millisecondsSinceEpoch}",
      title: "Local Courier Run (Sprinter)",
      description: "Urgent data stick delivery to nearby station. Quick turnaround.",
      requiredClass: "Sprinter",
      distanceAU: 0.75,
      minShieldLevel: 0,
      minCargo: 1,
      rewardSolars: 100,
      baseDurationMinutes: 1,
    );
  }

  List<Mission> generateMissions(int relayLevel, int broadcastingLevel, List<Ship> fleet) {
    List<Mission> newMissions = [];
    int missionsPerCategory = broadcastingLevel * 2;
    List<String> allCategories = ['Mule', 'Sprinter', 'Miner', 'Tanker', 'Harvester'];

    // 1. Generate missions tailored to the user's current ships
    for (var ship in fleet) {
      newMissions.add(_generateMissionForShip(ship, relayLevel));
    }

    // 2. Generate standard missions for each category
    for (String category in allCategories) {
      if (category == 'Miner' && relayLevel < 2) continue;
      if (category == 'Tanker' && relayLevel < 3) continue;
      if (category == 'Harvester' && relayLevel < 4) continue;

      for (int i = 0; i < missionsPerCategory; i++) {
        double distance = double.parse(_getRandomDistance(category).toStringAsFixed(2));
        int minShield = _random.nextInt(relayLevel + 1); 
        int minCargo = _generateCargoRequirement(category, relayLevel);
        var rewards = _calculateRewards(category, distance, minCargo);

        newMissions.add(Mission(
          id: "std_${category}_${DateTime.now().millisecondsSinceEpoch}_$i",
          title: "$category Contract #${_random.nextInt(9999)}",
          description: _getDescription(category),
          requiredClass: category,
          distanceAU: distance,
          minShieldLevel: minShield,
          minCargo: minCargo,
          rewardSolars: rewards['solars'] as int,
          rewardResource: rewards['resource'] as String?,
          rewardResourceAmount: rewards['amount'] as int,
          baseDurationMinutes: 0, // Calculated at launch based on speed
        ));
      }
    }

    if (!newMissions.any((m) => m.title.contains("Local Scrap Run"))) {
      newMissions.add(getLocalScrapRun());
    }
    if (!newMissions.any((m) => m.title.contains("Local Courier Run"))) {
      newMissions.add(getLocalCourierRun());
    }

    return newMissions;
  }

  Mission _generateMissionForShip(Ship ship, int relayLevel) {
    // Tailored Logic: Push limits of the ship
    double maxRange = ship.fuelCapacity * 10.0;
    
    // Target 70-95% of max range, or random class distance if it fits
    double rangeTarget = maxRange * (0.7 + (_random.nextDouble() * 0.25));
    double distance = double.parse(rangeTarget.toStringAsFixed(2));

    // Target 70-100% of Cargo
    int cargoTarget = (ship.cargoCapacity * (0.7 + (_random.nextDouble() * 0.3))).ceil();
    // Ensure at least 1
    cargoTarget = max(1, cargoTarget);

    var rewards = _calculateRewards(ship.shipClass, distance, cargoTarget);

    return Mission(
      id: "tailored_${ship.id}_${DateTime.now().millisecondsSinceEpoch}",
      title: "${ship.shipClass} Spec #${_random.nextInt(9999)}",
      description: "Direct contract for ship: ${ship.nickname}. Maximizes utility.",
      requiredClass: ship.shipClass,
      distanceAU: distance,
      minShieldLevel: ship.shieldLevel, // Exact match
      minCargo: cargoTarget,
      rewardSolars: rewards['solars'] as int,
      rewardResource: rewards['resource'] as String?,
      rewardResourceAmount: rewards['amount'] as int,
      baseDurationMinutes: 0, // Calculated at launch
    );
  }

  Map<String, dynamic> _calculateRewards(String shipClass, double distance, int cargoLoad) {
    // Base Calculation
    int value = (distance * 100).toInt() + (cargoLoad * 20);
    int variance = _random.nextInt(50);
    int baseTotal = value + variance;

    // Class Multipliers
    double multiplier = 1.0;
    switch(shipClass) {
      case 'Mule': multiplier = 1.0; break;
      case 'Sprinter': multiplier = 1.5; break;
      case 'Miner': multiplier = 3.0; break;
      case 'Tanker': multiplier = 6.0; break;
      case 'Harvester': multiplier = 10.0; break;
    }

    int totalValue = (baseTotal * multiplier).toInt();

    if (shipClass == 'Miner') {
      return {
        'solars': 0,
        'resource': 'Ore',
        'amount': max(5, (totalValue / 10).toInt()), // Ore ~10 Solars
      };
    } else if (shipClass == 'Tanker') {
      return {
        'solars': 0,
        'resource': 'Gas',
        'amount': max(2, (totalValue / 25).toInt()), // Gas ~25 Solars
      };
    } else if (shipClass == 'Harvester') {
      return {
        'solars': 0,
        'resource': 'Crystals',
        'amount': max(1, (totalValue / 100).toInt()), // Crystals ~100 Solars
      };
    }

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
