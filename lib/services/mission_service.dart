import 'dart:math';
import '../models/mission_model.dart';
import '../models/ship_model.dart';

class MissionService {
  final Random _random = Random();

  // =========================
  // DISTANCE + RANGE RULES
  // =========================
  // Missions are constrained to the solar-system scale you're using.
  static const double kMinMissionAU = 0.50;
  static const double kSoftMaxMissionAU = 32.0;

  // Range model:
  // +1 Fuel = full impact
  // +1 AI   = half impact (+1 AI = +0.5 Fuel equivalent)
  //
  // Calibrated so a fully-upgraded Tier-5 Tanker (Infinite Reach):
  //   maxFuel=14, maxAI=12 => (14 + 0.5*12) = 20 range points
  //   20 * 1.6 = 32 AU
  static const double kAUPerRangePoint = 1.6;

  // =========================
  // DISTANCE DISTRIBUTIONS
  // (These are starting distributions for random missions.
  //  We still "mostly" filter to be doable by at least one owned ship.)
  // =========================
  final Map<String, List<double>> _classDistances = {
    'Mule': [0.50, 12.0],
    'Sprinter': [0.50, 6.0],
    'Miner': [1.00, 10.0],
    'Tanker': [6.00, 24.0],
    'Harvester': [10.0, 32.0],
  };

