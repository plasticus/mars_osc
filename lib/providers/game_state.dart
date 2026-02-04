import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../models/ship_model.dart';
import '../models/mission_model.dart';
import '../services/mission_service.dart';
import '../services/auth_service.dart';
import '../services/trading_hub_service.dart'; // IMPORT NEW SERVICE
import '../models/log_entry.dart';
import '../utils/game_formulas.dart';
import '../utils/text_generators.dart';
import '../utils/debouncer.dart';
import 'dart:math';
import 'dart:async';

const bool enableDebugButtons = !bool.fromEnvironment('dart.vm.product');

final _cloudSaveDebouncer = Debouncer(delay: const Duration(seconds: 30));

void _applyHullWear(Ship ship) {
  double wear = (ship.missionDistance ?? 1.0) * 0.002 * (1.0 - min(0.5, (ship.shieldLevel + ship.aiLevel * 0.5) * 0.02));
  wear = max(wear, (ship.missionDistance ?? 1.0) * 0.0005) * (0.8 + Random().nextDouble() * 0.4);
  ship.condition = (ship.condition - wear).clamp(0.0, 1.0);
}

class GameState extends ChangeNotifier with WidgetsBindingObserver {
  int solars = 50000;
  String companyName = "Establishing Link...";
  bool hasNamedCompany = false;

  // Auth State
  User? currentUser;
  String? _currentUid;

  User? get user => FirebaseAuth.instance.currentUser;
  String? get currentUid => _currentUid;

  // --- NEW USER FLOW VARIABLES ---
  bool isNewUser = false;
  String? initError;
  bool isLoading = false;

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
  late TradingHubService _tradingService; // NEW SERVICE

  Timer? _gameTimer;
  // Timer? _marketTimer; // REMOVED OLD TIMER

  bool _isInitialized = false;
  bool isBetaTiming = true;

  DateTime? nextMissionRefresh;
  DateTime _lastActiveTime = DateTime.now(); // NEW FIELD FOR OFFLINE CALC

  void forceRefresh() {
    notifyListeners();
  }

  Future<void> _ensureUserDefaults(String uid) async {
    if (companyName == "Establishing Link..." || companyName == "Searching Registry...") {
      debugPrint("⚠️ Safety Gate: Aborting cloud sync to prevent data overwrite.");
      return;
    }

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? <String, dynamic>{};
    final Map<String, dynamic> missing = {};

    void ensure(String key, dynamic value) {
      if (!data.containsKey(key)) missing[key] = value;
    }

    if (companyName != "Establishing Link..." && companyName != "Searching Registry...") {
      ensure('companyName', companyName);
    }
    ensure('hasNamedCompany', hasNamedCompany);
    ensure('solars', solars);
    ensure('ore', ore);
    ensure('gas', gas);
    ensure('crystals', crystals);
    ensure('hangarLevel', hangarLevel);
    ensure('relayLevel', relayLevel);
    ensure('serverFarmLevel', serverFarmLevel);
    ensure('tradeDepotLevel', tradeDepotLevel);
    ensure('repairGantryLevel', repairGantryLevel);
    ensure('broadcastingArrayLevel', broadcastingArrayLevel);
    ensure('tradeDepotPrestige', tradeDepotPrestige);
    ensure('broadcastingArrayPrestige', broadcastingArrayPrestige);
    ensure('serverFarmPrestige', serverFarmPrestige);
    ensure('nextMissionRefresh', (nextMissionRefresh ?? DateTime.now()).toIso8601String());
    ensure('lastActiveTime', _lastActiveTime.toIso8601String()); // ENSURE CLOUD HAS TIME

    if (missing.isNotEmpty) {
      if (snap.exists) {
        await ref.update(missing);
      } else {
        await ref.set(missing);
      }
    }
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
      }
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

      // 3. EXECUTE OFFLINE CATCHUP *BEFORE* STARTING GAME LOOP
      // This ensures storage is cleared before ships land.
      _tradingService.processOfflineCatchup(
        lastActiveTime: _lastActiveTime,
        tradeDepotLevel: tradeDepotLevel,
        maxStorage: maxStorage,
        ore: ore,
        gas: gas,
        crystals: crystals
      );

      // 4. Start Loops
      _startGameLoop();

      // Start the new Trading Hub loop
      _tradingService.startTradingLoop(
        requestCurrentState: () => {
          'level': tradeDepotLevel,
          'maxStorage': maxStorage,
          'ore': ore,
          'gas': gas,
          'crystals': crystals,
        }
      );

