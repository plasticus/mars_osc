import 'dart:math';

class GameFormulas {
  // --- TUNING CONSTANTS ---
  static const double minDistance = 0.5;
  static const double maxDistance = 32.0;
  static const double rangeScale = 18.0;
  static const double distanceSpan = 31.5;

  static const double liveBaseSeconds = 36000.0;
  static const double liveMinSeconds = 600.0;
  static const double liveMaxSeconds = 36000.0;
  static const double distExponent = 0.5;
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
  static const int offlineSaleIntervalMinutes = 15; // How often the AI checks the market
  static const double offlineEfficiencyPenalty = 1.0; // 90% efficiency while app is closed
  static const int maxOfflineMinutes = 1440; // Cap at 24 hours of passive income

  /// Helper to convert class strings to numeric levels
  static int getShipClassLevel(String shipClass) {
    switch (shipClass) {
      case 'Mule': return 1;
      case 'Sprinter': return 2;
      case 'Miner': return 3;
      case 'Tanker': return 4;
      case 'Harvester': return 5;
      default: return 1;
    }
  }

  /// 1. REWARD AUTHORITY: Calculates final Solar payout
  static int calculateSolarReward({
    required int baseReward,
    required int aiLevel,
    required bool isElite,
    required String shipClass,
  }) {
    double total = baseReward * globalRewardMultiplier;
    double aiBonus = 1.0 + (aiLevel * 0.05);
    total *= aiBonus;

    if (isElite) {
      int level = getShipClassLevel(shipClass);
      total *= (1.0 + (level * solarBonusPerLevel));
    }

    return total.toInt();
  }

  /// 2. RESOURCE AUTHORITY: Calculates final cargo amount
  static int calculateResourceReward({
    required int baseAmount,
    required int aiLevel,
  }) {
    double total = baseAmount * globalRewardMultiplier;
    double aiBonus = 1.0 + (aiLevel * 0.05);
    return (total * aiBonus).toInt();
  }

  /// 3. PRIORITY DOCKING: Level * 2% faster
  static double getPriorityDockingMultiplier(int classLevel, bool isElite) {
    if (!isElite) return 1.0;
    return (1.0 - (classLevel * dockingBonusPerLevel)).clamp(0.5, 1.0);
  }

  /// 4. BLEEDING EDGE TECH: Value Calculation
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

  /// 5. LEGACY DESIGNATION: Name Generator
  static String generateLegacyName() {
    final prefixes = [
      "Vanguard", "Zenith", "Obsidian", "Sovereign", "Stellar",
      "Infinite", "Absolute", "Eternal", "Apex", "Hallowed",
      "Celestial", "Omega", "Relic", "Titan", "Prime",
      "Astral", "Ghost", "Iron", "Mythic", "Nova",
      "Oracle", "Phantom", "Solar", "Void", "Warp"
    ];

    final nouns = [
      "Monolith", "Sentinel", "Harbinger", "Paragon", "Conduit",
      "Aegis", "Catalyst", "Emissary", "Bastion", "Cipher",
      "Entity", "Origin", "Vector", "Pillar", "Sovereign",
      "Archon", "Colossus", "Dreadnought", "Icon", "Legion",
      "Nexus", "Oblivion", "Paladin", "Specter", "Titan"
    ];
    final random = Random();
    return "${prefixes[random.nextInt(15)]} ${nouns[random.nextInt(15)]}";
  }

