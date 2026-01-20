import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'details': details,
      'solarChange': solarChange,
      'isPositive': isPositive,
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp']),
      title: json['title'],
      details: json['details'],
      solarChange: json['solarChange'],
      isPositive: json['isPositive'],
    );
  }
}

class GameState extends ChangeNotifier {
  int solars = 50000;
  String companyName = "New MOSC Branch";

  // Base Upgrade Levels
  int hangarLevel = 1;
  int relayLevel = 1; 
  int serverFarmLevel = 0;
  int tradeDepotLevel = 0;
  int repairGantryLevel = 0;
  int broadcastingArrayLevel = 1;

  int get scanArrayLevel => relayLevel;

  List<Ship> fleet = [];
  List<Mission> availableMissions = [];
  List<LogEntry> missionLogs = [];
  
  final MissionService _missionService = MissionService();
  Timer? _gameTimer;
  bool _isInitialized = false;

  static const double _timeScalingFactor = 0.54;

  GameState() {
    _loadData().then((_) {
      _isInitialized = true;
      if (fleet.isEmpty) {
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
      }
      _startGameLoop();
      notifyListeners();
    });
  }

  // --- PERSISTENCE LOGIC ---

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setInt('solars', solars);
      await prefs.setInt('hangarLevel', hangarLevel);
      await prefs.setInt('relayLevel', relayLevel);
      await prefs.setInt('serverFarmLevel', serverFarmLevel);
      await prefs.setInt('tradeDepotLevel', tradeDepotLevel);
      await prefs.setInt('repairGantryLevel', repairGantryLevel);
      await prefs.setInt('broadcastingArrayLevel', broadcastingArrayLevel);
      
      final fleetJson = jsonEncode(fleet.map((s) => s.toJson()).toList());
      await prefs.setString('fleet', fleetJson);
      
