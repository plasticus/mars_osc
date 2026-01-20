import 'package:flutter/material.dart';
import '../models/ship_model.dart';
import '../models/mission_model.dart';
import 'dart:math';

class GameState extends ChangeNotifier {
  int solars = 1000;
  String companyName = "New MOSC Branch";
  
  int hangarLevel = 1;
  int scanArrayLevel = 1;
  
  List<Ship> fleet = [];
  List<Mission> availableMissions = [];

  GameState() {
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
      fleet[shipIndex].missionEndTime = now.add(Duration(minutes: mission.baseDurationMinutes));
      fleet[shipIndex].pendingReward = mission.rewardSolars;
      
      solars -= 50; 
      availableMissions.removeWhere((m) => m.id == mission.id);
      notifyListeners();
    }
  }

  void completeMission(String shipId) {
    final shipIndex = fleet.indexWhere((s) => s.id == shipId);
    if (shipIndex != -1) {
      final ship = fleet[shipIndex];
      solars += ship.pendingReward;
      ship.pendingReward = 0;
      ship.missionStartTime = null;
      ship.missionEndTime = null;

      double wear = (Random().nextInt(15) + 10) / 100;
      ship.condition = (ship.condition - wear).clamp(0.0, 1.0);

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

  // --- SHIPYARD LOGIC ---
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
}