  /// 6. OFFLINE AI AUTHORITY: Simulates sales while app is closed
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
      'minutesProcessed': ticks,
    };
  }

  /// 7. ONLINE AI AUTHORITY: Wrapper for the unified tick logic
  static Map<String, int> calculateOnlineAutoSale({
    required int ore,
    required int gas,
    required int crystals,
    required int tradeDepotLevel,
    required int maxStorage,
    required Map<String, int> marketPrices,
  }) {
    Random rng = Random();
    // Target: 8-12% of MAX CAPACITY
    double quotaPercent = 0.08 + (rng.nextDouble() * 0.04);
    int totalQuota = (maxStorage * quotaPercent).round();

    // Try to sell an equal amount of each
    int targetPerType = (totalQuota / 3).floor();
    int sOre = min(ore, targetPerType);
    int sGas = min(gas, targetPerType);
    int sCrystals = min(crystals, targetPerType);

    int remainingQuota = totalQuota - (sOre + sGas + sCrystals);
    if (remainingQuota > 0) {
      // Try to dump the remaining work into Ore
      int extraOre = min(ore - sOre, remainingQuota);
      sOre += extraOre;
      remainingQuota -= extraOre;

      // If we still have quota (Ore is empty), try Gas
      if (remainingQuota > 0) {
        int extraGas = min(gas - sGas, remainingQuota);
        sGas += extraGas;
        remainingQuota -= extraGas;
      }

      // If we STILL have quota (Gas is empty), try Crystals
      if (remainingQuota > 0) {
        int extraCrystals = min(crystals - sCrystals, remainingQuota);
        sCrystals += extraCrystals;
        remainingQuota -= extraCrystals;
      }
    }

    double multiplier = 1.0 + (tradeDepotLevel * 0.05);
    int revenue = ((sOre * (marketPrices['Ore'] ?? 10) +
        sGas * (marketPrices['Gas'] ?? 25) +
        sCrystals * (marketPrices['Crystals'] ?? 100)) * multiplier).toInt();

    return {
      'soldOre': sOre,
      'soldGas': sGas,
      'soldCrystals': sCrystals,
      'revenue': revenue,
    };
  }

  /// UNIFIED MATH CORE: The Balanced Quota Logic
  static Map<String, int> _simulateBalancedQuotaTick({
    required int ore,
    required int gas,
    required int crystals,
    required int maxStorage,
    required Map<String, int> prices,
    required double multiplier,
  }) {
    Random rng = Random();
    double quotaPercent = 0.08 + (rng.nextDouble() * 0.04);
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
        remainingQuota -= extraCrystals;
      }
    }

    int rev = 0;
    rev += (sOre * (prices['Ore'] ?? 10) * multiplier).toInt();
    rev += (sGas * (prices['Gas'] ?? 25) * multiplier).toInt();
    rev += (sCrystals * (prices['Crystals'] ?? 100) * multiplier).toInt();

    return {
      'soldOre': sOre,
      'soldGas': sGas,
      'soldCrystals': sCrystals,
      'revenue': rev,
    };
  }




  // --- RANGE & DURATION ---

  static double getEffectiveRange(int fuel, int ai) {
    ai = max(0, ai);
    return fuel + (aiFuelEfficiency * ai);
  }

  static int getRangeRequired(double distanceAU) {
    double d = distanceAU.clamp(minDistance, maxDistance);
    return (rangeScale * (d - minDistance) / distanceSpan).ceil();
  }

  static double getEffectiveSpeed(int speed, int ai) {
    ai = max(0, ai);
    return max(0.5, speed + (aiSpeedEfficiency * ai));
  }

  static Duration calculateMissionDuration({
    required double distanceAU,
    required int speed,
    required int ai,
    required bool isBetaTiming,
    required bool isElite,
    required String shipClass,
  }) {
    double d = distanceAU.clamp(minDistance, maxDistance);
    double effectiveSpeed = getEffectiveSpeed(speed, ai);
    double baseSecondsLive = liveBaseSeconds * pow(d / maxDistance, distExponent) * (anchorSpeed / effectiveSpeed);

    double finalSeconds;
    if (isBetaTiming) {
      finalSeconds = (baseSecondsLive * betaScale).clamp(betaMinSeconds, betaMaxSeconds);
    } else {
      finalSeconds = baseSecondsLive.clamp(liveMinSeconds, liveMaxSeconds);
    }

    if (isElite) {
      finalSeconds *= getPriorityDockingMultiplier(getShipClassLevel(shipClass), isElite);
    }

    return Duration(seconds: finalSeconds.toInt());
  }

  static bool canRunMission(double distanceAU, int fuel, int ai) {
    return getEffectiveRange(fuel, ai) >= getRangeRequired(distanceAU);
  }

  static double getMaxDistanceAU(int fuel, int ai) {
    double effectiveRange = getEffectiveRange(fuel, ai);
    double calculatedMax = minDistance + (effectiveRange * distanceSpan / rangeScale);
    return calculatedMax;
  }
}