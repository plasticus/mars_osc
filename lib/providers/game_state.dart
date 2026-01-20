import 'package:flutter/material.dart';
import '../models/ship_model.dart';
import '../models/mission_model.dart';
import '../services/mission_service.dart';
import 'dart:math';
import 'dart:async';

/// Data class for Mission Logs
class LogEntry {
  final DateTime timestamp;
  final String title;
  final String details;
  final int? solarChange;
  final bool isPositive;

  LogEntry({
    required this.timestamp,
    required this.title,
    required this.details,
    this.solarChange,
    this.isPositive = true,
  });
}

class GameState extends ChangeNotifier {
  int solars = 1000;
  String companyName = "New MOSC Branch";

  int hangarLevel = 1;
  int scanArrayLevel = 1;

  List<Ship> fleet = [];
  List<Mission> availableMissions = [];
  List<LogEntry> missionLogs = [];
  
  final MissionService _missionService = MissionService();
  Timer? _gameTimer;

  GameState() {
    fleet.add(Ship(
      id: "starter_001",
      nickname: "The Rusty Scow",
      modelName: "Rusty Tug",
      shipClass: "Mule",
      speed: 2,
      maxSpeed: 4,
      cargoCapacity: 4,
      maxCargo: 6,
      fuelCapacity: 3,
      maxFuel: 5,
      shieldLevel: 1,
      maxShield: 3,
      aiLevel: 1,
      maxAI: 2,
    ));

    _startGameLoop();
  }

  int get maxFleetSize => hangarLevel * 3;

  void _startGameLoop() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      bool changesMade = false;

      for (var ship in fleet) {
        if (ship.missionEndTime != null && now.isAfter(ship.missionEndTime!)) {
          _processMissionCompletion(ship);
          changesMade = true;
        }
        
        if (ship.busyUntil != null && now.isAfter(ship.busyUntil!)) {
          _processMaintenanceCompletion(ship);
          changesMade = true;
        }
      }

