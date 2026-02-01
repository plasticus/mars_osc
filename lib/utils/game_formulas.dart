import 'dart:math';

/// DATA MANIFEST: The package returned by the Mission Authority.
/// Defined outside the class for easy access by GameState.
class MissionResults {
  final int totalSolars;        // Base + Brand Reach + Vanguard Honorarium + Overflow
  final int baseReward;         // The core solar payout
  final int brandReachBonus;    // The Broadcasting Array contribution
  final int vanguardHonorarium; // The Elite-only status contribution

  final String resourceType;    // Ore, Gas, or Crystals
  final int resourceAmount;     // The physical amount to add to inventory
  final int overflowSolars;     // Cash from "Rushed Sales" if storage was full

  MissionResults({
    required this.totalSolars,
    required this.baseReward,
    required this.brandReachBonus,
    required this.vanguardHonorarium,
    required this.resourceType,
    required this.resourceAmount,
    this.overflowSolars = 0,
  });
}

class GameFormulas {
  // --- TUNING CONSTANTS ---
  static const double minDistance = 0.5;
  static const double maxDistance = 32.0;
  static const double rangeScale = 18.0;
  static const double distanceSpan = 31.5;

  static const double liveMinSeconds = 30.0;    // Absolute floor for any mission
  static const double liveMaxSeconds = 18000.0; // 5 hours (60s * 60m * 5h)
  static const double liveBaseSeconds = 18000.0; // The 5-hour anchor at max distance
  static const double distExponent = 1.0;       // 1.0 = Linear scaling (easier to balance)
  static const double anchorSpeed = 2.0;

  static const double betaScale = 0.015;
  static const double betaMinSeconds = 10.0;
  static const double betaMaxSeconds = 300.0;
  static const double aiSpeedEfficiency = 0.5;
  static const double aiFuelEfficiency = 0.5;

  // --- ELITE & REWARD TUNING ---
  static const double globalRewardMultiplier = 5.0;
  static const double solarBonusPerLevel = 0.03;
  static const double dockingBonusPerLevel = 0.02;
  static const double eliteValueMultiplier = 1.25;

  // --- OFFLINE AI TUNING ---
  static const int offlineSaleIntervalMinutes = 15;
  static const double offlineEfficiencyPenalty = 1.0;
  static const int maxOfflineMinutes = 1440;

  // --- SHIP TIER DATA ---
  static const Map<String, int> shipTiers = {
    // Mules
    'Rusty Tug': 1, 'Iron Snail': 2, 'Bulk Carrier': 3, 'Solar Whale': 4, 'Titan Hauler': 5,
    // Sprinters
    'Dart': 1, 'Comet': 2, 'Silver Streak': 3, 'Velocity': 4, 'Warp Shadow': 5,
    // Tankers
    'Fuel Buoy': 1, 'Gas Giant': 2, 'Deep Oiler': 3, 'Voyager': 4, 'Infinite Reach': 5,
    // Miners
    'Gravel Picker': 1, 'Rock Biter': 2, 'Ore Hound': 3, 'Asteroid Eater': 4, 'Core Driller': 5,
    // Harvesters
    'Rift Skimmer': 1, 'Soul Beacon': 2, 'Void Weaver': 3, 'Eon Traveler': 4, 'Singularity': 5,
  };

  /// Bridges the gap for screens looking for Tier/Level logic
  static int getShipClassLevel(String modelName) => getShipTier(modelName);

  /// Standard check for mission viability
  static bool canRunMission(double distanceAU, int fuel, int ai) {
    return getEffectiveRange(fuel, ai) >= getRangeRequired(distanceAU);
  }
  static int getShipTier(String modelName) => shipTiers[modelName] ?? 1;

  static int getBaseResourceValue(String type) {
    switch (type.toLowerCase()) {
      case 'ore': return 10;
      case 'gas': return 25;
      case 'crystals': return 100;
      default: return 0;
    }
  }

  // --- THE MISSION AUTHORITY ---

