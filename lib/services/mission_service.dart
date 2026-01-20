import 'dart:math';
import '../models/mission_model.dart';

class MissionService {
  final Random _random = Random();

  final Map<String, List<double>> _classDistances = {
    'Mule': [1.0, 3.0],
    'Sprinter': [1.5, 5.0],
    'Tanker': [5.0, 15.0],
    'Miner': [2.0, 8.0],
    'Harvester': [10.0, 30.0],
  };

  List<Mission> generateMissions(int scanArrayLevel) {
    int count = _getMissionCount(scanArrayLevel);
    List<Mission> newMissions = [];

    for (int i = 0; i < count; i++) {
      String shipClass = _getRandomClass(scanArrayLevel);
      double distance = _getRandomDistance(shipClass);

      int baseReward = (distance * (100 + _random.nextInt(100))).toInt();
      if (shipClass == 'Harvester') baseReward *= 3;

      newMissions.add(Mission(
        id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
        title: "$shipClass Operation #${_random.nextInt(999)}",
        description: "Transporting vital goods across ${distance.toStringAsFixed(1)} AU.",
        requiredClass: shipClass,
        distanceAU: distance,
        minShieldLevel: _random.nextInt(scanArrayLevel + 1),
        minCargo: (shipClass == 'Mule') ? 10 + _random.nextInt(10) : 1 + _random.nextInt(5),
        rewardSolars: baseReward,
        baseDurationMinutes: (distance * 20).toInt(),
      ));
    }

    // NEW: Guaranteed Starter Mission
    newMissions.add(Mission(
      id: "starter_${DateTime.now().millisecondsSinceEpoch}",
      title: "Local Scrap Run",
      description: "A simple run to the nearest debris field. Perfect for rookies.",
      requiredClass: "Mule", // Starter ship class
      distanceAU: 0.5,
      minShieldLevel: 1,
      minCargo: 1,
      rewardSolars: 50,
      baseDurationMinutes: 5,
    ));

    // Shuffle so the starter isn't always at the end of the list
    newMissions.shuffle();

    return newMissions;
  }

  int _getMissionCount(int level) {
    if (level >= 5) return 20;
    if (level == 4) return 15;
    if (level == 3) return 10;
    if (level == 2) return 6;
    return 3;
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