      if (changesMade) {
        notifyListeners();
      }
    });
  }

  void _processMaintenanceCompletion(Ship ship) {
    if (ship.currentTask == 'Repairing') {
      ship.condition = 1.0;
      missionLogs.insert(0, LogEntry(
        timestamp: DateTime.now(),
        title: "Repair Complete",
        details: "${ship.nickname} maintenance finished. Hull at 100%.",
      ));
    } else if (ship.currentTask == 'Upgrading') {
      missionLogs.insert(0, LogEntry(
        timestamp: DateTime.now(),
        title: "Upgrade Installed",
        details: "${ship.nickname} systems have been enhanced.",
      ));
    }
    ship.busyUntil = null;
    ship.currentTask = null;
  }

  void startMission(String shipId, Mission mission) {
    final shipIndex = fleet.indexWhere((s) => s.id == shipId);
    if (shipIndex != -1) {
      final now = DateTime.now();
      fleet[shipIndex].missionStartTime = now;
      fleet[shipIndex].missionEndTime = now.add(const Duration(minutes: 1));
      fleet[shipIndex].pendingReward = mission.rewardSolars;

      availableMissions.removeWhere((m) => m.id == mission.id);
      
      // Ensure "Local Scrap Run" is replaced immediately if it was the one taken
      if (mission.title == "Local Scrap Run") {
         availableMissions.add(_missionService.getLocalScrapRun());
      } else {
        // Also check if any scrap run exists, if not, add one
        bool scrapExists = availableMissions.any((m) => m.title == "Local Scrap Run");
        if (!scrapExists) {
          availableMissions.add(_missionService.getLocalScrapRun());
        }
      }

      missionLogs.insert(0, LogEntry(
        timestamp: now,
        title: "Mission Launched",
        details: "${fleet[shipIndex].nickname} sent to ${mission.title}.",
      ));
      
      notifyListeners();
    }
  }

  void _processMissionCompletion(Ship ship) {
    int reward = ship.pendingReward;
    solars += reward;
    
    double wear = (Random().nextInt(4) + 1) / 100.0; 
    double oldCondition = ship.condition;
    ship.condition = (ship.condition - wear).clamp(0.0, 1.0);
    double actualWear = (oldCondition - ship.condition) * 100;

    missionLogs.insert(0, LogEntry(
      timestamp: DateTime.now(),
      title: "Mission Return: ${ship.nickname}",
      details: "Earnings: ⁂$reward. Hull Wear: -${actualWear.toStringAsFixed(1)}%.",
      solarChange: reward,
      isPositive: true,
    ));

    ship.pendingReward = 0;
    ship.missionStartTime = null;
    ship.missionEndTime = null;
  }

  void repairShip(String shipId) {
    final shipIndex = fleet.indexWhere((s) => s.id == shipId);
    if (shipIndex != -1) {
      final ship = fleet[shipIndex];
      int cost = getRepairCost(ship);

      if (solars >= cost && ship.condition < 1.0 && ship.busyUntil == null) {
        solars -= cost;
        ship.busyUntil = DateTime.now().add(const Duration(seconds: 30));
        ship.currentTask = 'Repairing';
        
        missionLogs.insert(0, LogEntry(
          timestamp: DateTime.now(),
          title: "Maintenance Begun",
          details: "${ship.nickname} enters Dry Dock for repairs. Cost: ⁂$cost.",
          solarChange: -cost,
          isPositive: false,
        ));
        
        notifyListeners();
      }
    }
  }

  void upgradeShipStat(String shipId, String stat) {
    final shipIndex = fleet.indexWhere((s) => s.id == shipId);
    if (shipIndex == -1) return;
    final ship = fleet[shipIndex];
    if (ship.busyUntil != null || ship.missionEndTime != null) return;

    int currentLevel = 0;
    int maxLevel = 0;

    switch(stat) {
      case 'speed': currentLevel = ship.speed; maxLevel = ship.maxSpeed; break;
      case 'cargo': currentLevel = ship.cargoCapacity; maxLevel = ship.maxCargo; break;
      case 'fuel': currentLevel = ship.fuelCapacity; maxLevel = ship.maxFuel; break;
      case 'shield': currentLevel = ship.shieldLevel; maxLevel = ship.maxShield; break;
      case 'ai': currentLevel = ship.aiLevel; maxLevel = ship.maxAI; break;
    }

    int cost = getUpgradeCost(ship, currentLevel);

    if (solars >= cost && currentLevel < maxLevel) {
      solars -= cost;
      switch(stat) {
        case 'speed': ship.speed++; break;
        case 'cargo': ship.cargoCapacity++; break;
        case 'fuel': ship.fuelCapacity++; break;
        case 'shield': ship.shieldLevel++; break;
        case 'ai': ship.aiLevel++; break;
      }
      
      ship.busyUntil = DateTime.now().add(const Duration(minutes: 1));
      ship.currentTask = 'Upgrading';

      missionLogs.insert(0, LogEntry(
        timestamp: DateTime.now(),
        title: "Systems Upgrade",
        details: "${ship.nickname} $stat systems being enhanced. Cost: ⁂$cost.",
        solarChange: -cost,
        isPositive: false,
      ));

      notifyListeners();
    }
  }

  int getRepairCost(Ship ship) {
    double missingCondition = 1.0 - ship.condition;
    int shipValue = getShipSaleValue(ship);
    return (missingCondition * (shipValue * 0.2)).toInt();
  }

  int getUpgradeCost(Ship ship, int currentLevel) {
    int shipValue = getShipSaleValue(ship);
    return ((shipValue * 0.1) * (1 + currentLevel * 0.2)).toInt();
  }

  int getShipSaleValue(Ship ship) {
    int baseStatsValue = (ship.speed + ship.cargoCapacity + ship.shieldLevel + ship.aiLevel + ship.fuelCapacity) * 50;
    double conditionMult = 0.5 + (ship.condition * 0.5);
    return (baseStatsValue * conditionMult).toInt();
  }

  void sellShip(String shipId) {
    final shipIndex = fleet.indexWhere((s) => s.id == shipId);
    if (shipIndex != -1) {
      final ship = fleet[shipIndex];
      if (ship.missionEndTime != null || ship.busyUntil != null) return;

      int value = getShipSaleValue(ship);
      solars += value;
      
      missionLogs.insert(0, LogEntry(
        timestamp: DateTime.now(),
        title: "Ship Decommissioned",
        details: "${ship.nickname} sold for salvage. Recoup: ⁂$value.",
        solarChange: value,
        isPositive: true,
      ));

      fleet.removeAt(shipIndex);
      notifyListeners();
    }
  }

  bool buyShip(Ship newShip, int cost) {
    if (solars >= cost && fleet.length < maxFleetSize) {
      solars -= cost;
      fleet.add(newShip);
      
      missionLogs.insert(0, LogEntry(
        timestamp: DateTime.now(),
        title: "Fleet Expansion",
        details: "Purchased ${newShip.modelName} \"${newShip.nickname}\".",
        solarChange: -cost,
        isPositive: false,
      ));

      notifyListeners();
      return true;
    }
    return false;
  }

  void renameShip(String shipId, String newName) {
    final shipIndex = fleet.indexWhere((s) => s.id == shipId);
    if (shipIndex != -1 && newName.isNotEmpty) {
      fleet[shipIndex].nickname = newName;
      notifyListeners();
    }
  }

  void updateMissions(List<Mission> newMissions) {
    availableMissions = newMissions;
    // Always ensure a Scrap Run exists after a refresh
    if (!availableMissions.any((m) => m.title == "Local Scrap Run")) {
      availableMissions.add(_missionService.getLocalScrapRun());
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }
}