  /// The single source of truth for all mission payouts.
  static MissionResults calculateFullMissionResults({
    required int pendingReward,
    required String? pendingResource,
    required int pendingResourceAmount,
    required int aiLevel,
    required bool isElite,
    required String modelName,
    required int broadcastingPrestige,
    required int currentStorageUsed,
    required int maxStorage,
  }) {
    // 1. Calculate Core Solar Reward (with AI bonus)
    double rewardBase = pendingReward * globalRewardMultiplier;
    double aiBonusMult = 1.0 + (aiLevel * 0.05);
    int finalBaseReward = (rewardBase * aiBonusMult).toInt();

    // 2. Calculate Physical Resource Amount
    int finalResourceAmount = (pendingResourceAmount * (1.0 + (aiLevel * 0.05))).toInt();

    // 3. Calculate Bonus Foundation (Total market value: Solars + Resources)
    int resMarketValue = finalResourceAmount * getBaseResourceValue(pendingResource ?? "");
    int totalValueForBonusMath = finalBaseReward + resMarketValue;

    // 4. BRAND REACH: Applies to ALL ships (0.1% per Prestige level)
    int brandReachBonus = calculateBrandReachBonus(
      totalValue: totalValueForBonusMath,
      broadcastingPrestige: broadcastingPrestige,
    );

    // 5. VANGUARD HONORARIUM: Applies only to ELITE ships (3% per Tier)
    int vanguardBonus = calculateVanguardHonorarium(
      totalValue: totalValueForBonusMath,
      modelName: modelName,
      isElite: isElite,
    );

    // 6. Handle Storage & Overflow (Rushed Sales)
    int actualStored = 0;
    int overflowCash = 0;

    if (pendingResource != null && finalResourceAmount > 0) {
      int availableSpace = max(0, maxStorage - currentStorageUsed);
      actualStored = min(finalResourceAmount, availableSpace);
      int overflowAmount = finalResourceAmount - actualStored;

      if (overflowAmount > 0) {
        // Rushed sale: 75% of market value for the stuff that didn't fit
        overflowCash = (overflowAmount * getBaseResourceValue(pendingResource) * 0.75).toInt();
      }
    }

    return MissionResults(
      baseReward: finalBaseReward,
      brandReachBonus: brandReachBonus,
      vanguardHonorarium: vanguardBonus,
      totalSolars: finalBaseReward + brandReachBonus + vanguardBonus + overflowCash,
      resourceType: pendingResource ?? "None",
      resourceAmount: actualStored,
      overflowSolars: overflowCash,
    );
  }

  static int calculateBrandReachBonus({required int totalValue, required int broadcastingPrestige}) {
    if (broadcastingPrestige <= 0) return 0;
    double brandReachMult = broadcastingPrestige * 0.001; // 0.1% per level
    return (totalValue * brandReachMult).round();
  }

  static int calculateVanguardHonorarium({required int totalValue, required String modelName, required bool isElite}) {
    if (!isElite) return 0;
    int tier = getShipTier(modelName);
    double tierBonus = tier * 0.03; // 3% per Tier
    return (totalValue * tierBonus).toInt();
  }

  // --- CORE SYSTEM FORMULAS ---

  static int calculateSolarReward({
    required int baseReward,
    required int aiLevel,
    required bool isElite,
    String? shipClass,
    String? modelName,
    int broadcastingPrestige = 0,
  }) {
    double reward = baseReward * globalRewardMultiplier;
    double aiMult = 1.0 + (aiLevel * 0.05);
    int finalBase = (reward * aiMult).toInt();

    // If calling this standalone, it still respects Brand Reach
    double prestigeMult = 1.0 + (broadcastingPrestige * 0.001);
    return (finalBase * prestigeMult).toInt();
  }

  static int calculateResourceReward({required int baseAmount, required int aiLevel}) {
    return (baseAmount * (1.0 + (aiLevel * 0.05))).toInt();
  }