      final logsJson = jsonEncode(missionLogs.take(50).map((l) => l.toJson()).toList());
      await prefs.setString('missionLogs', logsJson);
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('solars')) return;

      solars = prefs.getInt('solars') ?? 50000;
      hangarLevel = prefs.getInt('hangarLevel') ?? 1;
      relayLevel = prefs.getInt('relayLevel') ?? 1;
      serverFarmLevel = prefs.getInt('serverFarmLevel') ?? 0;
      tradeDepotLevel = prefs.getInt('tradeDepotLevel') ?? 0;
      repairGantryLevel = prefs.getInt('repairGantryLevel') ?? 0;
      broadcastingArrayLevel = prefs.getInt('broadcastingArrayLevel') ?? 1;
      
      final fleetString = prefs.getString('fleet');
      if (fleetString != null) {
        final List<dynamic> decoded = jsonDecode(fleetString);
        fleet = decoded.map((item) => Ship.fromJson(item)).toList();
      }
      
      final logsString = prefs.getString('missionLogs');
      if (logsString != null) {
        final List<dynamic> decoded = jsonDecode(logsString);
        missionLogs = decoded.map((item) => LogEntry.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint("Load error: $e");
    }
  }

  Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    solars = 50000;
    hangarLevel = 1;
    relayLevel = 1;
    serverFarmLevel = 0;
    tradeDepotLevel = 0;
    repairGantryLevel = 0;
    broadcastingArrayLevel = 1;
    fleet = [];
    missionLogs = [];
    _isInitialized = false;
    
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
    _isInitialized = true;
    notifyListeners();
  }

  void _triggerUpdate() {
    if (_isInitialized) {
      _saveData();
    }
    notifyListeners();
  }

  // -------------------------

  int get maxFleetSize {
    if (hangarLevel == 1) return 2;
    return hangarLevel * 2;
  }

  bool isClassUnlocked(String shipClass) {
    if (shipClass == 'Mule' || shipClass == 'Sprinter') return true;
    if (shipClass == 'Tanker') return relayLevel >= 2;
    if (shipClass == 'Miner') return relayLevel >= 3;
    if (shipClass == 'Harvester') return relayLevel >= 4;
    return false;
  }

  double get globalAIBonus {
    if (serverFarmLevel == 1) return 0.5;
    if (serverFarmLevel == 2) return 1.0;
    if (serverFarmLevel == 3) return 2.0;
    return 0.0;
  }

  double get repairCostMultiplier {
    if (repairGantryLevel == 1) return 0.90;
    if (repairGantryLevel == 2) return 0.75;
    return 1.0;
  }

  double get repairSpeedMultiplier {
    if (repairGantryLevel == 3) return 2.0;
    return 1.0;
  }

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
        _saveData();
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
      
      if (mission.title == "Local Scrap Run") {
         availableMissions.add(_missionService.getLocalScrapRun());
      } else {
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
      
      _triggerUpdate();
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

  Duration getRepairDuration(Ship ship) {
    double missingCondition = 1.0 - ship.condition;
    int shipValue = getShipSaleValue(ship);
    int seconds = (missingCondition * shipValue * _timeScalingFactor / repairSpeedMultiplier).toInt();
    return Duration(seconds: max(5, seconds));
  }

  Duration getUpgradeDuration(Ship ship, int currentLevel) {
    int shipValue = getShipSaleValue(ship);
    int seconds = (shipValue * _timeScalingFactor * (1 + currentLevel * 0.1)).toInt();
    return Duration(seconds: max(10, seconds));
  }

  void repairShip(String shipId) {
    final shipIndex = fleet.indexWhere((s) => s.id == shipId);
    if (shipIndex != -1) {
      final ship = fleet[shipIndex];
      int cost = getRepairCost(ship);

      if (solars >= cost && ship.condition < 1.0 && ship.busyUntil == null) {
        solars -= cost;
        ship.busyUntil = DateTime.now().add(getRepairDuration(ship));
        ship.currentTask = 'Repairing';
        
        missionLogs.insert(0, LogEntry(
          timestamp: DateTime.now(),
          title: "Maintenance Begun",
          details: "${ship.nickname} enters Dry Dock for repairs. Cost: ⁂$cost.",
          solarChange: -cost,
          isPositive: false,
        ));
        
        _triggerUpdate();
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
      
      ship.busyUntil = DateTime.now().add(getUpgradeDuration(ship, currentLevel));
      ship.currentTask = 'Upgrading';

      missionLogs.insert(0, LogEntry(
        timestamp: DateTime.now(),
        title: "Systems Upgrade",
        details: "${ship.nickname} $stat systems being enhanced. Cost: ⁂$cost.",
        solarChange: -cost,
        isPositive: false,
      ));

      _triggerUpdate();
    }
  }

  int getRepairCost(Ship ship) {
    double missingCondition = 1.0 - ship.condition;
    int shipValue = getShipSaleValue(ship);
    return (missingCondition * (shipValue * 0.2) * repairCostMultiplier).toInt();
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

  void upgradeBase(String type, int cost) {
    if (solars >= cost) {
      solars -= cost;
      switch(type) {
        case 'Hangar': hangarLevel++; break;
        case 'Relay': relayLevel++; break;
        case 'Server': serverFarmLevel++; break;
        case 'Depot': tradeDepotLevel++; break;
        case 'Gantry': repairGantryLevel++; break;
        case 'Broadcasting': broadcastingArrayLevel++; break;
      }
      
      missionLogs.insert(0, LogEntry(
        timestamp: DateTime.now(),
        title: "Base Infrastructure Upgraded",
        details: "$type systems reached Level ${type == 'Hangar' ? hangarLevel : (type == 'Relay' ? relayLevel : (type == 'Server' ? serverFarmLevel : (type == 'Depot' ? tradeDepotLevel : (type == 'Gantry' ? repairGantryLevel : broadcastingArrayLevel))))}.",
        solarChange: -cost,
        isPositive: false,
      ));
      
      _triggerUpdate();
    }
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
      _triggerUpdate();
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

      _triggerUpdate();
      return true;
    }
    return false;
  }

  void renameShip(String shipId, String newName) {
    final shipIndex = fleet.indexWhere((s) => s.id == shipId);
    if (shipIndex != -1 && newName.isNotEmpty) {
      final ship = fleet[shipIndex];
      int cost = ship.hasBeenRenamed ? 100 : 0;

      if (solars >= cost) {
        solars -= cost;
        String oldName = ship.nickname;
        ship.nickname = newName;
        ship.hasBeenRenamed = true;

        missionLogs.insert(0, LogEntry(
          timestamp: DateTime.now(),
          title: "Ship Re-registered",
          details: "$oldName is now officially designated as $newName.${cost > 0 ? ' Fee: ⁂$cost.' : ' First time is free.'}",
          solarChange: cost > 0 ? -cost : null,
          isPositive: false,
        ));

        _triggerUpdate();
      }
    }
  }

  void updateMissions(List<Mission> newMissions) {
    availableMissions = newMissions;
    if (!availableMissions.any((m) => m.title == "Local Scrap Run")) {
      availableMissions.add(_missionService.getLocalScrapRun());
    }
    _triggerUpdate();
  }

  void generateNewMissions() {
    updateMissions(_missionService.generateMissions(relayLevel, broadcastingArrayLevel, fleet));
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }
}
