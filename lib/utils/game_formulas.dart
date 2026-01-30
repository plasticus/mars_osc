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
  static const double globalRewardMultiplier = 5.0; // Your new x5 balance
  static const double solarBonusPerLevel = 0.03;   // 3% per Class Level
  static const double dockingBonusPerLevel = 0.02; // 2% per Class Level
  static const double eliteValueMultiplier = 1.25; // 25% value jump

  /// Helper to convert class strings to numeric levels for formulas
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
    // Start with global multiplier
    double total = baseReward * globalRewardMultiplier;

    // Apply AI Bonus (5% per level)
    double aiBonus = 1.0 + (aiLevel * 0.05);
    total *= aiBonus;

    // Apply CORPORATE PRESTIGE (Elite only)
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
    // Resources get x5 and AI bonus, but typically not the Elite Solar bonus
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
      // Bleeding Edge: No depreciation + 25% bonus
      double totalInvestment = (basePrice + upgradeInvestment).toDouble();
      return (totalInvestment * eliteValueMultiplier * (0.5 + condition * 0.5)).toInt();
    } else {
      // Standard: 30% depreciation on base and 50% on upgrades
      double standardBase = basePrice * 0.7;
      double standardUpgrades = upgradeInvestment * 0.5;
      return ((standardBase + standardUpgrades) * (0.5 + condition * 0.5)).toInt();
    }
  }

  /// 5. LEGACY DESIGNATION: Name Generator
  static String generateLegacyName() {
    final prefixes = ["Vanguard", "Zenith", "Obsidian", "Sovereign", "Stellar", "Infinite", "Absolute", "Eternal", "Apex", "Hallowed", "Celestial", "Omega", "Relic", "Titan", "Prime"];
    final nouns = ["Apex", "Chassis", "Frame", "Core", "Prime", "Hull", "Vessel", "Keel", "Engine", "Node", "Entity", "Origin", "Vector", "Pillar", "Sovereign"];
    final random = Random();
    return "${prefixes[random.nextInt(15)]} ${nouns[random.nextInt(15)]}";
  }

  // --- RANGE & DURATION (UNCHANGED BUT SYNCED) ---

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
    required String shipClass, // Changed to string for easier helper use
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

  /// MissionOK = EffectiveRange >= RangeRequired
  static bool canRunMission(double distanceAU, int fuel, int ai) {
    return getEffectiveRange(fuel, ai) >= getRangeRequired(distanceAU);
  }

  /// MaxDistanceAU = 0.5 + (EffectiveRange * 31.5 / 18)
  static double getMaxDistanceAU(int fuel, int ai) {
    double effectiveRange = getEffectiveRange(fuel, ai);
    double calculatedMax = minDistance + (effectiveRange * distanceSpan / rangeScale);
    return calculatedMax;
  }

}