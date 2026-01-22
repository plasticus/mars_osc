import 'dart:math';
import '../models/mission_model.dart';
import '../models/ship_model.dart';
import '../utils/game_formulas.dart';

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

  Mission getLocalMiningRun() {
    return Mission(
      id: "miner_low_${DateTime.now().millisecondsSinceEpoch}",
      title: "Belt Skimming (Miner)",
      description: "A quick hop to the nearest carbonaceous asteroids for surface ore.",
      requiredClass: "Miner",
      distanceAU: 1.5, // Just outside Mars' immediate gravity well
      minShieldLevel: 0,
      minCargo: 1,
      rewardSolars: 0,
      rewardResource: 'Ore',
      rewardResourceAmount: 8, // Slightly bumped for the extra distance
      baseDurationMinutes: 0,
    );
  }

  Mission getLocalGasRun() {
    return Mission(
      id: "tanker_low_${DateTime.now().millisecondsSinceEpoch}",
      title: "Vent Siphoning (Tanker)",
      description: "Intercepting a pocket of expelled gas from a nearby belt-station.",
      requiredClass: "Tanker",
      distanceAU: 1.8,
      minShieldLevel: 0,
      minCargo: 1,
      rewardSolars: 0,
      rewardResource: 'Gas',
      rewardResourceAmount: 3,
      baseDurationMinutes: 0,
    );
  }

  Mission getLocalRiftRun() {
    return Mission(
      id: "harvester_low_${DateTime.now().millisecondsSinceEpoch}",
      title: "Belt Anomaly Sweep (Harvester)",
      description: "Scanning low-energy rift signatures on the very edge of the belt.",
      requiredClass: "Harvester",
      distanceAU: 2.0,
      minShieldLevel: 0,
      minCargo: 1,
      rewardSolars: 0,
      rewardResource: 'Crystals',
      rewardResourceAmount: 1,
      baseDurationMinutes: 0,
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
          description: _getRandomFlavorText(category),
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

// Ensure low-level missions always exist for every unlocked class
    if (!newMissions.any((m) => m.title.contains("Local Scrap Run"))) {
      newMissions.add(getLocalScrapRun());
    }
    if (!newMissions.any((m) => m.title.contains("Local Courier Run"))) {
      newMissions.add(getLocalCourierRun());
    }
// Class-Gated Locals
    if (relayLevel >= 2 && !newMissions.any((m) => m.title.contains("Belt Skimming"))) {
      newMissions.add(getLocalMiningRun());
    }
    if (relayLevel >= 3 && !newMissions.any((m) => m.title.contains("Vent Siphoning"))) {
      newMissions.add(getLocalGasRun());
    }
    if (relayLevel >= 4 && !newMissions.any((m) => m.title.contains("Belt Anomaly Sweep"))) {
      newMissions.add(getLocalRiftRun());
    }

    return newMissions;
  }

  Mission _generateMissionForShip(Ship ship, int relayLevel) {
    // Tailored Logic: Push limits of the ship
    double maxRange = GameFormulas.getMaxDistanceAU(ship.fuelCapacity, ship.aiLevel);
    
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
      description: _getRandomFlavorText(ship.shipClass),
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

String _getRandomFlavorText(String shipClass) {
  final Map<String, List<String>> flavorTexts = {
    'Mule': [
      "Local station needs a bulk shipment of bio-paste. Heavy but safe.",
      "Relocating surplus machinery from the lower docks.",
      "The habitat rings are low on water recyclers. Routine haul.",
      "Contractor failed to show. We need this scrap moved yesterday.",
      "Standard industrial freight. Keep it steady, trucker.",
      "A hydroponics bay is moving its soil beds. Dirty work, but it pays.",
      "Construction materials for the new transit hub. Don't scratch the plating.",
      "A batch of low-grade hull plating needs to go to the scrapyard.",
      "Transporting a shipment of 'Grade-B' luxury textiles. It's mostly just rugs.",
      "Moving crates of generic spare parts to the outer rim depot.",
      "The cafeteria is out of synth-coffee. This is a true emergency.",
      "Bulk delivery of insulation foam for the new radiation shielding.",
      "Moving a decommissioned engine block for museum display.",
      "Hauling a load of recycled plastics to the 3D-printing labs.",
      "Standard logistics loop: dropping off basic supplies at the mining camp.",
    ],
    'Sprinter': [
      "Urgent medical data drive needs to reach the inner moon. High priority.",
      "A high-ranking official forgot their credentials. Speed is key.",
      "Time-sensitive repair parts for the oxygen scrubbers.",
      "Courier request: Confidential diplomatic pouch. Don't ask, just fly.",
      "Emergency relay node deployment. The network is down until you arrive.",
      "Last-minute organ transport for a critical surgery on the science vessel.",
      "A lawyer needs to serve a subpoena before the ship docks. Burn those thrusters.",
      "Delivering a 'hot-fix' patch for a station's failing security grid.",
      "Fresh isotopes with a very short half-life. Don't dawdle.",
      "Someone left their lucky charm on the last station. Excessive pay for a silly task.",
      "Overdue library books. The fines are reaching astronomical levels.",
      "Delivering fresh sushi to the Governor’s yacht. Must arrive cold.",
      "High-speed intercept: A departing freighter forgot its flight manifest.",
      "Urgent press release for the Martian News Network. Breaking news!",
      "Transporting a specialized decryption key for a locked cargo container.",
    ],
    'Miner': [
      "Scanners picked up a high-density iron deposit in the nearby belt.",
      "The forge is hungry. Bring back a full load of raw silicates.",
      "A local conglomerate is offloading mining rights to a small debris field.",
      "Surface-level hematite detected. Perfect for a quick extraction.",
      "Small-scale rock-breaking contract. Low risk, steady ore.",
      "An old surveyor's map suggests a vein of copper in a forgotten sector.",
      "The local foundry is running low on fluxing agents. Get some ore.",
      "A rogue asteroid just entered the sector. Let's peel it before it leaves.",
      "Deep-vein nickel deposits found in a stable cluster.",
      "Mining drone broke down; finish the job and keep the remaining ore.",
      "Clear a path through a small debris field and harvest the remains.",
      "High-sulfur rock detected. Smells like money.",
      "An independent prospector is selling their location data for a cut.",
      "The station’s hull repair crew needs a fresh batch of raw magnesium.",
      "Stripping a silicate-rich rock for base construction materials.",
    ],
    'Tanker': [
      "A nearby freighter ran dry. Siphon some nebula gas and get it to them.",
      "The fuel depot is nearing critical lows. We need a gas injection.",
      "Trace amounts of Helium-3 detected in the local cloud. Go get it.",
      "Station atmosphere needs nitrogen balancing. Standard siphon run.",
      "Research vessel needs localized gas samples for their laboratory.",
      "Argon harvesting for the station's neon lighting and plasma cutters.",
      "Siphon a pocket of methane from a passing comet’s tail.",
      "Collecting Xenon gas for a long-haul vessel's ion engines.",
      "The localized nebula is particularly thick today. Easy picking.",
      "A pressurized leak in Sector 4 left a gas cloud ripe for the taking.",
      "Industrial cooling systems need a refill of ammonia gas.",
      "The greenhouse needs a concentrated CO2 injection.",
      "Harvesting traces of hydrogen from a low-density gas pocket.",
      "A rogue gas pocket is interfering with comms; go clean it up.",
      "Special request: High-purity oxygen for the station's medical wing.",
    ],
    'Harvester': [
      "A minor rift anomaly just blinked onto the long-range scanners.",
      "Deep-space energy signatures detected. Possible crystal formation.",
      "The science division needs fresh data from the anomaly's edge.",
      "Faint spectral readings detected. Harvest whatever hasn't stabilized yet.",
      "Anomaly sweep: Looking for high-energy resonance crystals.",
      "A distortion in space-time has left behind a trail of shimmering shards.",
      "The rift is breathing today. Crystals are blooming in the gaps.",
      "Unstable energy readings. Get in, grab the crystals, and get out.",
      "Harvesting 'memory crystals' from a stabilized rift pocket.",
      "A high-energy anomaly is collapsing. This is the last chance for shards.",
      "Trace amounts of exotic matter detected near a gravity well.",
      "The rift's resonance frequency matches our crystal collectors. Go!",
      "A 'ghost-signal' anomaly has left behind physical residue. Harvest it.",
      "Deep-space rift cluster: High reward for those who dare the edge.",
      "The anomaly is shedding its outer layer. Grab the flakes before they fade.",
    ],
  };

  final texts = flavorTexts[shipClass] ?? ["Standard cargo delivery contract."];
  return texts[_random.nextInt(texts.length)];
}
