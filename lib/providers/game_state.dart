import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../models/ship_model.dart';
import '../models/mission_model.dart';
import '../services/mission_service.dart';
import '../models/ship_templates.dart';
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
  String companyName = "ERR: Bypassed Name Function";
  bool hasNamedCompany = false;

  // Auth State
  User? currentUser;
  String? _currentUid;

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
  int totalDeliveries = 0; // Tracks every contract ever finished

  //Prestige
  int tradeDepotPrestige = 0;
  int broadcastingArrayPrestige = 0;
  int serverFarmPrestige = 0;

  int get scanArrayLevel => relayLevel;

  List<Ship> fleet = [];
  List<Mission> availableMissions = [];
  List<LogEntry> missionLogs = [];

  final MissionService _missionService = MissionService();
  Timer? _gameTimer;
  Timer? _marketTimer;
  bool _isInitialized = false;

  static const double _timeScalingFactor = 0.54;
  bool isBetaTiming = true;

  DateTime? nextMissionRefresh; // New field for timer

  Future<void> _ensureUserDefaults(String uid) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);

    final snap = await ref.get();
    final data = snap.data() ?? <String, dynamic>{};

    // Only add fields that are missing
    final Map<String, dynamic> missing = {};

    void ensure(String key, dynamic value) {
      if (!data.containsKey(key)) missing[key] = value;
    }

    ensure('companyName', companyName);
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

    // Ensure timer
    ensure('nextMissionRefresh', (nextMissionRefresh ?? DateTime.now()).toIso8601String());

    if (missing.isNotEmpty) {
      if (snap.exists) {
        await ref.update(missing);
      } else {
        await ref.set(missing); // creates doc for brand new user
      }
    }
  }



  GameState() {
    // Initial local load for faster startup (data is overwritten by Firestore on auth)
    _loadData().then((_) {
      _isInitialized = true;
      if (fleet.isEmpty) {
        _setupStarterShip();
      }
      _startGameLoop();
      _startMarketLoop();
      notifyListeners();
    });
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

  // --- LOGGING HELPER (Caps at 50) ---
  void _addLog(LogEntry entry) {
    missionLogs.insert(0, entry);
    if (missionLogs.length > 50) {
      missionLogs.removeRange(50, missionLogs.length);
    }
  }

  // --- AUTHENTICATION & CLOUD SESSION ---

  Future<void> initializeUserSession(String uid) async {
    if (_currentUid == uid) return;
    _currentUid = uid;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;

        companyName = data['companyName'] ?? "ERR: Cloud Missing Name";
        //companyName = data['companyName'] ?? _generateRandomCompanyName();
        hasNamedCompany = data['hasNamedCompany'] ?? false;
        solars = data['solars'] ?? 50000;
        ore = data['ore'] ?? 0;
        gas = data['gas'] ?? 0;
        crystals = data['crystals'] ?? 0;

        hangarLevel = data['hangarLevel'] ?? 1;
        relayLevel = data['relayLevel'] ?? 1;
        serverFarmLevel = data['serverFarmLevel'] ?? 0;
        tradeDepotLevel = data['tradeDepotLevel'] ?? 1;
        repairGantryLevel = data['repairGantryLevel'] ?? 0;
        broadcastingArrayLevel = data['broadcastingArrayLevel'] ?? 1;
        // Load prestige levels
        tradeDepotPrestige = data['tradeDepotPrestige'] ?? 0;
        broadcastingArrayPrestige = data['broadcastingArrayPrestige'] ?? 0;
        serverFarmPrestige = data['serverFarmPrestige'] ?? 0;
        
        // Load Mission Timer
        if (data['nextMissionRefresh'] != null) {
          nextMissionRefresh = DateTime.tryParse(data['nextMissionRefresh']);
        }

        if (data['fleet'] != null) {
          final List<dynamic> decodedFleet = data['fleet'];
          fleet = decodedFleet.map((item) => Ship.fromJson(item)).toList();
        }

        if (data['missionLogs'] != null) {
          final List<dynamic> decodedLogs = data['missionLogs'];
          missionLogs = decodedLogs.map((item) => LogEntry.fromJson(item)).toList();
        }
      } else {
        // New User Initialization
        hasNamedCompany = false;
        companyName = _generateRandomCompanyName();
        solars = 50000;
        _setupStarterShip();
        await _saveData(); // Create initial cloud doc
      }

      await _ensureUserDefaults(uid);

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Firebase Session Init Error: $e");
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint("Google Sign-In canceled by user");
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user?.uid != null) {
        await initializeUserSession(userCredential.user!.uid);
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();

      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      _currentUid = null;
      _isInitialized = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Sign out error: $e");
    }
  }


  // --- PERSISTENCE LOGIC (Dual Support) ---

  Future<void> _saveData() async {
    if (!_isInitialized || _currentUid == null) return;

    int fleetValue = fleet.fold(0, (sum, ship) => sum + getShipSaleValue(ship));

    // Add the Engineering investment to the total
    int engineeringValue = calculateBaseUpgradeInvestment();
    int netWorth = solars + fleetValue + engineeringValue;

    // 2. Find Single Most Valuable Ship
    Ship? topShip;
    int topShipValue = 0;
    if (fleet.isNotEmpty) {
      topShip = fleet.reduce((a, b) => getShipSaleValue(a) > getShipSaleValue(b) ? a : b);
      topShipValue = getShipSaleValue(topShip);
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUid);
      batch.set(userRef, {
        'companyName': companyName,
        'hasNamedCompany': hasNamedCompany,

        'solars': solars,
        'ore': ore,
        'gas': gas,
        'crystals': crystals,

        // Engineering
        'hangarLevel': hangarLevel,
        'relayLevel': relayLevel,
        'serverFarmLevel': serverFarmLevel,
        'tradeDepotLevel': tradeDepotLevel,
        'repairGantryLevel': repairGantryLevel,
        'broadcastingArrayLevel': broadcastingArrayLevel,
        //Leaderboard stuff
        'totalDeliveries': totalDeliveries,
        'fleet': fleet.map((s) => s.toJson()).toList(),
        'missionLogs': missionLogs.map((l) => l.toJson()).toList(),
        // Prestige levels
        'tradeDepotPrestige': tradeDepotPrestige,
        'broadcastingArrayPrestige': broadcastingArrayPrestige,
        'serverFarmPrestige': serverFarmPrestige,
        // Mission Timer
        'nextMissionRefresh': nextMissionRefresh?.toIso8601String(),
      }, SetOptions(merge: true));


      // 3. Update the Leaderboard with your 4 categories
      final leadRef = FirebaseFirestore.instance.collection('leaderboard').doc(_currentUid);
      batch.set(leadRef, {
        'companyName': companyName,
        'cashOnHand': solars,            // Category 1
        'netWorth': netWorth,             // Category 2
        'topShipNickname': topShip?.nickname ?? "N/A", // Category 3
        'topShipClass': topShip?.shipClass ?? "N/A",
        'topShipValue': topShipValue,
        'totalDeliveries': totalDeliveries, // Category 4
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      debugPrint("Leaderboard Sync Error: $e");
    }
  }

  Future<void> _loadData() async {
    // Standard Local Load (Used on startup before Auth)
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('solars')) return;

      solars = prefs.getInt('solars') ?? 50000;
      ore = prefs.getInt('ore') ?? 0;
      gas = prefs.getInt('gas') ?? 0;
      crystals = prefs.getInt('crystals') ?? 0;
      hangarLevel = prefs.getInt('hangarLevel') ?? 1;
      relayLevel = prefs.getInt('relayLevel') ?? 1;
      hasNamedCompany = prefs.getBool('hasNamedCompany') ?? false;
      
      final refreshString = prefs.getString('nextMissionRefresh');
      if (refreshString != null) {
        nextMissionRefresh = DateTime.tryParse(refreshString);
      }

      final fleetString = prefs.getString('fleet');
      if (fleetString != null) {
        final List<dynamic> decoded = jsonDecode(fleetString);
        fleet = decoded.map((item) => Ship.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint("Local Load Error: $e");
    }
  }

  Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    solars = 50000;
    // companyName = "New MOSC Branch"; // OLD
    companyName = _generateRandomCompanyName(); // NEW: Keep consistent with random names
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
    if (_isInitialized) {
      _saveData();
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
      
      // Auto-refresh missions
      if (nextMissionRefresh != null && now.isAfter(nextMissionRefresh!)) {
        generateNewMissions();
        changesMade = true;
      } else if (nextMissionRefresh == null) {
        // If null (fresh start without load), set it now or generate
        // Usually generateNewMissions sets it.
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

  void _startMarketLoop() {
    _marketTimer?.cancel();
    _marketTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (ore > 0 || gas > 0 || crystals > 0) {
        _performAutoSell();
        _triggerUpdate();
      }
    });
  }

  void _performAutoSell() {
    Random rng = Random();
    double percent = 0.05 + (rng.nextDouble() * 0.05);

    int soldOre = (ore * percent).ceil();
    int soldGas = (gas * percent).ceil();
    int soldCrystals = (crystals * percent).ceil();

    if (soldOre == 0 && ore > 0) soldOre = 1;
    if (soldGas == 0 && gas > 0) soldGas = 1;
    if (soldCrystals == 0 && crystals > 0) soldCrystals = 1;

    double multiplier = 1.0 + (tradeDepotLevel * 0.05);

    int revenue = 0;
    revenue += (soldOre * getResourcePrice('Ore') * multiplier).toInt();
    revenue += (soldGas * getResourcePrice('Gas') * multiplier).toInt();
    revenue += (soldCrystals * getResourcePrice('Crystals') * multiplier).toInt();

    ore -= soldOre;
    gas -= soldGas;
    crystals -= soldCrystals;
    solars += revenue;

    _addLog(LogEntry(
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
      _addLog(LogEntry(
        timestamp: DateTime.now(),
        title: "Upgrade Installed",
        details: "${ship.isMaxed ? '[Elite] ' : ''}${ship.nickname} systems have been enhanced.",
      ));
    }
    ship.busyUntil = null;
    ship.currentTask = null;
  }

  void startMission(String shipId, Mission mission) {
    final shipIndex = fleet.indexWhere((s) => s.id == shipId);
    if (shipIndex != -1) {
      final now = DateTime.now();
      final ship = fleet[shipIndex];
      ship.missionStartTime = now;
      ship.missionDistance = mission.distanceAU;

      double factor = 2000.0; //dropping her down to normal game speed
      int speed = max(1, ship.speed);
      double aiMult = max(0.5, 1.0 - (ship.aiLevel * 0.05));

      // 0.1% faster per prestige level => 0.1% less time per level
      double prestigeTimeMult = 1.0 - (serverFarmPrestige * 0.001);
      // safety clamp so it never goes negative / ridiculous
      prestigeTimeMult = prestigeTimeMult.clamp(0.25, 1.0);

      int seconds = max(
        5,
        ((mission.distanceAU / speed) * factor * aiMult * prestigeTimeMult)
            .clamp(0, 300)
            .toInt(),
      );

      ship.missionEndTime = now.add(Duration(seconds: seconds));
      ship.pendingReward = mission.rewardSolars;
      ship.pendingResource = mission.rewardResource;
      ship.pendingResourceAmount = mission.rewardResourceAmount;

      availableMissions.removeWhere((m) => m.id == mission.id);

      if (mission.title.contains("Local Scrap Run")) {
        availableMissions.add(_missionService.getLocalScrapRun());
      } else if (mission.title.contains("Local Courier Run")) {
        availableMissions.add(_missionService.getLocalCourierRun());
      }

      _addLog(LogEntry(
        timestamp: now,
        title: "Mission Launched",
        details: "${ship.isMaxed ? '[Elite] ' : ''}${ship.nickname} sent to ${mission.title}. ETA: ${seconds}s",
      ));

      _triggerUpdate();
    }
  }

  void _processMissionCompletion(Ship ship) {
    totalDeliveries++; // Increment for Category 4
    int reward = ship.pendingReward;
    int amount = ship.pendingResourceAmount;

    double aiRewardMult = 1.0 + (ship.aiLevel * 0.05);
    reward = (reward * aiRewardMult * 10).toInt();
    amount = (amount * aiRewardMult * 10).toInt();

    int resourceValue = 0;
    if (ship.pendingResource != null && amount > 0) {
      resourceValue = amount * getResourcePrice(ship.pendingResource!);
    }
    int totalMissionValue = reward + resourceValue;

    int eliteBonus = ship.isMaxed ? (totalMissionValue * 0.05).toInt() : 0;

    // Broadcasting Prestige Bonus: 0.1% per level of total mission value
    int broadcastBonus = 0;
    if (broadcastingArrayPrestige > 0) {
      broadcastBonus = (totalMissionValue * (broadcastingArrayPrestige * 0.001)).round();
    }

    solars += reward + eliteBonus + broadcastBonus;

    String earnings = reward > 0 ? "⁂$reward" : "";
    if (eliteBonus > 0) earnings += (earnings.isEmpty ? "" : " + ") + "⁂$eliteBonus (Elite)";
    if (broadcastBonus > 0) earnings += (earnings.isEmpty ? "" : " + ") + "⁂$broadcastBonus (Brand Reach)";

    if (ship.pendingResource != null && amount > 0) {
      int space = maxStorage - (ore + gas + crystals);
      int toStore = min(amount, max(0, space));
      int overflow = amount - toStore;

      if (toStore > 0) {
        if (ship.pendingResource == 'Ore') ore += toStore;
        if (ship.pendingResource == 'Gas') gas += toStore;
        if (ship.pendingResource == 'Crystals') crystals += toStore;
      }

      String icon = ship.pendingResource == 'Ore' ? "🏔️" : (ship.pendingResource == 'Gas' ? "☁️" : "💎");
      earnings += (earnings.isEmpty ? "" : " + ") + "$toStore m³ $icon ${ship.pendingResource}";

      if (overflow > 0) {
        int val = (overflow * getResourcePrice(ship.pendingResource!) * 0.75).toInt();
        solars += val;
        earnings += "\n(⚠️ Storage Full: $overflow m³ sold rushed for ⁂$val)";
      }
    }

    double wear = (ship.missionDistance ?? 1.0) * 0.002 * (1.0 - min(0.5, (ship.shieldLevel + ship.aiLevel * 0.5) * 0.02));
    wear = max(wear, (ship.missionDistance ?? 1.0) * 0.0005) * (0.8 + Random().nextDouble() * 0.4);

    double oldC = ship.condition;
    ship.condition = (ship.condition - wear).clamp(0.0, 1.0);

    _addLog(LogEntry(
      timestamp: DateTime.now(),
      title: "Mission Return: ${ship.isMaxed ? '[Elite] ' : ''}${ship.nickname}",
      details: "Earnings: $earnings. Hull Wear: -${((oldC - ship.condition) * 100).toStringAsFixed(2)}%.",
      isPositive: true,
    ));

    ship.pendingReward = 0; ship.pendingResource = null; ship.pendingResourceAmount = 0;
    ship.missionStartTime = null; ship.missionEndTime = null; ship.missionDistance = null;
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

  Duration getRepairDuration(Ship ship) {
    final damage = (1.0 - ship.condition).clamp(0.0, 1.0);
    final sale = getShipSaleValue(ship).toDouble();

    const double minSale = 1000;     // cheapest template-ish
    const double maxSale = 420000;   // most expensive template-ish

    final logMin = log(minSale);
    final logMax = log(maxSale);
    final logSale = log(sale.clamp(minSale, maxSale));

    final valueNorm = ((logSale - logMin) / (logMax - logMin)).clamp(0.0, 1.0);

    final minSeconds = _lerp(5.0, 20.0, valueNorm);
    final maxSeconds = _lerp(100.0, 666.0, valueNorm);

    final gamma = _lerp(1.0, 1.8, valueNorm);

    final curvedDamage = pow(damage, gamma).toDouble();

    var seconds = minSeconds + curvedDamage * (maxSeconds - minSeconds);

    seconds = seconds / repairSpeedMultiplier;

    final secInt = seconds.round().clamp(2, 3600);

    return Duration(seconds: secInt);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
  // --- TEMPLATE LOOKUPS ---
  int _getTemplatePrice(String modelName) {
    try {
      return ShipTemplate.all.firstWhere((t) => t.modelName == modelName).price;
    } catch (_) {
      return 0;
    }
  }

  // --- SHIP UPGRADES (COST + TIME) ---
  int getUpgradeCost(Ship s, int currentLevel) {
    // Cost scales with ship model price and how far you’ve pushed the stat.
    final price = _getTemplatePrice(s.modelName).toDouble();

    // Normalize price to 0..1 using your template range (1k..420k)
    const minPrice = 1000.0;
    const maxPrice = 420000.0;
    final valueNorm = ((log(price.clamp(minPrice, maxPrice)) - log(minPrice)) /
        (log(maxPrice) - log(minPrice)))
        .clamp(0.0, 1.0);

    // Base cost: cheap ships ~80, expensive ships ~1500
    final base = _lerp(80.0, 1500.0, valueNorm);

    // Level scaling: mild exponential so later upgrades cost more
    final levelFactor = pow(1.22, currentLevel).toDouble();

    return (base * levelFactor).round();
  }

  Duration getUpgradeDuration(Ship s, int currentLevel) {
    final price = _getTemplatePrice(s.modelName).toDouble();

    const minPrice = 1000.0;
    const maxPrice = 420000.0;
    final valueNorm = ((log(price.clamp(minPrice, maxPrice)) - log(minPrice)) /
        (log(maxPrice) - log(minPrice)))
        .clamp(0.0, 1.0);

    // Base seconds: cheap ships ~5s, expensive ships ~45s
    final baseSeconds = _lerp(5.0, 45.0, valueNorm);

    // Later levels take longer
    final levelSeconds = baseSeconds * (1.0 + currentLevel * 0.25);

    // Optional: use repair gantry as "better yard tooling" too (speeds upgrades a bit)
    final seconds = (levelSeconds / repairSpeedMultiplier).round().clamp(3, 600);

    return Duration(seconds: seconds);
  }

  // --- SINGLE SHIP REPAIR (used by DryDock screen) ---
  void repairShip(String shipId) {
    final idx = fleet.indexWhere((s) => s.id == shipId);
    if (idx == -1) return;

    final s = fleet[idx];

    // Don’t repair if already busy or on mission
    if (s.busyUntil != null || s.missionEndTime != null) return;
    if (s.condition >= 1.0) return;

    final cost = getRepairCost(s);
    if (solars < cost) return;

    solars -= cost;
    s.isRepairing = true;
    s.currentTask = 'Repairing';
    s.busyUntil = DateTime.now().add(getRepairDuration(s));

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
        if (solars >= cost) { solars -= cost; total += cost; s.busyUntil = DateTime.now().add(getRepairDuration(s)); s.currentTask = 'Repairing'; }
      }
    }
    if (total > 0) {
      _addLog(LogEntry(timestamp: DateTime.now(), title: "Fleet Maintenance", details: "Batch repair executed. Total: ⁂$total.", solarChange: -total, isPositive: false));
      _triggerUpdate();
    }
  }

  void upgradeShipStat(String shipId, String stat) {
    final idx = fleet.indexWhere((s) => s.id == shipId);
    if (idx == -1) return;
    final s = fleet[idx];
    if (s.busyUntil != null || s.missionEndTime != null) return;

    int cur = 0, mx = 0;
    if (stat == 'speed') { cur = s.speed; mx = s.maxSpeed; }
    else if (stat == 'cargo') { cur = s.cargoCapacity; mx = s.maxCargo; }
    else if (stat == 'fuel') { cur = s.fuelCapacity; mx = s.maxFuel; }
    else if (stat == 'shield') { cur = s.shieldLevel; mx = s.maxShield; }
    else if (stat == 'ai') { cur = s.aiLevel; mx = s.maxAI; }

    int cost = getUpgradeCost(s, cur);
    if (solars >= cost && cur < mx) {
      solars -= cost;
      if (stat == 'speed') s.speed++;
      else if (stat == 'cargo') s.cargoCapacity++;
      else if (stat == 'fuel') s.fuelCapacity++;
      else if (stat == 'shield') s.shieldLevel++;
      else if (stat == 'ai') s.aiLevel++;

      s.busyUntil = DateTime.now().add(getUpgradeDuration(s, cur));
      s.currentTask = 'Upgrading';
      _addLog(LogEntry(timestamp: DateTime.now(), title: "Systems Upgrade", details: "${s.nickname} $stat enhanced. Cost: ⁂$cost.", solarChange: -cost, isPositive: false));
      _triggerUpdate();
    }
  }

  int getRepairCost(Ship s) => ((1.0 - s.condition) * (getShipSaleValue(s) * 0.2) * repairCostMultiplier).toInt();
  int getShipSaleValue(Ship s) {
    int basePrice = _getTemplatePrice(s.modelName);
    double baseValue = basePrice * 0.7; // 70% Depreciation

    // Add 50% of the total solar investment spent on upgrades
    int upgradeInvestment = _calculateTotalUpgradeInvestment(s);
    double totalAppraisal = baseValue + (upgradeInvestment * 0.5);

    // Factor in the ship's current physical condition (0.0 to 1.0)
    return (totalAppraisal * (0.5 + s.condition * 0.5)).toInt();
  }

  /// Calculates every solar spent on this ship's stats using the upgrade cost formula.
  int _calculateTotalUpgradeInvestment(Ship s) {
    int investment = 0;
    // Fetch starting levels from the template to calculate the "delta"
    final template = ShipTemplate.all.firstWhere((t) => t.modelName == s.modelName);

    investment += _sumStatCost(s, s.speed, template.baseSpeed);
    investment += _sumStatCost(s, s.cargoCapacity, template.baseCargo);
    investment += _sumStatCost(s, s.fuelCapacity, template.baseFuel);
    investment += _sumStatCost(s, s.shieldLevel, template.baseShield);
    investment += _sumStatCost(s, s.aiLevel, template.baseAI);


    return investment;
  }

  int _sumStatCost(Ship s, int currentLevel, int startLevel) {
    int total = 0;
    for (int i = startLevel; i < currentLevel; i++) {
      total += getUpgradeCost(s, i);
    }
    return total;
  }

  void upgradeBase(String type, int cost) {
    if (solars >= cost) {
      solars -= cost;
      if (type == 'Hangar') hangarLevel++;
      else if (type == 'Relay') relayLevel++;
      else if (type == 'Server') serverFarmLevel++;
      else if (type == 'Depot') tradeDepotLevel++;
      else if (type == 'Gantry') repairGantryLevel++;
      else if (type == 'Broadcasting') broadcastingArrayLevel++;

      _addLog(LogEntry(timestamp: DateTime.now(), title: "Base Upgraded", details: "$type reached Level ${[hangarLevel, relayLevel, serverFarmLevel, tradeDepotLevel, repairGantryLevel, broadcastingArrayLevel].join(', ')}", solarChange: -cost, isPositive: false));
      _triggerUpdate();
    }
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
      details: "Overflow Storage +100 m³ (Prestige ${tradeDepotPrestige})",
      solarChange: -cost,
      isPositive: false,
    ));

    _triggerUpdate(); // this saves + notifyListeners
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
      details: "Brand Reach +0.1% (Prestige ${broadcastingArrayPrestige})",
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
    const int maxLevel = 3; // your server farm max
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
    int actualCost = _getTemplatePrice(s.modelName);
    // Use your hangarLevel logic here directly
    int currentLimit = hangarLevel == 1 ? 2 : hangarLevel * 2;

    if (solars >= actualCost && fleet.length < currentLimit) {
      solars -= actualCost;
      fleet.add(s);
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

  void renameShip(String id, String name) {
    final idx = fleet.indexWhere((s) => s.id == id);
    if (idx != -1 && name.isNotEmpty) {
      final s = fleet[idx];
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
    _triggerUpdate();
  }


  /// Calculates the sum of all repair costs for ships that are damaged and not busy.
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
    // Keep those locals pinned so there's always something to do
    if (!availableMissions.any((m) => m.title.contains("Local Scrap Run"))) {
      availableMissions.add(_missionService.getLocalScrapRun());
    }
    if (!availableMissions.any((m) => m.title.contains("Local Courier Run"))) {
      availableMissions.add(_missionService.getLocalCourierRun());
    }
    _triggerUpdate();
  }

  /// Refreshes the mission board using the mission service.
  void generateNewMissions() {
    updateMissions(_missionService.generateMissions(relayLevel, broadcastingArrayLevel, fleet));
    // Set 2 hour timer
    nextMissionRefresh = DateTime.now().add(const Duration(hours: 2));
    _triggerUpdate();
  }

  /// Calculates total solars spent on upgrading base facilities.
  int calculateBaseUpgradeInvestment() {
    int total = 0;

    // We sum the cost for every level starting from 1 up to the current level
    // Note: Most facilities start at Level 1, some at Level 0.
    total += _sumBaseCategoryCost('Hangar', hangarLevel, 1);
    total += _sumBaseCategoryCost('Relay', relayLevel, 1);
    total += _sumBaseCategoryCost('Server', serverFarmLevel, 0);
    total += _sumBaseCategoryCost('Depot', tradeDepotLevel, 1);
    total += _sumBaseCategoryCost('Gantry', repairGantryLevel, 0);
    total += _sumBaseCategoryCost('Broadcasting', broadcastingArrayLevel, 1);

    return total;
  }

  /// Helper to simulate the costs paid for each level jump.
  int _sumBaseCategoryCost(String type, int currentLevel, int startLevel) {
    int categoryTotal = 0;
    // We loop from the starting level to the current level
    for (int i = startLevel; i < currentLevel; i++) {
      categoryTotal += getBaseUpgradeCost(type, i);
    }
    return categoryTotal;
  }

  /// This should match your existing upgrade cost logic in EngineeringScreen.
  int getBaseUpgradeCost(String type, int level) {
    // Replace these with your actual price scaling logic
    switch (type) {
      case 'Hangar': return (5000 * pow(2, level)).toInt();
      case 'Relay': return (10000 * pow(2.5, level)).toInt();
      default: return (2500 * pow(1.8, level)).toInt();
    }
  }

  //New corp name for new users!@#$
  String _generateRandomCompanyName() {
    final List<String> adjectives = [
      "Heavy", "Deep", "Interstellar", "Prime", "Apex", "Vanguard", "Bulk",
      "Stellar", "Void", "Infinite", "Solar", "Divine", "Rusty", "Frontier"
    ];
    final List<String> nouns = [
      "Freight", "Haulage", "Cargo", "Transit", "Relay", "Extraction",
      "Mineral", "Ore", "Orbit", "Voyager", "Asteroid", "Nebula", "Comet",
      "Forge", "Vector", "Drift"
    ];
    final List<String> businessWords = [
      "Inc.", "Enterprises", "LLC", "Corp", "Solutions", "Group",
      "Logistics", "Consolidated", "Ventures", "Systems", "Combine", "Syndicate"
    ];

    final random = Random();
    String adj = adjectives[random.nextInt(adjectives.length)];
    String noun = nouns[random.nextInt(nouns.length)];
    String selectedBiz = businessWords[random.nextInt(businessWords.length)];

    return "$adj $noun $selectedBiz";
  }

  Future<void> nuclearReset() async {
    if (_currentUid == null) return;

    try {
      // 1. Wipe Cloud Firestore
      await FirebaseFirestore.instance.collection('users').doc(_currentUid).delete();
      await FirebaseFirestore.instance.collection('leaderboard').doc(_currentUid).delete();

      // 2. Wipe Local SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 3. Reset Local State to "Day Zero"
      solars = 50000;
      companyName = _generateRandomCompanyName();
      hasNamedCompany = false;
      ore = 0; gas = 0; crystals = 0;
      fleet = [];
      missionLogs = [];

      _setupStarterShip();

      // 4. Force a cloud save of the fresh state
      await _saveData();

      notifyListeners();
      debugPrint("COREY_LOG: Nuclear reset complete. System purged.");
    } catch (e) {
      debugPrint("COREY_LOG: Reset failed: $e");
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _marketTimer?.cancel();
    super.dispose();
  }
} // <--- Final class bracket