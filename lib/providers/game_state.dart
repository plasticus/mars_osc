import 'package:flutter/material.dart';
import '../models/ship_model.dart';
import '../models/mission_model.dart';
import 'dart:math';
import 'dart:async'; // Required for the mission timer

class GameState extends ChangeNotifier {
  int solars = 1000;
  String companyName = "New MOSC Branch";

  int hangarLevel = 1;
  int scanArrayLevel = 1;

  List<Ship> fleet = [];
  List<Mission> availableMissions = [];

  // Background timer to check mission status
  Timer? _missionTimer;

  GameState() {
    // Initialize the starter ship
    fleet.add(Ship(
      id: "starter_001",
      nickname: "The Rusty Scow",
      modelName: "Tug-v1",
      shipClass: "Mule",
      speed: 2,
      cargoCapacity: 15,
      fuelCapacity: 2,
      shieldLevel: 1,
      aiLevel: 1,
    ));

    // Start the "heartbeat" to check for finished missions
    _startMissionChecking();
  }

  // Monitor fleet for completed missions every second
  void _startMissionChecking() {
    _missionTimer?.cancel();
    _missionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      bool changesMade = false;

      for (var ship in fleet) {
        if (ship.missionEndTime != null && now.isAfter(ship.missionEndTime!)) {
          // Mission complete!
          _processMissionCompletion(ship);
          changesMade = true;
        }
      }

      if (changesMade) {
        notifyListeners();
      }
    });
  }

  void updateMissions(List<Mission> newMissions) {
    availableMissions = newMissions;
    notifyListeners();
  }

  void startMission(String shipId, Mission mission) {
    final shipIndex = fleet.indexWhere((s) => s.id == shipId);
    if (shipIndex != -1) {
      final now = DateTime.now();
      fleet[shipIndex].missionStartTime = now;

      // FOR TESTING: Setting duration to 1 minute instead of the calculated distance
      fleet[shipIndex].missionEndTime = now.add(const Duration(minutes: 1));

      fleet[shipIndex].pendingReward = mission.rewardSolars;

      // Removed the 50 solar launch fee
      availableMissions.removeWhere((m) => m.id == mission.id);
      notifyListeners();
    }
  }

  // Internal logic to handle the actual reward processing
  void _processMissionCompletion(Ship ship) {
    solars += ship.pendingReward;
    ship.pendingReward = 0;
    ship.missionStartTime = null;
    ship.missionEndTime = null;

    // Apply random wear and tear (10% to 25%)
    double wear = (Random().nextInt(15) + 10) / 100;
    ship.condition = (ship.condition - wear).clamp(0.0, 1.0);
  }

  // Manual completion trigger if needed for UI
  void completeMission(String shipId) {
    final shipIndex = fleet.indexWhere((s) => s.id == shipId);
    if (shipIndex != -1) {
      _processMissionCompletion(fleet[shipIndex]);
      notifyListeners();
    }
  }

  void repairShip(String shipId) {
    final shipIndex = fleet.indexWhere((s) => s.id == shipId);
    if (shipIndex != -1) {
      final ship = fleet[shipIndex];
      double missingCondition = 1.0 - ship.condition;
      int repairCost = (missingCondition * 500).toInt();

      if (solars >= repairCost && missingCondition > 0) {
        solars -= repairCost;
        ship.condition = 1.0;
        notifyListeners();
      }
    }
  }

  void buyShip(Ship newShip, int cost) {
    if (solars >= cost) {
      solars -= cost;
      fleet.add(newShip);
      notifyListeners();
    }
  }

  void addSolars(int amount) {
    solars += amount;
    notifyListeners();
  }

  @override
  void dispose() {
    _missionTimer?.cancel(); // Clean up timer when provider is destroyed
    super.dispose();
  }
}