      // 5. Auth Check
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) {
        await initializeUserSession(u.uid);
      } else {
        isLoading = false;
        initError = null;
        notifyListeners();
      }
    });
  }

  @override
    void didChangeAppLifecycleState(AppLifecycleState state) {
      if (state == AppLifecycleState.paused) {
        // User left the app: Save now to lock in the "Last Active" time
        debugPrint("⏸️ App Paused: Saving State...");
        _triggerUpdate();
      }

      if (state == AppLifecycleState.resumed) {
        // User came back: Run the Catch-up logic!
        debugPrint("▶️ App Resumed: Checking Offline Sales...");
        _loadData().then((_) {
           // Reload data first to ensure we have the latest timestamp, then process
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
      WidgetsBinding.instance.removeObserver(this); // <--- CLEANUP
      _gameTimer?.cancel();
      _tradingService.stop();
      super.dispose();
    }

  void _setupStarterShip() {
    fleet = [
      Ship(
        id: "starter_${DateTime.now().millisecondsSinceEpoch}",
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

  Future<void> initializeUserSession(String uid) async {
    if (_currentUid == uid && _isInitialized) return;

    _currentUid = uid;
    isLoading = true;
    initError = "STATUS: CONTACTING_MARS_RELAY...";
    notifyListeners();

    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final snap = await docRef.get();

      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        _applyCloudData(data);
        await _ensureUserDefaults(uid);
      } else {
        await _ensureUserDefaults(uid);
        isNewUser = true;
      }

      final prefs = await SharedPreferences.getInstance();
      await _saveLocal(prefs);

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

  void _applyCloudData(Map<String, dynamic> data) {
    companyName = (data['companyName'] as String?) ?? companyName;
    solars = (data['solars'] as int?) ?? solars;
    crystals = (data['crystals'] as int?) ?? crystals;
    ore = (data['ore'] as int?) ?? ore;
    gas = (data['gas'] as int?) ?? gas;

    hangarLevel = (data['hangarLevel'] as int?) ?? hangarLevel;
    relayLevel = (data['relayLevel'] as int?) ?? relayLevel;
    tradeDepotLevel = (data['tradeDepotLevel'] as int?) ?? tradeDepotLevel;
    tradeDepotPrestige = (data['tradeDepotPrestige'] as int?) ?? tradeDepotPrestige;
    broadcastingArrayLevel = (data['broadcastingArrayLevel'] as int?) ?? broadcastingArrayLevel;
    broadcastingArrayPrestige = (data['broadcastingArrayPrestige'] as int?) ?? broadcastingArrayPrestige;
    serverFarmLevel = (data['serverFarmLevel'] as int?) ?? serverFarmLevel;
    serverFarmPrestige = (data['serverFarmPrestige'] as int?) ?? serverFarmPrestige;
    repairGantryLevel = (data['repairGantryLevel'] as int?) ?? repairGantryLevel;

    final nextRefreshStr = data['nextMissionRefresh'] as String?;
    if (nextRefreshStr != null) {
      nextMissionRefresh = DateTime.tryParse(nextRefreshStr) ?? nextMissionRefresh;
    }

    // Cloud overrides local time if valid
    final lastActiveStr = data['lastActiveTime'] as String?;
    if (lastActiveStr != null) {
       // We only use this if we didn't just load a fresher one from local,
       // but generally local is king for "last time I closed the app".
    }

    final fleetList = data['fleet'];
    if (fleetList is List) {
      try {
        fleet = (fleetList as List)
            .map((m) => Ship.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      } catch (_) {}
    }
  }

  Future<void> signInWithGoogle() async {
    final userCredential = await AuthService.signInWithGoogle();
    if (userCredential?.user != null) {
      await initializeUserSession(userCredential!.user!.uid);
    }
  }

  Future<void> signOut() async {
    await AuthService.signOut();
    _currentUid = null;
    _isInitialized = false;
    notifyListeners();
  }

  Future<void> _saveData() async {
      if (!_isInitialized) return;

      // 1. Local Save (Keep this)
      final prefs = await SharedPreferences.getInstance();
      await _saveLocal(prefs);

      if (_currentUid == null) return;

      // 2. Prepare User Data (Keep this)
      final int fleetValue = fleet.fold(0, (sum, ship) => sum + getShipSaleValue(ship));

      // Calculate Top Ship for Leaderboard
      Ship? topShip;
      int topShipVal = 0;
      if (fleet.isNotEmpty) {
        // Find the single most valuable ship
        for (var s in fleet) {
          int val = getShipSaleValue(s);
          if (val > topShipVal) {
            topShipVal = val;
            topShip = s;
          }
        }
      }

      // Main User Data Cloud Payload
      final Map<String, dynamic> cloudData = {
        'companyName': companyName,
        'solars': solars,
        'crystals': crystals,
        'ore': ore,
        'gas': gas,
        'maxStorage': maxStorage,
        'contractsPerCategory': contractsPerCategory,
        'bonusContractsPerCategory': bonusContractsPerCategory,
        'nextMissionRefresh': nextMissionRefresh?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'lastActiveTime': _lastActiveTime.toIso8601String(),
        'hangarLevel': hangarLevel,
        'relayLevel': relayLevel,
        'broadcastingArrayLevel': broadcastingArrayLevel,
        'broadcastingArrayPrestige': broadcastingArrayPrestige,
        'broadcastingArrayValueBonusPct': broadcastingArrayValueBonusPct,
        'serverFarmLevel': serverFarmLevel,
        'serverFarmPrestige': serverFarmPrestige,
        'tradeDepotLevel': tradeDepotLevel,
        'tradeDepotPrestige': tradeDepotPrestige,
        'repairGantryLevel': repairGantryLevel,
        'fleet': fleet.map((ship) => ship.toJson()).toList(),
        'fleetValue': fleetValue,
        'missionLogs': missionLogs.map((l) => l.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 3. Prepare Public Leaderboard Payload (NEW)
      final Map<String, dynamic> leaderboardData = {
        'companyName': companyName,
        'cashOnHand': solars, // Matches 'solars'
        'netWorth': solars + fleetValue + calculateBaseUpgradeInvestment(), // More accurate Net Worth (Cash + Ships + Buildings)
        'totalContracts': totalContracts,
        'topShipValue': topShipVal,
        'topShipNickname': topShip?.nickname ?? "None",
        'topShipClass': topShip?.shipClass ?? "N/A",
        'updatedAt': FieldValue.serverTimestamp(),
      };

      try {
        // Write to PRIVATE user doc
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUid)
            .set(cloudData, SetOptions(merge: true));

        // Write to PUBLIC leaderboard doc
        await FirebaseFirestore.instance
            .collection('leaderboard')
            .doc(_currentUid)
            .set(leaderboardData, SetOptions(merge: true));

      } catch (e) {
        debugPrint("Error syncing cloud: $e");
      }
    }

  final _localSaveDebouncer = Debouncer(delay: const Duration(milliseconds: 400));

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
          'nextMissionRefresh': (nextMissionRefresh ?? DateTime.now()).toIso8601String(),
          'lastActiveTime': _lastActiveTime.toIso8601String(),
          'fleet': fleet.map((s) => s.toJson()).toList(),
          'missionLogs': missionLogs.map((l) => l.toJson()).toList(),
          'availableMissions': availableMissions.map((m) => m.toJson()).toList(),
        };

        // 2. Attempt to Encode (This is likely where it crashes)
        final String encodedJson = jsonEncode(local);

        // 3. Write to disk
        await prefs.setString('mosc_save', encodedJson);

        debugPrint("✅ SAVE SUCCESS: Wrote Relay Level $relayLevel and ${availableMissions.length} missions.");

      } catch (e) {
        // THIS is the error we need to see
        debugPrint("🛑 SAVE FAILED: $e");
        //debugLoadError = "SAVE FAILED: $e"; // Show it on the UI if you added that feature
      }
    }

  Future<void> _loadData() async {
      debugPrint("📂 LOAD: Starting safe load sequence...");
      try {
        final prefs = await SharedPreferences.getInstance();

        // 1. Try to load the "Box" (New Format)
        final String? jsonStr = prefs.getString('mosc_save');

        if (jsonStr != null) {
          final Map<String, dynamic> local = jsonDecode(jsonStr);

          // --- A. LOAD TIMESTAMPS (Safely) ---
          try {
            if (local['lastActiveTime'] != null) {
              _lastActiveTime = DateTime.tryParse(local['lastActiveTime']) ?? DateTime.now();
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
            tradeDepotLevel = (local['tradeDepotLevel'] as num?)?.toInt() ?? tradeDepotLevel;
            tradeDepotPrestige = (local['tradeDepotPrestige'] as num?)?.toInt() ?? tradeDepotPrestige;
            broadcastingArrayLevel = (local['broadcastingArrayLevel'] as num?)?.toInt() ?? broadcastingArrayLevel;
            broadcastingArrayPrestige = (local['broadcastingArrayPrestige'] as num?)?.toInt() ?? broadcastingArrayPrestige;
            serverFarmLevel = (local['serverFarmLevel'] as num?)?.toInt() ?? serverFarmLevel;
            serverFarmPrestige = (local['serverFarmPrestige'] as num?)?.toInt() ?? serverFarmPrestige;
            repairGantryLevel = (local['repairGantryLevel'] as num?)?.toInt() ?? repairGantryLevel;
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
              debugPrint("✅ LOAD: Restored ${availableMissions.length} missions.");
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

  Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    solars = 50000;
    companyName = TextGenerators.generateCompanyName();
    ore = 0; gas = 0; crystals = 0;
    hangarLevel = 1; relayLevel = 1; serverFarmLevel = 0;
    tradeDepotLevel = 1; repairGantryLevel = 0; broadcastingArrayLevel = 1;
    hasNamedCompany = false;
    fleet = [];
    missionLogs = [];
    nextMissionRefresh = null;
    _setupStarterShip();
    _isInitialized = true;
    notifyListeners();
  }

  void _triggerUpdate() {
    SharedPreferences.getInstance().then((prefs) {
      _saveLocal(prefs);
    });
    if (_currentUid != null) {
      _cloudSaveDebouncer.run(() => _saveData());
    }
    notifyListeners();
  }

  // --- GAME LOGIC ---

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

    ore = 0; gas = 0; crystals = 0;
    solars += revenue;
    _triggerUpdate();
  }

  void _processMaintenanceCompletion(Ship ship) {
    if (ship.currentTask == 'Repairing') {
      ship.condition = 1.0;
      _addLog(LogEntry(
        timestamp: DateTime.now(),
        title: "Repair Complete",
        details: "${ship.isMaxed ? '[Elite] ' : ''}${ship.nickname} maintenance finished. Hull at 100%.",
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
          details: "${ship.nickname} has achieved Elite Status. Attributes Gained: Vanguard Honorarium, Priority Docking, Bleeding Edge Tech, and Legacy Designation",
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
        details: "${ship.isMaxed ? '[Elite] ' : ''}${ship.nickname} sent to ${mission.title}.",
        isPositive: true,
      ));

      _triggerUpdate();
    }
  }

  void _processMissionCompletion(Ship ship) {
    totalContracts++;

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

    solars += results.totalSolars;

    if (results.resourceAmount > 0) {
      switch (results.resourceType) {
        case 'Ore':
          ore += results.resourceAmount;
          break;
        case 'Gas':
          gas += results.resourceAmount;
          break;
        case 'Crystals':
          crystals += results.resourceAmount;
          break;
      }
    }

    String earnings = "⁂${results.baseReward}";
    if (results.brandReachBonus > 0) earnings += " + ⁂${results.brandReachBonus} (Brand Reach)";
    if (results.vanguardHonorarium > 0) earnings += " + ⁂${results.vanguardHonorarium} (Vanguard Honorarium)";

    if (results.resourceAmount > 0) {
      earnings += " + ${results.resourceAmount}m³ ${results.resourceType}";
    }

    if (results.overflowSolars > 0) {
      earnings += "\n⚠️ Storage Full: ${results.resourceType} sold for ⁂${results.overflowSolars}";
    }

    _applyHullWear(ship);

    _addLog(LogEntry(
      timestamp: DateTime.now(),
      title: "Contract Completed: ${ship.nickname}",
      details: "Earnings: $earnings",
      isPositive: true,
    ));

    ship.clearMissionData();
    _triggerUpdate();
  }

  int getResourcePrice(String resource) {
    double variance = 1.0 + (sin(DateTime.now().minute / 10) * 0.2);
    if (resource == 'Ore') return (10 * variance).toInt();
    if (resource == 'Gas') return (25 * variance).toInt();
    if (resource == 'Crystals') return (100 * variance).toInt();
    return 0;
  }

  void sellResource(String resource, int amount) {
    int total = getResourcePrice(resource) * amount;
    bool sold = false;
    if (resource == 'Ore' && ore >= amount) { ore -= amount; sold = true; }
    else if (resource == 'Gas' && gas >= amount) { gas -= amount; sold = true; }
    else if (resource == 'Crystals' && crystals >= amount) { crystals -= amount; sold = true; }

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
    s.busyUntil = DateTime.now().add(GameFormulas.calculateRepairDuration(s, repairSpeedMultiplier));

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
      if (s.condition < 1.0 && s.busyUntil == null && s.missionEndTime == null) {
        int cost = getRepairCost(s);
        if (solars >= cost) { solars -= cost; total += cost; s.busyUntil = DateTime.now().add(GameFormulas.calculateRepairDuration(s, repairSpeedMultiplier)); s.currentTask = 'Repairing'; }
      }
    }
    if (total > 0) {
      _addLog(LogEntry(timestamp: DateTime.now(), title: "Fleet Maintenance", details: "Batch repair executed. Total: ⁂$total.", solarChange: -total, isPositive: false));
      _triggerUpdate();
    }
  }

  bool upgradeShipStat(String shipId, String stat) {
    final idx = fleet.indexWhere((s) => s.id == shipId);
    if (idx == -1) return false;
    final s = fleet[idx];
    if (s.busyUntil != null || s.missionEndTime != null) return false;

    int cur = 0, mx = 0;
    if (stat == 'speed') { cur = s.speed; mx = s.maxSpeed; }
    else if (stat == 'cargo') { cur = s.cargoCapacity; mx = s.maxCargo; }
    else if (stat == 'fuel') { cur = s.fuelCapacity; mx = s.maxFuel; }
    else if (stat == 'shield') { cur = s.shieldLevel; mx = s.maxShield; }
    else if (stat == 'ai') { cur = s.aiLevel; mx = s.maxAI; }

    int cost = GameFormulas.calculateUpgradeCost(modelName: s.modelName, currentLevel: cur);
    if (solars >= cost && cur < mx) {
      solars -= cost;
      if (stat == 'speed') {
        s.speed++;
      } else if (stat == 'cargo') s.cargoCapacity++;
      else if (stat == 'fuel') s.fuelCapacity++;
      else if (stat == 'shield') s.shieldLevel++;
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

  int getRepairCost(Ship s) => ((1.0 - s.condition) * (getShipSaleValue(s) * 0.2) * repairCostMultiplier).toInt();

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
    if (idx != -1 && fleet[idx].missionEndTime == null && fleet[idx].busyUntil == null) {
      int val = getShipSaleValue(fleet[idx]);
      solars += val;
      _addLog(LogEntry(timestamp: DateTime.now(), title: "Ship Decommissioned", details: "${fleet[idx].nickname} salvaged for ⁂$val.", solarChange: val));
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

    if (newMission != null && !availableMissions.any((m) => m.title == targetTitle)) {
      availableMissions.add(newMission);
    }
  }

  void renameShip(String id, String name) {
    final idx = fleet.indexWhere((s) => s.id == id);
    if (idx != -1 && name.isNotEmpty) {
      final s = fleet[idx];

      if (s.renameLocked) {
        debugPrint("COREY_LOG: Rename blocked. ${s.nickname} is a Legacy vessel.");
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
      if (s.condition < 1.0 && s.busyUntil == null && s.missionEndTime == null) {
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
    updateMissions(_missionService.generateMissions(relayLevel, broadcastingArrayLevel, fleet));
    final now = DateTime.now();
    int currentHour = now.hour;
    int nextHour = (currentHour % 2 == 0) ? currentHour + 2 : currentHour + 1;
    if (nextHour >= 24) {
      final tomorrow = now.add(const Duration(days: 1));
      nextMissionRefresh = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 0, 0);
    } else {
      nextMissionRefresh = DateTime(now.year, now.month, now.day, nextHour, 0, 0);
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
      case 'Hangar': return (5000 * pow(2, level)).toInt();
      case 'Relay': return (10000 * pow(2.5, level)).toInt();
      default: return (2500 * pow(1.8, level)).toInt();
    }
  }

  Future<void> nuclearReset() async {
    if (_currentUid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(_currentUid).delete();
      await FirebaseFirestore.instance.collection('leaderboard').doc(_currentUid).delete();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      _gameTimer?.cancel();
      // Service timer cancel is handled by service.stop() if exposed, or auto GC when GameState dies.

      solars = 50000;
      ore = 0; gas = 0; crystals = 0;
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