  // =========================
  // PUBLIC: guaranteed starter missions
  // =========================
  Mission getLocalScrapRun() {
    return Mission(
      id: "scrap_run_${DateTime.now().millisecondsSinceEpoch}",
      title: "Local Scrap Run (Mule)",
      description: "A simple run to the nearest debris field. Reliable but low pay.",
      requiredClass: "Mule",
      distanceAU: kMinMissionAU,
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

  // =========================
  // PUBLIC: generate mission board
  // =========================
  List<Mission> generateMissions(int relayLevel, int broadcastingLevel, List<Ship> fleet) {
    List<Mission> newMissions = [];
    int missionsPerCategory = broadcastingLevel * 2;

    // If player has no ships, just give the always-available locals + some basic Mules.
    // (Optional safeguard; you can tweak/remove.)
    if (fleet.isEmpty) {
      newMissions.add(getLocalScrapRun());
      newMissions.add(getLocalCourierRun());
      // Add a couple of generic Mule missions so the board isn't empty.
      for (int i = 0; i < max(1, missionsPerCategory); i++) {
        final m = _generateGenericMission("Mule", relayLevel, i);
        newMissions.add(m);
      }
      return newMissions;
    }

    // 1) Tailored missions: mostly 1 per owned ship, guaranteed doable by that ship
    for (var ship in fleet) {
      newMissions.add(_generateMissionForShip(ship, relayLevel));
    }

    // 2) Standard missions by category:
    //    Most of these will be filtered to be doable by at least one ship.
    List<String> allCategories = ['Mule', 'Sprinter', 'Miner', 'Tanker', 'Harvester'];

    for (String category in allCategories) {
      if (category == 'Miner' && relayLevel < 2) continue;
      if (category == 'Tanker' && relayLevel < 3) continue;
      if (category == 'Harvester' && relayLevel < 4) continue;

      for (int i = 0; i < missionsPerCategory; i++) {
        // 85% of "extra" missions should be doable by at least one owned ship.
        // 15% can be aspirational / not doable yet.
        final bool requireDoable = _random.nextDouble() < 0.85;

        Mission? m;
        if (requireDoable) {
          m = _tryGenerateStandardMission(category, relayLevel, i, fleet);
          if (m == null) {
            // Couldn't find a doable mission in this category after many attempts.
            // Skip silently (or generate a safe fallback if you prefer).
            continue;
          }
        } else {
          // Aspirational / purely random mission
          m = _generateGenericMission(category, relayLevel, i);
        }

        newMissions.add(m);
      }
    }

    // Ensure local missions always exist
    if (!newMissions.any((m) => m.title.contains("Local Scrap Run"))) {
      newMissions.add(getLocalScrapRun());
    }
    if (!newMissions.any((m) => m.title.contains("Local Courier Run"))) {
      newMissions.add(getLocalCourierRun());
    }

    return newMissions;
  }

  // =========================
  // RANGE / FEASIBILITY HELPERS
  // =========================
  double _rangePoints(Ship ship) => ship.fuelCapacity + (ship.aiLevel * 0.5);

  double _shipMaxDistanceAU(Ship ship) => _rangePoints(ship) * kAUPerRangePoint;

  bool _shipCanRunMission(Ship ship, Mission m) {
    if (ship.shipClass != m.requiredClass) return false;
    if (ship.shieldLevel < m.minShieldLevel) return false;
    if (ship.cargoCapacity < m.minCargo) return false;
    if (_shipMaxDistanceAU(ship) < m.distanceAU) return false;
    return true;
  }

  bool _anyShipCanRunMission(Mission m, List<Ship> fleet) {
    return fleet.any((s) => _shipCanRunMission(s, m));
  }

  // =========================
  // TAILORED MISSION (guaranteed doable)
  // =========================
  Mission _generateMissionForShip(Ship ship, int relayLevel) {
    final maxAU = _shipMaxDistanceAU(ship);

    // Missions won't ask beyond the soft cap, but still tuned to ship capability
    final cappedMaxAU = max(kMinMissionAU, min(maxAU, kSoftMaxMissionAU));

    // Target 70–95% of ship's reachable distance (within cap)
    final distance = double.parse(
      (cappedMaxAU * (0.70 + (_random.nextDouble() * 0.25))).toStringAsFixed(2),
    );

    // Target 70–100% of Cargo, ensure at least 1
    int cargoTarget = (ship.cargoCapacity * (0.70 + (_random.nextDouble() * 0.30))).ceil();
    cargoTarget = max(1, cargoTarget);

    // Shield requirement <= ship shield
    final int minShield = ship.shieldLevel == 0 ? 0 : _random.nextInt(ship.shieldLevel + 1);

    var rewards = _calculateRewards(ship.shipClass, distance, cargoTarget);

    final mission = Mission(
      id: "tailored_${ship.id}_${DateTime.now().millisecondsSinceEpoch}",
      title: "${ship.shipClass} Spec #${_random.nextInt(9999)}",
      description: "Direct contract for ship: ${ship.nickname}. Maximizes utility.",
      requiredClass: ship.shipClass,
      distanceAU: distance,
      minShieldLevel: minShield,
      minCargo: cargoTarget,
      rewardSolars: rewards['solars'] as int,
      rewardResource: rewards['resource'] as String?,
      rewardResourceAmount: rewards['amount'] as int,
      baseDurationMinutes: 0,
    );

    // Absolute failsafe (should rarely/never trigger)
    if (!_shipCanRunMission(ship, mission)) {
      return Mission(
        id: "tailored_safe_${ship.id}_${DateTime.now().millisecondsSinceEpoch}",
        title: "${ship.shipClass} Safe Contract",
        description: "Fallback contract tuned to your ship.",
        requiredClass: ship.shipClass,
        distanceAU: kMinMissionAU,
        minShieldLevel: 0,
        minCargo: 1,
        rewardSolars: 50,
        baseDurationMinutes: 0,
      );
    }

    return mission;
  }

  // =========================
  // STANDARD MISSION: try to find one doable by at least one owned ship
  // =========================
  Mission? _tryGenerateStandardMission(
      String category,
      int relayLevel,
      int i,
      List<Ship> fleet,
      ) {
    const int attempts = 25;

    for (int a = 0; a < attempts; a++) {
      final m = _generateGenericMission(category, relayLevel, i, attempt: a);
      if (_anyShipCanRunMission(m, fleet)) return m;
    }

    return null;
  }

  // Generate a mission with your usual random rules (optionally tagged by attempt).
  Mission _generateGenericMission(String category, int relayLevel, int i, {int? attempt}) {
    double distance = double.parse(_getRandomDistance(category).toStringAsFixed(2));
    distance = max(kMinMissionAU, min(distance, kSoftMaxMissionAU));

    int minShield = _random.nextInt(relayLevel + 1);
    int minCargo = _generateCargoRequirement(category, relayLevel);
    var rewards = _calculateRewards(category, distance, minCargo);

    final suffix = attempt == null ? "" : "_$attempt";

    return Mission(
      id: "std_${category}_${DateTime.now().millisecondsSinceEpoch}_${i}$suffix",
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
    );
  }

  // =========================
  // REWARDS
  // =========================
  Map<String, dynamic> _calculateRewards(String shipClass, double distance, int cargoLoad) {
    // Base Calculation
    int value = (distance * 100).toInt() + (cargoLoad * 20);
    int variance = _random.nextInt(50);
    int totalValue = value + variance;

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

  // =========================
  // TEXT + RANDOM HELPERS
  // =========================
  String _getDescription(String shipClass) {
    switch (shipClass) {
      case 'Miner':
        return "Asteroid belt mining operation.";
      case 'Tanker':
        return "Nebula gas siphon run.";
      case 'Harvester':
        return "Deep rift anomaly harvest.";
      default:
        return "Standard cargo delivery contract.";
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