  static double getPriorityDockingMultiplier(int tier, bool isElite) {
    if (!isElite) return 1.0;
    return (1.0 - (tier * dockingBonusPerLevel)).clamp(0.5, 1.0);
  }

  static int calculateShipValue({
    required int basePrice,
    required int upgradeInvestment,
    required double condition,
    required bool isElite,
  }) {
    if (isElite) {
      double totalInvestment = (basePrice + upgradeInvestment).toDouble();
      return (totalInvestment * eliteValueMultiplier * (0.5 + condition * 0.5)).toInt();
    } else {
      double standardBase = basePrice * 0.7;
      double standardUpgrades = upgradeInvestment * 0.5;
      return ((standardBase + standardUpgrades) * (0.5 + condition * 0.5)).toInt();
    }
  }

static String generateLegacyName() {
  final prefixes = [
    "Vanguard", "Zenith", "Obsidian", "Sovereign", "Stellar",
    "Infinite", "Absolute", "Eternal", "Apex", "Hallowed",
    "Crimson", "Ashen", "Ironclad", "Arcane", "Glacial",
    "Phantom", "Radiant", "Tenebrous", "Umbral", "Golden",
    "Fathomless", "Indomitable", "Veiled", "Eldritch", "Sundered",
    "Celestial", "Wrathful", "Onyx", "Primordial", "Spectral", "Maximum",
    "Winged", "Space", "Black", "Porcine", "Ebony", "Silver", "Green",
    "Purple", "Blue", "Steel", "Silent", "Violent", "Blonde", "The Last",
    "The First"
  ];

  final nouns = [
    "Monolith", "Sentinel", "Harbinger", "Paragon", "Conduit",
    "Aegis", "Catalyst", "Emissary", "Bastion", "Cipher",
    "Colossus", "Warlock", "Titan", "Specter", "Goliath",
    "Arbiter", "Veil", "Relic", "Throne", "Oracle",
    "Archon", "Phantom", "Revenant", "Obelisk", "Warden",
    "Leviathan", "Dreadnought", "Seraph", "Enigma",
    "Ghost", "Giant", "Lion", "Whale", "Abyss", "Abomination",
    "Lance", "Spud", "Eden"
  ];

  final random = Random();
  return "${prefixes[random.nextInt(prefixes.length)]} ${nouns[random.nextInt(nouns.length)]}";
}

  // --- TRADING & AI SALES ---

  static Map<String, dynamic> calculateOfflineAutoSales({
    required int minutesAway,
    required int startOre,
    required int startGas,
    required int startCrystals,
    required int tradeDepotLevel,
    required int maxStorage,
    required Map<String, int> marketPrices,
  }) {
    int currentOre = startOre;
    int currentGas = startGas;
    int currentCrystals = startCrystals;
    int totalRevenue = 0;

    int totalMinutesProcessed = min(minutesAway, maxOfflineMinutes);
    int ticks = (totalMinutesProcessed / offlineSaleIntervalMinutes).floor();
    double multiplier = (1.0 + (tradeDepotLevel * 0.05)) * offlineEfficiencyPenalty;

    for (int i = 0; i < ticks; i++) {
      var result = _simulateBalancedQuotaTick(
        ore: currentOre,
        gas: currentGas,
        crystals: currentCrystals,
        maxStorage: maxStorage,
        prices: marketPrices,
        multiplier: multiplier,
      );

      currentOre -= result['soldOre']!;
      currentGas -= result['soldGas']!;
      currentCrystals -= result['soldCrystals']!;
      totalRevenue += result['revenue']!;

      if (currentOre <= 0 && currentGas <= 0 && currentCrystals <= 0) break;
    }

    return {
      'newOre': currentOre,
      'newGas': currentGas,
      'newCrystals': currentCrystals,
      'totalRevenue': totalRevenue,
      'minutesProcessed': ticks * offlineSaleIntervalMinutes,
    };
  }

