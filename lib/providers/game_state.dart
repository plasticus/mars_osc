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
  
  // Resource Inventory
  int ore = 0;
  int gas = 0;
  int crystals = 0;

  // Base Upgrade Levels
  int hangarLevel = 1;
  int relayLevel = 1; 
  int serverFarmLevel = 0;
  int tradeDepotLevel = 1; 
  int repairGantryLevel = 0;
  int broadcastingArrayLevel = 1;

  int get scanArrayLevel => relayLevel;

  List<Ship> fleet = [];
  List<Mission> availableMissions = [];
  List<LogEntry> missionLogs = [];
  
  final MissionService _missionService = MissionService();
  Timer? _gameTimer;
  Timer? _marketTimer;
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
      _startMarketLoop();
      notifyListeners();
    });
  }

  // --- PERSISTENCE LOGIC ---

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setInt('solars', solars);
      await prefs.setInt('ore', ore);
      await prefs.setInt('gas', gas);
      await prefs.setInt('crystals', crystals);

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
      ore = prefs.getInt('ore') ?? 0;
      gas = prefs.getInt('gas') ?? 0;
      crystals = prefs.getInt('crystals') ?? 0;

      hangarLevel = prefs.getInt('hangarLevel') ?? 1;
      relayLevel = prefs.getInt('relayLevel') ?? 1;
      serverFarmLevel = prefs.getInt('serverFarmLevel') ?? 0;
      tradeDepotLevel = prefs.getInt('tradeDepotLevel') ?? 1;
      if (tradeDepotLevel < 1) tradeDepotLevel = 1;

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
    ore = 0;
    gas = 0;
    crystals = 0;
    hangarLevel = 1;
    relayLevel = 1;
    serverFarmLevel = 0;
    tradeDepotLevel = 1;
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

  int get maxStorage {
    // Base 500, +500 per level
    return tradeDepotLevel * 500; 
  }

  bool isClassUnlocked(String shipClass) {
    if (shipClass == 'Mule' || shipClass == 'Sprinter') return true;
    if (shipClass == 'Miner') return relayLevel >= 2; 
    if (shipClass == 'Tanker') return relayLevel >= 3;
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

  void _startMarketLoop() {
    _marketTimer?.cancel();
    // In Beta Mode: 1 minute = 1 hour.
    // In Real Mode: 60 minutes = 1 hour.
    const duration = Duration(minutes: 1); 
    
    _marketTimer = Timer.periodic(duration, (timer) {
      if (ore > 0 || gas > 0 || crystals > 0) {
        _performAutoSell();
        _saveData();
        notifyListeners();
      }
    });
  }

  void _performAutoSell() {
    Random rng = Random();
    // Sell a random chunk (e.g., 5% to 10% of current stock)
    double percent = 0.05 + (rng.nextDouble() * 0.05); 
    
    int soldOre = (ore * percent).ceil();
    int soldGas = (gas * percent).ceil();
    int soldCrystals = (crystals * percent).ceil();

    if (soldOre == 0 && ore > 0) soldOre = 1;
    if (soldGas == 0 && gas > 0) soldGas = 1;
    if (soldCrystals == 0 && crystals > 0) soldCrystals = 1;

    // AI Price Bonus: Base 1.05 + 0.05 per level above 1
    // Lvl 1: 1.05 (105%)
    // Lvl 5: 1.25 (125%)
    double multiplier = 1.0 + (tradeDepotLevel * 0.05);

    int revenue = 0;
    revenue += (soldOre * getResourcePrice('Ore') * multiplier).toInt();
    revenue += (soldGas * getResourcePrice('Gas') * multiplier).toInt();
    revenue += (soldCrystals * getResourcePrice('Crystals') * multiplier).toInt();

    ore -= soldOre;
    gas -= soldGas;
    crystals -= soldCrystals;
    solars += revenue;

    missionLogs.insert(0, LogEntry(
      timestamp: DateTime.now(),
      title: "Auto-Sell AI",
      details: "Sold goods for ⁂$revenue (${(multiplier*100).toInt()}% rate). Left: $ore 🏔️ | $gas ☁️ | $crystals 💎",
      solarChange: revenue,
      isPositive: true,
    ));
  }

  void manualSellAll() {
    if (ore == 0 && gas == 0 && crystals == 0) return;

    int revenue = 0;
    revenue += ore * getResourcePrice('Ore');
    revenue += gas * getResourcePrice('Gas');
    revenue += crystals * getResourcePrice('Crystals');

    missionLogs.insert(0, LogEntry(
      timestamp: DateTime.now(),
      title: "Manual Liquidate",
      details: "Sold all inventory ($ore 🏔️ | $gas ☁️ | $crystals 💎) for ⁂$revenue.",
      solarChange: revenue,
      isPositive: true,
    ));

    ore = 0;
    gas = 0;
    crystals = 0;
    solars += revenue;
    
    _triggerUpdate();
  }

  void debugCompleteAllMissions() {
    bool updated = false;
    final now = DateTime.now();
    for (var ship in fleet) {
      if (ship.missionEndTime != null) {
        // Set to now, loop will catch it
        ship.missionEndTime = now;
        updated = true;
      }
      if (ship.busyUntil != null) {
        // Also finish repairs/upgrades instantly
        ship.busyUntil = now;
        updated = true;
      }
    }
    
    if (updated) {
      missionLogs.insert(0, LogEntry(
        timestamp: DateTime.now(),
        title: "BETA: Warp Speed",
        details: "All active timers advanced to completion.",
        isPositive: true,
      ));
      _triggerUpdate();
    }
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
      fleet[shipIndex].missionDistance = mission.distanceAU; 
      
      // -- NEW DURATION LOGIC (SECONDS) --
      // Base factor: 1920 seconds per (AU/Speed) [32 minutes]
      // Beta factor: 0.015 [Roughly 30 seconds per unit]
      double factor = 1920.0;
      factor *= 0.015; // Beta: Super Fast
      
      int speed = fleet[shipIndex].speed;
      if (speed < 1) speed = 1; 
      
      // AI Speed Bonus: -5% time per AI Level
      int ai = fleet[shipIndex].aiLevel;
      double aiMult = max(0.5, 1.0 - (ai * 0.05));
      factor *= aiMult;

      double rawSeconds = (mission.distanceAU / speed) * factor;
      
      // --- BETA CAP (SECONDS) ---
      // Hard cap at 5 minutes (300 seconds)
      if (rawSeconds > 300.0) rawSeconds = 300.0;
      // ----------------
      
      int seconds = max(5, rawSeconds.toInt()); // Min 5 seconds
      
      fleet[shipIndex].missionEndTime = now.add(Duration(seconds: seconds));
      // ------------------------
      
      fleet[shipIndex].pendingReward = mission.rewardSolars;
      fleet[shipIndex].pendingResource = mission.rewardResource;
      fleet[shipIndex].pendingResourceAmount = mission.rewardResourceAmount;

      availableMissions.removeWhere((m) => m.id == mission.id);
      
      if (mission.title.contains("Local Scrap Run")) {
         availableMissions.add(_missionService.getLocalScrapRun());
      } else if (mission.title.contains("Local Courier Run")) {
         availableMissions.add(_missionService.getLocalCourierRun());
      }

      missionLogs.insert(0, LogEntry(
        timestamp: now,
        title: "Mission Launched",
        details: "${fleet[shipIndex].nickname} sent to ${mission.title}. ETA: ${seconds}s",
      ));
      
      _triggerUpdate();
    }
  }

  void _processMissionCompletion(Ship ship) {
    int reward = ship.pendingReward;
    String? resource = ship.pendingResource;
    int amount = ship.pendingResourceAmount;

    // --- AI BONUS: REWARDS ---
    double aiRewardMult = 1.0 + (ship.aiLevel * 0.05);
    reward = (reward * aiRewardMult).toInt();
    amount = (amount * aiRewardMult).toInt();

    // --- BETA TESTING SWITCH ---
    // REMOVE THIS BLOCK BEFORE RELEASE
    reward *= 10;
    amount *= 10;
    // ---------------------------
    
    // Add rewards (Cash)
    solars += reward;
    String earnings = "";
    if (reward > 0) earnings += "⁂$reward";

    int overflowIncome = 0;

    // Handle Resources with Storage Cap
    if (resource != null && amount > 0) {
      int currentTotal = ore + gas + crystals;
      int space = maxStorage - currentTotal;
      int toStore = min(amount, max(0, space));
      int overflow = amount - toStore;

      if (toStore > 0) {
        if (resource == 'Ore') ore += toStore;
        if (resource == 'Gas') gas += toStore;
        if (resource == 'Crystals') crystals += toStore;
      }

      String icon = "";
      if (resource == 'Ore') icon = "🏔️";
      if (resource == 'Gas') icon = "☁️";
      if (resource == 'Crystals') icon = "💎";

      if (earnings.isNotEmpty) earnings += " + ";
      earnings += "$toStore m³ $icon $resource";

      if (overflow > 0) {
        // Instant Sell Overflow at 75% market
        int price = getResourcePrice(resource);
        int penaltyPrice = (price * 0.75).toInt();
        int overflowVal = overflow * penaltyPrice;
        solars += overflowVal;
        overflowIncome = overflowVal;
        
        int potentialVal = overflow * price;
        int lostVal = potentialVal - overflowVal;
        
        earnings += "\n(⚠️ Storage Full: $overflow m³ $icon sold rushed. Lost potential ⁂$lostVal)";
      }
    }
    
    // --- NEW WEAR CALCULATION ---
    double dist = ship.missionDistance ?? 1.0;
    double baseWearPercent = dist * 0.002; 
    
    // Mitigation: 2% reduction per Effective Shield
    double effectiveShield = ship.shieldLevel + (ship.aiLevel * 0.5);
    double mitigation = min(0.5, effectiveShield * 0.02); // Max 50% mitigation
    
    double wearPercent = baseWearPercent * (1.0 - mitigation);
    
    // Hard Floor: 0.05% per AU
    double floor = dist * 0.0005;
    if (wearPercent < floor) wearPercent = floor;
    
    // Variance: 0.8x to 1.2x
    double variance = 0.8 + (Random().nextDouble() * 0.4);
    wearPercent *= variance;
    
    double oldCondition = ship.condition;
    ship.condition = (ship.condition - wearPercent).clamp(0.0, 1.0);
    double actualWear = (oldCondition - ship.condition) * 100;

    missionLogs.insert(0, LogEntry(
      timestamp: DateTime.now(),
      title: "Mission Return: ${ship.nickname}",
      details: "Earnings: $earnings. Hull Wear: -${actualWear.toStringAsFixed(2)}%.",
      solarChange: reward + overflowIncome,
      isPositive: true,
    ));

    // Clear Pending
    ship.pendingReward = 0;
    ship.pendingResource = null;
    ship.pendingResourceAmount = 0;
    ship.missionStartTime = null;
    ship.missionEndTime = null;
    ship.missionDistance = null;
  }
  
  // Market Logic
  int getResourcePrice(String resource) {
    final now = DateTime.now().minute;
    double variance = 1.0 + (sin(now / 10) * 0.2); // +/- 20%
    
    switch(resource) {
      case 'Ore': return (10 * variance).toInt();
      case 'Gas': return (25 * variance).toInt();
      case 'Crystals': return (100 * variance).toInt();
      default: return 0;
    }
  }

  void sellResource(String resource, int amount) {
    if (amount <= 0) return;
    
    int price = getResourcePrice(resource);
    int total = price * amount;
    
    bool sold = false;
    if (resource == 'Ore' && ore >= amount) {
      ore -= amount;
      sold = true;
    } else if (resource == 'Gas' && gas >= amount) {
      gas -= amount;
      sold = true;
    } else if (resource == 'Crystals' && crystals >= amount) {
      crystals -= amount;
      sold = true;
    }
    
    if (sold) {
      solars += total;
      missionLogs.insert(0, LogEntry(
        timestamp: DateTime.now(),
        title: "Market Transaction",
        details: "Sold $amount m³ of $resource for ⁂$total.",
        solarChange: total,
        isPositive: true,
      ));
      _triggerUpdate();
    }
  }

  Duration getRepairDuration(Ship ship) {
    double missingCondition = 1.0 - ship.condition;
    int shipValue = getShipSaleValue(ship);
    int seconds = (missingCondition * shipValue * _timeScalingFactor / repairSpeedMultiplier).toInt();
    
    // --- BETA TESTING SWITCH ---
    // Fast repairs
    seconds = (seconds * 0.1).toInt();
    // ---------------------------

    return Duration(seconds: max(2, seconds));
  }

  Duration getUpgradeDuration(Ship ship, int currentLevel) {
    int shipValue = getShipSaleValue(ship);
    int seconds = (shipValue * _timeScalingFactor * (1 + currentLevel * 0.1)).toInt();
    
    // --- BETA TESTING SWITCH ---
    // Fast upgrades
    seconds = (seconds * 0.1).toInt();
    // ---------------------------

    return Duration(seconds: max(2, seconds));
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
  
  void repairAllShips() {
    int totalCost = 0;
    int baseCostTotal = 0;
    bool anyRepaired = false;
    
    // Calculate base multiplier inverse to find savings
    // repairCostMultiplier is 0.9 or 0.75 etc.
    double mult = repairCostMultiplier;
    
    for (var ship in fleet) {
      if (ship.condition < 1.0 && ship.busyUntil == null && ship.missionEndTime == null) {
        int cost = getRepairCost(ship);
        // Reverse engineer base cost (approx)
        int baseCost = (cost / mult).round();
        
        if (solars >= cost) {
          solars -= cost;
          totalCost += cost;
          baseCostTotal += baseCost;
          
          ship.busyUntil = DateTime.now().add(getRepairDuration(ship));
          ship.currentTask = 'Repairing';
          anyRepaired = true;
        }
      }
    }
    
    if (anyRepaired) {
      int saved = baseCostTotal - totalCost;
      String savingsText = saved > 0 ? " (Saved ⁂$saved via Gantry)" : "";
      
      missionLogs.insert(0, LogEntry(
        timestamp: DateTime.now(),
        title: "Fleet Maintenance",
        details: "Batch repair order executed. Total Cost: ⁂$totalCost.$savingsText",
        solarChange: -totalCost,
        isPositive: false,
      ));
      _triggerUpdate();
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
  
  int getTotalRepairCost() {
    int total = 0;
    for (var ship in fleet) {
      if (ship.condition < 1.0 && ship.busyUntil == null && ship.missionEndTime == null) {
        total += getRepairCost(ship);
      }
    }
    return total;
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
    if (!availableMissions.any((m) => m.title.contains("Local Scrap Run"))) {
      availableMissions.add(_missionService.getLocalScrapRun());
    }
    if (!availableMissions.any((m) => m.title.contains("Local Courier Run"))) {
      availableMissions.add(_missionService.getLocalCourierRun());
    }
    _triggerUpdate();
  }

  void generateNewMissions() {
    updateMissions(_missionService.generateMissions(relayLevel, broadcastingArrayLevel, fleet));
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _marketTimer?.cancel(); // Dispose new timer
    super.dispose();
  }
}
