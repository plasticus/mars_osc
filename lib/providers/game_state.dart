import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../models/ship_model.dart';
import '../models/mission_model.dart';
import '../services/mission_service.dart';
import '../services/auth_service.dart';
import '../services/milestone_service.dart';
import '../services/trading_hub_service.dart'; // IMPORT NEW SERVICE
import '../models/log_entry.dart';
import '../utils/game_formulas.dart';
import '../utils/text_generators.dart';
import '../utils/debouncer.dart';
import 'dart:math';
import 'dart:async';

const bool enableDebugButtons = !bool.fromEnvironment('dart.vm.product');

void _applyHullWear(Ship ship) {
  double wear = (ship.missionDistance ?? 1.0) * 0.002 * (1.0 - min(0.5, (ship.shieldLevel + ship.aiLevel * 0.5) * 0.02));
  wear = max(wear, (ship.missionDistance ?? 1.0) * 0.0005) * (0.8 + Random().nextDouble() * 0.4);
  ship.condition = (ship.condition - wear).clamp(0.0, 1.0);
}


class SaveConflict {
  final DateTime localTime;
  final int localNetWorth;
  final int localContracts;

  final DateTime cloudTime;
  final int cloudNetWorth;
  final int cloudContracts;

  SaveConflict({
    required this.localTime, required this.localNetWorth, required this.localContracts,
    required this.cloudTime, required this.cloudNetWorth, required this.cloudContracts,
  });
}


class GameState extends ChangeNotifier with WidgetsBindingObserver {
  int solars = 50000;
  String companyName = "Establishing Link...";
  bool hasNamedCompany = false;
  int totalOreHarvested = 0;
  int totalGasHarvested = 0;
  int totalCrystalsHarvested = 0;
  int totalContractsCompleted = 0;

  // Auth State
  User? currentUser;
  String? _currentUid;

  User? get user => FirebaseAuth.instance.currentUser;

  String? get currentUid => _currentUid;

  // --- NEW USER FLOW VARIABLES ---
  bool isNewUser = false;
  String? initError;
  bool isLoading = false;

  bool get hasLocalSave => _hasLocalSave;
  bool autoCloudBackupEnabled = false;
  bool _loopsStarted = false;
  bool _hasLocalSave = false;

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
  int totalContracts = 0;

  //Prestige
  int tradeDepotPrestige = 0;
  int broadcastingArrayPrestige = 0;
  int serverFarmPrestige = 0;

  int get scanArrayLevel => relayLevel;

  List<Ship> fleet = [];
  List<Mission> availableMissions = [];
  List<LogEntry> missionLogs = [];

  final MissionService _missionService = MissionService();
  late TradingHubService _tradingService;
  final MilestoneService milestoneService = MilestoneService();

  Timer? _gameTimer;

  bool _isInitialized = false;
  bool isBetaTiming = true;

  DateTime? nextMissionRefresh;
  DateTime _lastActiveTime = DateTime.now();
  DateTime _lastLeaderboardWrite = DateTime.fromMillisecondsSinceEpoch(0);


  void forceRefresh() {
    notifyListeners();
  }