  static Map<String, int> calculateOnlineAutoSale({
    required int ore,
    required int gas,
    required int crystals,
    required int tradeDepotLevel,
    required int maxStorage,
    required Map<String, int> marketPrices,
  }) {
    double multiplier = 1.0 + (tradeDepotLevel * 0.05);
    return _simulateBalancedQuotaTick(
      ore: ore,
      gas: gas,
      crystals: crystals,
      maxStorage: maxStorage,
      prices: marketPrices,
      multiplier: multiplier,
    );
  }

  static Map<String, int> _simulateBalancedQuotaTick({
    required int ore,
    required int gas,
    required int crystals,
    required int maxStorage,
    required Map<String, int> prices,
    required double multiplier,
  }) {
    Random rng = Random();
    double quotaPercent = 0.006 + (rng.nextDouble() * 0.004);
    int totalQuota = (maxStorage * quotaPercent).round();

    int targetPerType = (totalQuota / 3).floor();

    int sOre = min(ore, targetPerType);
    int sGas = min(gas, targetPerType);
    int sCrystals = min(crystals, targetPerType);

    int remainingQuota = totalQuota - (sOre + sGas + sCrystals);

    if (remainingQuota > 0) {
      int extraOre = min(ore - sOre, remainingQuota);
      sOre += extraOre;
      remainingQuota -= extraOre;
      if (remainingQuota > 0) {
        int extraGas = min(gas - sGas, remainingQuota);
        sGas += extraGas;
        remainingQuota -= extraGas;
      }
      if (remainingQuota > 0) {
        int extraCrystals = min(crystals - sCrystals, remainingQuota);
        sCrystals += extraCrystals;
      }
    }

    int rev = ( (sOre * (prices['Ore'] ?? 10)) +
        (sGas * (prices['Gas'] ?? 25)) +
        (sCrystals * (prices['Crystals'] ?? 100)) ).toInt();

    return {
      'soldOre': sOre,
      'soldGas': sGas,
      'soldCrystals': sCrystals,
      'revenue': (rev * multiplier).toInt(),
    };
  }

  // --- RANGE & DURATION ---
  static double getEffectiveRange(int fuel, int ai) => fuel + (aiFuelEfficiency * ai);

  static int getRangeRequired(double distanceAU) {
    double d = distanceAU.clamp(minDistance, maxDistance);
    return (rangeScale * (d - minDistance) / distanceSpan).ceil();
  }

  static double getEffectiveSpeed(int speed, int ai) => max(0.5, speed + (aiSpeedEfficiency * ai));

    static Duration calculateMissionDuration({
      required double distanceAU,
      required int speed,
      required int ai,
      required bool isElite,
      required String shipClass,
      bool isBetaTiming = false, // We can keep the param to avoid breaking signatures, but ignore it
    }) {
      // 1. Clamp distance to your game's range (0.5 to 32.0 AU)
      double d = distanceAU.clamp(minDistance, maxDistance);

      // 2. Calculate speed impact
      double effectiveSpeed = getEffectiveSpeed(speed, ai);
      double speedFactor = anchorSpeed / effectiveSpeed;

      // 3. Calculate time based on distance (Linear: d / max)
      // At 32 AU, this is 1.0 * liveBaseSeconds. At 16 AU, it is 0.5 * liveBaseSeconds.
      double travelSeconds = (d / maxDistance) * liveBaseSeconds * speedFactor;

      // 4. Apply Elite priority docking (1.0 for normal, ~0.5-0.9 for Elite)
      if (isElite) {
        travelSeconds *= getPriorityDockingMultiplier(getShipTier(shipClass), isElite);
      }

      // 5. Hard clamp to your 30s - 5h window
      int finalSeconds = travelSeconds.toInt().clamp(
        liveMinSeconds.toInt(),
        liveMaxSeconds.toInt()
      );

      return Duration(seconds: finalSeconds);
    }

  static double getMaxDistanceAU(int fuel, int ai) {
    double effectiveRange = getEffectiveRange(fuel, ai);
    return minDistance + (effectiveRange * distanceSpan / rangeScale);
  }
}