  void _unpackSaveBlob(String? blob) async {
    if (blob == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mosc_save', blob); // Save to disk first
    await _loadData(); // Then trigger the existing load sequence
    notifyListeners();
  }

  SaveConflict? activeConflict;

  // 2. Fix the resolution logic to use the stored data
  void resolveConflict({required bool useCloud}) {
    if (useCloud && _pendingCloudData != null) {
      _unpackSaveBlob(_pendingCloudData!['saveBlob']);
      debugPrint("🪐 CONFLICT: Restored Cloud Blob.");
    } else {
      debugPrint("📱 CONFLICT: Kept Local. Cloud will overwrite on next save.");
    }

    activeConflict = null;
    _pendingCloudData = null;
    notifyListeners();
  }


  Future<void> _ensureUserDefaults(String uid) async {
    // We keep this safety check to prevent accidental overwrites during linking
    if (fleet.isNotEmpty &&
        (companyName == "Establishing Link..." ||
            companyName == "Searching Registry...")) {
      debugPrint(
          "⚠️ Safety Gate: Aborting cloud sync to prevent data overwrite.");
      return;
    }

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await ref.get();

    // Only initialize if the document is missing entirely
    if (!snap.exists) {
      await ref.set({
        'hasNamedCompany': false,
        'solars': 50000,
        'isNewUser': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint("📂 CLOUD: Initialized new user document.");
    }
  }

  int get netWorth {
    int liquid = solars;
    int fleetAppraisal = fleet.fold(
        0, (total, ship) => total + getShipSaleValue(ship));
    int facilityValue = calculateBaseUpgradeInvestment();
    return liquid + fleetAppraisal + facilityValue;
  }

  GameState() {
    WidgetsBinding.instance.addObserver(this);

    // 1. Initialize Trading Service with Callback
    _tradingService = TradingHubService(
      onTradeExecuted: (revenue, dOre, dGas, dCrystals, logEntry) {
        solars += revenue;
        ore += dOre;
        gas += dGas;
        crystals += dCrystals;
        if (logEntry != null) _addLog(logEntry);
        _triggerUpdate();
      },
    );

    // 2. Load Local Data
    _loadData().then((_) async {
      _isInitialized = true;

      if (fleet.isEmpty) {
        _setupStarterShip();
      }

      if (availableMissions.isEmpty) {
        generateNewMissions();
      }

      // ✅ Local load finished.
      isLoading = false;
      initError = null;
      notifyListeners();
    }); // { closes .then() }
  } // this closes GameState() Constructor#@!%

  Future<void> connectCloudSession(String uid) async {
    if (_currentUid == uid && _isInitialized) return;

    _currentUid = uid;
    isLoading = true;
    initError = "STATUS: CONTACTING_MARS_RELAY...";
    notifyListeners();

    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final snap = await docRef.get();

      if (!snap.exists) {
        // BRAND NEW USER: Create the doc with defaults
        await _ensureUserDefaults(uid);
        isNewUser = true;
      } else {
        // RETURNING USER: Do NOT run _ensureUserDefaults yet.
        // This protects the cloud data so main.dart can restore it.
        isNewUser = false;
        debugPrint(
            "☁️ CLOUD: Account found. Standing by for main.dart restore.");
      }

      isLoading = false;
      initError = null;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      initError = "ERROR: ${e.toString()}";
      notifyListeners();
    }
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      debugPrint("⏸️ App Paused: Saving State...");
      Future.microtask(() async {
        final prefs = await SharedPreferences.getInstance();
        await _saveLocal(prefs);
        await syncLeaderboardNow();
      });
    }

    if (state == AppLifecycleState.resumed) {
      debugPrint("▶️ App Resumed: Checking Offline Sales...");
      _loadData().then((_) {
        _tradingService.processOfflineCatchup(
          lastActiveTime: _lastActiveTime,
          tradeDepotLevel: tradeDepotLevel,
          maxStorage: maxStorage,
          ore: ore,
          gas: gas,
          crystals: crystals,
        );
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameTimer?.cancel();
    _tradingService.stop();
    super.dispose();
  }

  void _setupStarterShip() {
    fleet = [
      Ship(
        id: "starter_${DateTime
            .now()
            .millisecondsSinceEpoch}",
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
      )
    ];
  }

  void _addLog(LogEntry entry) {
    missionLogs.insert(0, entry);
    if (missionLogs.length > 50) {
      missionLogs.removeRange(50, missionLogs.length);
    }
  }


  Future<void> signInWithGoogle() async {
    final userCredential = await AuthService.signInWithGoogle();
    if (userCredential?.user != null) {
      await connectCloudSession(userCredential!.user!.uid);
    }
  }

  Future<void> signOut() async {
    await AuthService.signOut();
    _currentUid = null;
    // keep _isInitialized as-is
    notifyListeners();
  }

  Future<void> syncLeaderboardNow() async {
    if (_currentUid == null) return;

    final now = DateTime.now();
    // Hard throttle: no more than once every 2 minutes
    if (now
        .difference(_lastLeaderboardWrite)
        .inSeconds < 120) return;

    // Calculate fleet value
    final int fleetValue = fleet.fold(
        0, (total, ship) => total + getShipSaleValue(ship));

    Ship? topShip;
    int topShipVal = 0;
    for (var s in fleet) {
      final val = getShipSaleValue(s);
      if (val > topShipVal) {
        topShipVal = val;
        topShip = s;
      }
    }

    final Map<String, dynamic> leaderboardData = {
      'companyName': companyName,
      'cashOnHand': solars,
      'netWorth': solars + fleetValue + calculateBaseUpgradeInvestment(),
      'totalContracts': totalContracts,
      'topShipValue': topShipVal,
      'topShipNickname': topShip?.nickname ?? "None",
      'topShipClass': topShip?.shipClass ?? "N/A",
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('leaderboard')
          .doc(_currentUid)
          .set(leaderboardData, SetOptions(merge: true));

      _lastLeaderboardWrite = DateTime.now();
      debugPrint("🏆 CLOUD: Leaderboard updated");
    } catch (e) {
      debugPrint("🏆 CLOUD: Leaderboard update failed: $e");
    }
  }

  final _localSaveDebouncer = Debouncer(
      delay: const Duration(milliseconds: 400));

  void _scheduleLocalSave() {
    _localSaveDebouncer.run(() async {
      final prefs = await SharedPreferences.getInstance();
      await _saveLocal(prefs);
    });
  }

  Future<void> _saveLocal(SharedPreferences prefs) async {
    try {
      _lastActiveTime = DateTime.now();

      // 1. Construct the map
      final local = <String, dynamic>{
        'companyName': companyName,
        'solars': solars,
        'crystals': crystals,
        'ore': ore,
        'gas': gas,
        'hangarLevel': hangarLevel,
        'relayLevel': relayLevel, // This should be 4!
        'tradeDepotLevel': tradeDepotLevel,
        'tradeDepotPrestige': tradeDepotPrestige,
        'broadcastingArrayLevel': broadcastingArrayLevel,
        'broadcastingArrayPrestige': broadcastingArrayPrestige,
        'serverFarmLevel': serverFarmLevel,
        'serverFarmPrestige': serverFarmPrestige,
        'repairGantryLevel': repairGantryLevel,
        'nextMissionRefresh': (nextMissionRefresh ?? DateTime.now())
            .toIso8601String(),
        'lastActiveTime': _lastActiveTime.toIso8601String(),
        'fleet': fleet.map((s) => s.toJson()).toList(),
        'missionLogs': missionLogs.map((l) => l.toJson()).toList(),
        'availableMissions': availableMissions.map((m) => m.toJson()).toList(),
        'totalOreHarvested': totalOreHarvested,
        'totalGasHarvested': totalGasHarvested,
        'totalCrystalsHarvested': totalCrystalsHarvested,
        'totalContractsCompleted': totalContractsCompleted,
      };

      // 2. Attempt to Encode
      final String encodedJson = jsonEncode(local);

      // 3. Write to disk
      await prefs.setString('mosc_save', encodedJson);

      debugPrint(
          "✅ SAVE SUCCESS: Wrote Relay Level $relayLevel and ${availableMissions
              .length} missions.");
    } catch (e) {
      debugPrint("🛑 SAVE FAILED: $e");
    }
  }

  Future<void> _loadData() async {
    debugPrint("📂 LOAD: Starting safe load sequence...");
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Try to load the "Box" (New Format)
      final String? jsonStr = prefs.getString('mosc_save');
      _hasLocalSave = (jsonStr != null);


      if (jsonStr != null) {
        final Map<String, dynamic> local = jsonDecode(jsonStr);

        // --- A. LOAD TIMESTAMPS (Safely) ---
        try {
          if (local['lastActiveTime'] != null) {
            _lastActiveTime =
                DateTime.tryParse(local['lastActiveTime']) ?? DateTime.now();
          }
          if (local['nextMissionRefresh'] != null) {
            nextMissionRefresh = DateTime.tryParse(local['nextMissionRefresh']);
          }
        } catch (e) {
          debugPrint("⚠️ LOAD ERROR (Timestamps): $e");
        }

        // --- B. LOAD STATS (Safely) ---
        try {
          companyName = local['companyName'] ?? companyName;
          solars = (local['solars'] as num?)?.toInt() ?? solars;
          ore = (local['ore'] as num?)?.toInt() ?? ore;
          gas = (local['gas'] as num?)?.toInt() ?? gas;
          crystals = (local['crystals'] as num?)?.toInt() ?? crystals;

          hangarLevel = (local['hangarLevel'] as num?)?.toInt() ?? hangarLevel;
          relayLevel = (local['relayLevel'] as num?)?.toInt() ?? relayLevel;
          tradeDepotLevel =
              (local['tradeDepotLevel'] as num?)?.toInt() ?? tradeDepotLevel;
          tradeDepotPrestige = (local['tradeDepotPrestige'] as num?)?.toInt() ??
              tradeDepotPrestige;
          broadcastingArrayLevel =
              (local['broadcastingArrayLevel'] as num?)?.toInt() ??
                  broadcastingArrayLevel;
          broadcastingArrayPrestige =
              (local['broadcastingArrayPrestige'] as num?)?.toInt() ??
                  broadcastingArrayPrestige;
          serverFarmLevel =
              (local['serverFarmLevel'] as num?)?.toInt() ?? serverFarmLevel;
          serverFarmPrestige = (local['serverFarmPrestige'] as num?)?.toInt() ??
              serverFarmPrestige;
          repairGantryLevel = (local['repairGantryLevel'] as num?)?.toInt() ??
              repairGantryLevel;
          totalOreHarvested =
              (local['totalOreHarvested'] as num?)?.toInt() ?? 0;
          totalGasHarvested =
              (local['totalGasHarvested'] as num?)?.toInt() ?? 0;
          totalCrystalsHarvested =
              (local['totalCrystalsHarvested'] as num?)?.toInt() ?? 0;
          totalContractsCompleted =
              (local['totalContractsCompleted'] as num?)?.toInt() ?? 0;
        } catch (e) {
          debugPrint("⚠️ LOAD ERROR (Stats): $e");
        }

        // --- C. LOAD LISTS (Safely) ---

        // Fleet
        try {
          if (local['fleet'] != null) {
            fleet = (local['fleet'] as List)
                .map((m) => Ship.fromJson(Map<String, dynamic>.from(m)))
                .toList();
          }
        } catch (e) {
          debugPrint("⚠️ LOAD ERROR (Fleet): $e");
        }

        // Logs
        try {
          if (local['missionLogs'] != null) {
            missionLogs = (local['missionLogs'] as List)
                .map((m) => LogEntry.fromJson(Map<String, dynamic>.from(m)))
                .toList();
          }
        } catch (e) {
          debugPrint("⚠️ LOAD ERROR (Logs): $e");
        }

        // Missions (The likely culprit)
        try {
          if (local['availableMissions'] != null) {
            availableMissions = (local['availableMissions'] as List)
                .map((m) => Mission.fromJson(Map<String, dynamic>.from(m)))
                .toList();
            debugPrint(
                "✅ LOAD: Restored ${availableMissions.length} missions.");
          }
        } catch (e) {
          debugPrint("⚠️ LOAD ERROR (Missions): $e");
          // If missions fail to load, we clear the list so the Safety Check generates new ones
          availableMissions = [];
        }
      } else {
        // --- PATH B: LEGACY FALLBACK ---
        debugPrint("⚠️ LOAD: No box found, trying legacy keys...");
        // (Keep your existing legacy loading logic here if you want,
        // or just let it start fresh since you reinstalled)
        relayLevel = prefs.getInt('relayLevel') ?? 1;
        // ... etc ...
      }
    } catch (e) {
      debugPrint("🛑 CRITICAL LOAD FAILURE: $e");
    }
  }

  DateTime? _lastCloudSave; // Track the last successful sync

  Future<void> uploadLocalSaveToCloud({bool force = false}) async {
    if (_currentUid == null) return;

    // 1. COOLDOWN GATE: Skip if we synced less than 5 minutes ago
    final now = DateTime.now();
    if (!force && _lastCloudSave != null &&
        now.difference(_lastCloudSave!) < const Duration(minutes: 5)) {
      debugPrint("☁️ CLOUD: Sync skipped (Cooldown active).");
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // 2. Ensure local is freshly saved first
    await _saveLocal(prefs);

    final jsonStr = prefs.getString('mosc_save');
    if (jsonStr == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .set({
        'saveBlob': jsonStr,
        'saveVersion': 1,
        'saveLastActiveTime': _lastActiveTime.toIso8601String(),
        'saveUpdatedAt': FieldValue.serverTimestamp(),
        'netWorth': netWorth,
        'solars': solars,
        'totalContractsCompleted': totalContractsCompleted,
      }, SetOptions(merge: true));

      _lastCloudSave = now; // 3. Update the cooldown timer on success
      debugPrint("✅ CLOUD: Save successful for $companyName.");
    } catch (e) {
      debugPrint("❌ CLOUD: Save failed: $e");
    }
  }

  Map<String, dynamic>? _pendingCloudData;

  Future<void> restoreFromCloudIfNewer({bool force = false}) async {
    if (_currentUid == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(_currentUid);
    final snap = await ref.get();
    if (!snap.exists) return;

    final cloudData = snap.data()!;
    final cloudTimeStr = cloudData['saveLastActiveTime'] as String?;
    final cloudTime = cloudTimeStr != null
        ? DateTime.tryParse(cloudTimeStr)
        : null;

    // 1. If forcing (manual sync), skip the check and just load
    if (force) {
      _unpackSaveBlob(cloudData['saveBlob']);
      return;
    }

    // 2. CONFLICT CHECK: Local is newer than Cloud by > 1 minute
    if (cloudTime != null &&
        _lastActiveTime.isAfter(cloudTime.add(const Duration(minutes: 1)))) {
      _pendingCloudData = cloudData;
      activeConflict = SaveConflict(
        localTime: _lastActiveTime,
        localNetWorth: netWorth,
        localContracts: totalContractsCompleted,
        cloudTime: cloudTime,
        cloudNetWorth: (cloudData['netWorth'] as num?)?.toInt() ?? 0,
        cloudContracts: (cloudData['totalContractsCompleted'] as num?)
            ?.toInt() ?? 0,
      );
      notifyListeners();
      return;
    }

    // 3. Normal path: Cloud is newer or same age, just load it
    _unpackSaveBlob(cloudData['saveBlob']);
  }


  Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    solars = 50000;
    companyName = TextGenerators.generateCompanyName();
    ore = 0;
    gas = 0;
    crystals = 0;
    hangarLevel = 1;
    relayLevel = 1;
    serverFarmLevel = 0;
    tradeDepotLevel = 1;
    repairGantryLevel = 0;
    broadcastingArrayLevel = 1;
    hasNamedCompany = false;
    fleet = [];
    missionLogs = [];
    nextMissionRefresh = null;
    _setupStarterShip();
    _isInitialized = true;
    notifyListeners();
  }

  void _triggerUpdate() {
    // NEW: Do not trigger an auto-save if we are still initializing
    if (companyName == "Establishing Link..." ||
        companyName == "Searching Registry...") {
      debugPrint("💾 SAVE BLOCKED: Still in link-establishment phase.");
      return;
    }

    _scheduleLocalSave();
    notifyListeners();
  }


  int get maxFleetSize => hangarLevel == 1 ? 2 : hangarLevel * 2;

  int get maxStorage => (tradeDepotLevel * 500) + (tradeDepotPrestige * 100);

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

  // UI-facing bonus summaries
  int get tradeDepotAutoSellPriceBonusPct => tradeDepotLevel * 5;

  int get tradeDepotAutoSellVolumeBonusPct => tradeDepotLevel * 1;

  int get tradeDepotAutoSellQuotaUnitsPerTickBase {
    final basePercent = tradeDepotLevel * 0.01;
    return (maxStorage * basePercent).round();
  }

  int get contractsPerCategory {
    final perCat = 2 + ((broadcastingArrayLevel - 1) * 2);
    return perCat.clamp(2, 10);
  }

  int get bonusContractsPerCategory => contractsPerCategory - 2;

  double get broadcastingArrayValueBonusPct => broadcastingArrayPrestige * 0.1;

  double get repairCostMultiplier {
    if (repairGantryLevel == 1) return 0.90;
    if (repairGantryLevel == 2) return 0.75;
    return 1.0;
  }

  double get repairSpeedMultiplier => repairGantryLevel == 3 ? 2.0 : 1.0;

  void _startGameLoop() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      bool changesMade = false;

      if (nextMissionRefresh == null) {
        generateNewMissions();
      } else if (now.isAfter(nextMissionRefresh!)) {
        generateNewMissions();
        changesMade = true;
      }

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
        _triggerUpdate();
      }
    });
  }

  void startLoopsIfNeeded() {
    if (_loopsStarted) return;
    _loopsStarted = true;

    // Execute offline catchup BEFORE starting loops (same as you had)
    _tradingService.processOfflineCatchup(
      lastActiveTime: _lastActiveTime,
      tradeDepotLevel: tradeDepotLevel,
      maxStorage: maxStorage,
      ore: ore,
      gas: gas,
      crystals: crystals,
    );

    // Start the main game loop
    _startGameLoop();

    // Start the Trading Hub loop (same as you had)
    _tradingService.startTradingLoop(
      requestCurrentState: () =>
      {
        'level': tradeDepotLevel,
        'maxStorage': maxStorage,
        'ore': ore,
        'gas': gas,
        'crystals': crystals,
      },
    );

    debugPrint('🔁 LOOPS: Started');
  }


  void debugSave() {
    debugPrint("🔘 DEBUG: Force Save Initiated");
    _triggerUpdate(); // This triggers _saveLocal immediately
  }

  void manualSellAll() {
    if (ore == 0 && gas == 0 && crystals == 0) return;

    int revenue = 0;
    revenue += ore * getResourcePrice('Ore');
    revenue += gas * getResourcePrice('Gas');
    revenue += crystals * getResourcePrice('Crystals');

    _addLog(LogEntry(
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

  void _processMaintenanceCompletion(Ship ship) {
    if (ship.currentTask == 'Repairing') {
      ship.condition = 1.0;
      _addLog(LogEntry(
        timestamp: DateTime.now(),
        title: "Repair Complete",
        details: "${ship.isMaxed ? '[Elite] ' : ''}${ship
            .nickname} maintenance finished. Hull at 100%.",
      ));
    } else if (ship.currentTask == 'Upgrading') {
      if (ship.isMaxed) {
        if (!ship.hasBeenRenamed) {
          ship.nickname = GameFormulas.generateLegacyName();
          ship.hasBeenRenamed = true;
        }
        ship.renameLocked = true;

        _addLog(LogEntry(
          timestamp: DateTime.now(),
          title: "ELITE TRANSFORMATION",
          details: "${ship
              .nickname} has achieved Elite Status. Attributes Gained: Vanguard Honorarium, Priority Docking, Bleeding Edge Tech, and Legacy Designation",
          isPositive: true,
        ));
      } else {
        _addLog(LogEntry(
          timestamp: DateTime.now(),
          title: "Upgrade Installed",
          details: "${ship.nickname} systems have been enhanced.",
        ));
      }
    }

    ship.busyUntil = null;
    ship.currentTask = null;
  }

  void startMission(String shipId, Mission mission) {
    final shipIndex = fleet.indexWhere((s) => s.id == shipId);
    if (shipIndex != -1) {
      final now = DateTime.now();
      final ship = fleet[shipIndex];

      Duration missionDuration = GameFormulas.calculateMissionDuration(
        distanceAU: mission.distanceAU,
        speed: ship.speed,
        ai: ship.aiLevel,
        isBetaTiming: isBetaTiming,
        isElite: ship.isMaxed,
        shipClass: ship.shipClass,
      );

      ship.missionStartTime = now;
      ship.missionEndTime = now.add(missionDuration);

      ship.currentMissionName = mission.title;
      ship.pendingReward = mission.rewardSolars;
      ship.pendingResource = mission.rewardResource;
      ship.pendingResourceAmount = mission.rewardResourceAmount;
      ship.missionDistance = mission.distanceAU;

      availableMissions.removeWhere((m) => m.id == mission.id);

      //repeatable contracts here
      if (mission.title.contains("Local Scrap Run")) {
        availableMissions.add(_missionService.getLocalScrapRun());
      } else if (mission.title.contains("Local Courier Run")) {
        availableMissions.add(_missionService.getLocalCourierRun());
      } else if (mission.title.contains("Belt Skimming")) {
        availableMissions.add(_missionService.getLocalMiningRun());
      } else if (mission.title.contains("Vent Siphoning")) {
        availableMissions.add(_missionService.getLocalGasRun());
      } else if (mission.title.contains("Belt Anomaly Sweep")) {
        availableMissions.add(_missionService.getLocalRiftRun());
      }
      _addLog(LogEntry(
        timestamp: now,
        title: "Contract Launched",
        details: "${ship.isMaxed ? '[Elite] ' : ''}${ship
            .nickname} sent to ${mission.title}.",
        isPositive: true,
        distance: mission.distanceAU,
      ));
      milestoneService.requestCheck(this);
      _triggerUpdate();
    }
  }

  void _processMissionCompletion(Ship ship) {
    // 1. Calculate results first
    final results = GameFormulas.calculateFullMissionResults(
      pendingReward: ship.pendingReward,
      pendingResource: ship.pendingResource,
      pendingResourceAmount: ship.pendingResourceAmount,
      aiLevel: ship.aiLevel,
      isElite: ship.isMaxed,
      modelName: ship.modelName,
      broadcastingPrestige: broadcastingArrayPrestige,
      currentStorageUsed: (ore + gas + crystals),
      maxStorage: maxStorage,
    );

    // 2. Track LIFETIME stats for milestones
    totalContractsCompleted++;
    if (results.resourceType == 'Ore')
      totalOreHarvested += results.resourceAmount;
    if (results.resourceType == 'Gas')
      totalGasHarvested += results.resourceAmount;
    if (results.resourceType == 'Crystals')
      totalCrystalsHarvested += results.resourceAmount;

    // 3. Update the Wallet and Inventory
    solars += results.totalSolars;
    if (results.resourceType == 'Ore') ore += results.resourceAmount;
    if (results.resourceType == 'Gas') gas += results.resourceAmount;
    if (results.resourceType == 'Crystals') crystals += results.resourceAmount;

    // 4. Create the log with DISTANCE
    _addLog(LogEntry(
      timestamp: DateTime.now(),
      title: "Contract Completed: ${ship.nickname}",
      details: "Earnings: ⁂${results.totalSolars}${results.resourceAmount > 0 ? ' '
          'and ${results.resourceAmount}m³ ${results.resourceType}' : ''}",
      isPositive: true,
      distance: ship.missionDistance ?? 0.0, // Assumes Ship has missionDistance
    ));

    _applyHullWear(ship);
    milestoneService.requestCheck(this); // Trigger the 5s debouncer
    ship.clearMissionData();
    _triggerUpdate();
  }

  int getResourcePrice(String resource) {
    double variance = 1.0 + (sin(DateTime
        .now()
        .minute / 10) * 0.2);
    if (resource == 'Ore') return (10 * variance).toInt();
    if (resource == 'Gas') return (25 * variance).toInt();
    if (resource == 'Crystals') return (100 * variance).toInt();
    return 0;
  }

  void sellResource(String resource, int amount) {
    int total = getResourcePrice(resource) * amount;
    bool sold = false;
    if (resource == 'Ore' && ore >= amount) {
      ore -= amount;
      sold = true;
    }
    else if (resource == 'Gas' && gas >= amount) {
      gas -= amount;
      sold = true;
    }
    else if (resource == 'Crystals' && crystals >= amount) {
      crystals -= amount;
      sold = true;
    }

    if (sold) {
      solars += total;
      _addLog(LogEntry(
        timestamp: DateTime.now(),
        title: "Market Transaction",
        details: "Sold $amount m³ of $resource for ⁂$total.",
        solarChange: total,
      ));
      _triggerUpdate();
    }
  }

  // --- SINGLE SHIP REPAIR ---
  void repairShip(String shipId) {
    final idx = fleet.indexWhere((s) => s.id == shipId);
    if (idx == -1) return;

    final s = fleet[idx];

    if (s.busyUntil != null || s.missionEndTime != null) return;
    if (s.condition >= 1.0) return;

    final cost = getRepairCost(s);
    if (solars < cost) return;

    solars -= cost;
    s.isRepairing = true;
    s.currentTask = 'Repairing';
    s.busyUntil = DateTime.now().add(
        GameFormulas.calculateRepairDuration(s, repairSpeedMultiplier));

    _addLog(LogEntry(
      timestamp: DateTime.now(),
      title: "Repair Started",
      details: "${s.nickname} entered dry dock. Cost: ⁂$cost.",
      solarChange: -cost,
      isPositive: false,
    ));

    _triggerUpdate();
  }

  void repairAllShips() {
    int total = 0;
    for (var s in fleet) {
      if (s.condition < 1.0 && s.busyUntil == null &&
          s.missionEndTime == null) {
        int cost = getRepairCost(s);
        if (solars >= cost) {
          solars -= cost;
          total += cost;
          s.busyUntil = DateTime.now().add(
              GameFormulas.calculateRepairDuration(s, repairSpeedMultiplier));
          s.currentTask = 'Repairing';
        }
      }
    }
    if (total > 0) {
      _addLog(LogEntry(timestamp: DateTime.now(),
          title: "Fleet Maintenance",
          details: "Batch repair executed. Total: ⁂$total.",
          solarChange: -total,
          isPositive: false));
      _triggerUpdate();
    }
  }

  bool upgradeShipStat(String shipId, String stat) {
    final idx = fleet.indexWhere((s) => s.id == shipId);
    if (idx == -1) return false;
    final s = fleet[idx];
    if (s.busyUntil != null || s.missionEndTime != null) return false;

    int cur = 0,
        mx = 0;
    if (stat == 'speed') {
      cur = s.speed;
      mx = s.maxSpeed;
    }
    else if (stat == 'cargo') {
      cur = s.cargoCapacity;
      mx = s.maxCargo;
    }
    else if (stat == 'fuel') {
      cur = s.fuelCapacity;
      mx = s.maxFuel;
    }
    else if (stat == 'shield') {
      cur = s.shieldLevel;
      mx = s.maxShield;
    }
    else if (stat == 'ai') {
      cur = s.aiLevel;
      mx = s.maxAI;
    }

    int cost = GameFormulas.calculateUpgradeCost(
        modelName: s.modelName, currentLevel: cur);
    if (solars >= cost && cur < mx) {
      solars -= cost;
      if (stat == 'speed') {
        s.speed++;
      } else if (stat == 'cargo')
        s.cargoCapacity++;
      else if (stat == 'fuel')
        s.fuelCapacity++;
      else if (stat == 'shield')
        s.shieldLevel++;
      else if (stat == 'ai') s.aiLevel++;

      bool becomingElite = s.isMaxed && !s.renameLocked;

      if (becomingElite) {
        if (!s.hasBeenRenamed) {
          s.nickname = GameFormulas.generateLegacyName();
          s.hasBeenRenamed = true;
        }
        s.renameLocked = true;
      }

      s.busyUntil = DateTime.now().add(GameFormulas.calculateUpgradeDuration(
          modelName: s.modelName,
          currentLevel: cur,
          repairSpeedMultiplier: repairSpeedMultiplier
      ));
      s.currentTask = 'Upgrading';

      _triggerUpdate();
      return becomingElite;
    }
    return false;
  }

  int getRepairCost(Ship s) =>
      ((1.0 - s.condition) * (getShipSaleValue(s) * 0.2) * repairCostMultiplier)
          .toInt();

  void upgradeBase(String type, int cost) {
    if (solars >= cost) {
      solars -= cost;
      int newLevel = 0;

      if (type == 'Hangar') {
        hangarLevel++;
        newLevel = hangarLevel;
      } else if (type == 'Relay') {
        relayLevel++;
        newLevel = relayLevel;
      } else if (type == 'Server') {
        serverFarmLevel++;
        newLevel = serverFarmLevel;
      } else if (type == 'Depot') {
        tradeDepotLevel++;
        newLevel = tradeDepotLevel;
      } else if (type == 'Gantry') {
        repairGantryLevel++;
        newLevel = repairGantryLevel;
      } else if (type == 'Broadcasting') {
        broadcastingArrayLevel++;
        newLevel = broadcastingArrayLevel;
      }

      _addLog(LogEntry(
        timestamp: DateTime.now(),
        title: "Base Upgraded",
        details: "$type reached Level $newLevel",
        solarChange: -cost,
        isPositive: false,
      ));

      _triggerUpdate();
    }
    _scheduleLocalSave();
    notifyListeners();
  }

  int getTradeDepotPrestigeCost() {
    const base = 2000;
    const growth = 1.18;
    return (base * pow(growth, tradeDepotPrestige)).round();
  }

  void upgradeTradeDepotPrestige() {
    const int maxDepotLevel = 5;
    if (tradeDepotLevel < maxDepotLevel) return;

    final cost = getTradeDepotPrestigeCost();
    if (solars < cost) return;

    solars -= cost;
    tradeDepotPrestige += 1;

    _addLog(LogEntry(
      timestamp: DateTime.now(),
      title: "Trade Depot Prestige",
      details: "Overflow Storage +100 m³ (Prestige $tradeDepotPrestige)",
      solarChange: -cost,
      isPositive: false,
    ));

    _triggerUpdate();
  }

  int getBroadcastingArrayPrestigeCost() {
    const base = 2000;
    const growth = 1.2;
    return (base * pow(growth, broadcastingArrayPrestige)).round();
  }

  void upgradeBroadcastingArrayPrestige() {
    const int maxLevel = 5;
    if (broadcastingArrayLevel < maxLevel) return;

    final cost = getBroadcastingArrayPrestigeCost();
    if (solars < cost) return;

    solars -= cost;
    broadcastingArrayPrestige += 1;

    _addLog(LogEntry(
      timestamp: DateTime.now(),
      title: "Broadcasting Prestige",
      details: "Brand Reach +0.1% (Prestige $broadcastingArrayPrestige)",
      solarChange: -cost,
      isPositive: false,
    ));

    _triggerUpdate();
  }

  int getServerFarmPrestigeCost() {
    const base = 2000;
    const growth = 1.2;
    return (base * pow(growth, serverFarmPrestige)).round();
  }

  void upgradeServerFarmPrestige() {
    const int maxLevel = 3;
    if (serverFarmLevel < maxLevel) return;

    final cost = getServerFarmPrestigeCost();
    if (solars < cost) return;

    solars -= cost;
    serverFarmPrestige += 1;

    _addLog(LogEntry(
      timestamp: DateTime.now(),
      title: "Server Farm Prestige",
      details: "Contract Speed +0.1% (Prestige $serverFarmPrestige)",
      solarChange: -cost,
      isPositive: false,
    ));

    _triggerUpdate();
  }

  int getShipSaleValue(Ship s) {
    return GameFormulas.calculateShipValue(
      basePrice: GameFormulas.getTemplatePrice(s.modelName),
      upgradeInvestment: GameFormulas.calculateTotalUpgradeInvestment(s),
      condition: s.condition,
      isElite: s.isMaxed,
    );
  }

  void sellShip(String id) {
    final idx = fleet.indexWhere((s) => s.id == id);
    if (idx != -1 && fleet[idx].missionEndTime == null &&
        fleet[idx].busyUntil == null) {
      int val = getShipSaleValue(fleet[idx]);
      solars += val;
      _addLog(LogEntry(timestamp: DateTime.now(),
          title: "Ship Decommissioned",
          details: "${fleet[idx].nickname} salvaged for ⁂$val.",
          solarChange: val));
      fleet.removeAt(idx);
      _triggerUpdate();
    }
  }

  bool buyShip(Ship s, int cost) {
    int actualCost = GameFormulas.getTemplatePrice(s.modelName);
    int currentLimit = hangarLevel == 1 ? 2 : hangarLevel * 2;

    if (solars >= actualCost && fleet.length < currentLimit) {
      solars -= actualCost;
      fleet.add(s);
      _injectLocalMissionForClass(s.shipClass);
      _addLog(LogEntry(
          timestamp: DateTime.now(),
          title: "Fleet Expansion",
          details: "Purchased ${s.modelName} \"${s.nickname}\".",
          solarChange: -actualCost,
          isPositive: false
      ));
      _triggerUpdate();
      return true;
    }
    return false;
  }

  void _injectLocalMissionForClass(String shipClass) {
    String targetTitle = "";
    Mission? newMission;

    switch (shipClass) {
      case 'Mule':
        targetTitle = "Local Scrap Run";
        newMission = _missionService.getLocalScrapRun();
        break;
      case 'Sprinter':
        targetTitle = "Local Courier Run";
        newMission = _missionService.getLocalCourierRun();
        break;
      case 'Miner':
        targetTitle = "Local Ore Run";
        newMission = _missionService.getLocalMiningRun();
        break;
      case 'Tanker':
        targetTitle = "Local Gas Run";
        newMission = _missionService.getLocalGasRun();
        break;
      case 'Harvester':
        targetTitle = "Local Rift Run";
        newMission = _missionService.getLocalRiftRun();
        break;
    }

    if (newMission != null &&
        !availableMissions.any((m) => m.title == targetTitle)) {
      availableMissions.add(newMission);
    }
  }

  void renameShip(String id, String name) {
    final idx = fleet.indexWhere((s) => s.id == id);
    if (idx != -1 && name.isNotEmpty) {
      final s = fleet[idx];

      if (s.renameLocked) {
        debugPrint(
            "COREY_LOG: Rename blocked. ${s.nickname} is a Legacy vessel.");
        return;
      }

      int cost = s.hasBeenRenamed ? 100 : 0;
      if (solars >= cost) {
        solars -= cost;
        s.nickname = name;
        s.hasBeenRenamed = true;
        _triggerUpdate();
      }
    }
  }

  void setInitialCompanyName(String name) {
    companyName = name;
    hasNamedCompany = true;
    isNewUser = false;
    _triggerUpdate();
  }

  int getTotalRepairCost() {
    int total = 0;
    for (var s in fleet) {
      if (s.condition < 1.0 && s.busyUntil == null &&
          s.missionEndTime == null) {
        total += getRepairCost(s);
      }
    }
    return total;
  }

  void updateMissions(List<Mission> newMissions) {
    availableMissions = newMissions;

    if (!availableMissions.any((m) => m.title.contains("Local Scrap Run"))) {
      availableMissions.add(_missionService.getLocalScrapRun());
    }
    if (!availableMissions.any((m) => m.title.contains("Local Courier Run"))) {
      availableMissions.add(_missionService.getLocalCourierRun());
    }

    if (fleet.any((s) => s.shipClass == 'Miner') &&
        !availableMissions.any((m) => m.requiredClass == 'Miner')) {
      availableMissions.add(_missionService.getLocalMiningRun());
    }

    if (fleet.any((s) => s.shipClass == 'Tanker') &&
        !availableMissions.any((m) => m.requiredClass == 'Tanker')) {
      availableMissions.add(_missionService.getLocalGasRun());
    }

    if (fleet.any((s) => s.shipClass == 'Harvester') &&
        !availableMissions.any((m) => m.requiredClass == 'Harvester')) {
      availableMissions.add(_missionService.getLocalRiftRun());
    }

    _triggerUpdate();
  }

  void generateNewMissions() {
    updateMissions(_missionService.generateMissions(
        relayLevel, broadcastingArrayLevel, fleet));
    final now = DateTime.now();
    int currentHour = now.hour;
    int nextHour = (currentHour % 2 == 0) ? currentHour + 2 : currentHour + 1;
    if (nextHour >= 24) {
      final tomorrow = now.add(const Duration(days: 1));
      nextMissionRefresh =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 0, 0);
    } else {
      nextMissionRefresh =
          DateTime(now.year, now.month, now.day, nextHour, 0, 0);
    }
    _triggerUpdate();
  }

  int calculateBaseUpgradeInvestment() {
    int total = 0;
    total += _sumBaseCategoryCost('Hangar', hangarLevel, 1);
    total += _sumBaseCategoryCost('Relay', relayLevel, 1);
    total += _sumBaseCategoryCost('Server', serverFarmLevel, 0);
    total += _sumBaseCategoryCost('Depot', tradeDepotLevel, 1);
    total += _sumBaseCategoryCost('Gantry', repairGantryLevel, 0);
    total += _sumBaseCategoryCost('Broadcasting', broadcastingArrayLevel, 1);
    return total;
  }

  int _sumBaseCategoryCost(String type, int currentLevel, int startLevel) {
    int categoryTotal = 0;
    for (int i = startLevel; i < currentLevel; i++) {
      categoryTotal += getBaseUpgradeCost(type, i);
    }
    return categoryTotal;
  }

  int getBaseUpgradeCost(String type, int level) {
    switch (type) {
      case 'Hangar':
        return (5000 * pow(2, level)).toInt();
      case 'Relay':
        return (10000 * pow(2.5, level)).toInt();
      default:
        return (2500 * pow(1.8, level)).toInt();
    }
  }

  Future<void> nuclearReset() async {
    if (_currentUid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .delete();
      await FirebaseFirestore.instance.collection('leaderboard').doc(
          _currentUid).delete();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      _gameTimer?.cancel();
      // Service timer cancel is handled by service.stop() if exposed, or auto GC when GameState dies.

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
      tradeDepotPrestige = 0;
      broadcastingArrayPrestige = 0;
      serverFarmPrestige = 0;
      totalContracts = 0;
      hasNamedCompany = false;

      fleet = [];
      missionLogs = [];
      availableMissions = [];

      _setupStarterShip();

      _isInitialized = false;
      await signOut();

      notifyListeners();
    } catch (e) {
      debugPrint("COREY_LOG: Reset failed: $e");
    }
  }

  void debugSimulateOfflineTime(int minutes) {
    debugPrint("🕒 DEBUG: Simulating $minutes minutes of offline time...");

    // 1. Create a fake timestamp in the past
    final fakeLastActive = DateTime.now().subtract(Duration(minutes: minutes));

    // 2. Force the Trading Service to catch up from that fake time
    _tradingService.processOfflineCatchup(
      lastActiveTime: fakeLastActive,
      tradeDepotLevel: tradeDepotLevel,
      maxStorage: maxStorage,
      ore: ore,
      gas: gas,
      crystals: crystals,
    );

    // 3. Force a UI refresh so you see the logs immediately
    notifyListeners();
  }
}