import 'dart:math';

class GameFormulas {
  // --- TUNING CONSTANTS ---
  static const double minDistance = 0.5;
  static const double maxDistance = 32.0;
  static const double rangeScale = 18.0;
  static const double distanceSpan = 31.5; // maxDistance - minDistance

  static const double liveBaseSeconds = 36000.0; // 10 hours
  static const double liveMinSeconds = 600.0;    // 10 minutes
  static const double liveMaxSeconds = 36000.0;  // 10 hours
  static const double distExponent = 0.5;
  static const double anchorSpeed = 2.0;

  static const double betaScale = 0.015; // Roughly 30 seconds per unit for (AU/Speed)
  static const double betaMinSeconds = 10.0;   // 10 seconds
  static const double betaMaxSeconds = 300.0;  // 5 minutes
  static const double aiSpeedEfficiency = 0.5; // AI is 50% as effective as Speed stat for duration
  static const double aiFuelEfficiency = 0.5;  // AI is 50% as effective as Fuel stat for range

  // --- RANGE / DISTANCE GATE ---

  /// EffectiveRange = Fuel + 0.5 * AI
  static double getEffectiveRange(int fuel, int ai) {
    // Clamp AI to non-negative
    ai = max(0, ai);
    return fuel + (aiFuelEfficiency * ai);
  }

  /// RangeRequired = ceil( 18 * (DistanceAU - 0.5) / 31.5 )
  static int getRangeRequired(double distanceAU) {
    // Clamp distance just in case. Missions should generate within this range.
    double d = distanceAU.clamp(minDistance, maxDistance);
    return (rangeScale * (d - minDistance) / distanceSpan).ceil();
  }

  /// MissionOK = EffectiveRange >= RangeRequired
  static bool canRunMission(double distanceAU, int fuel, int ai) {
    return getEffectiveRange(fuel, ai) >= getRangeRequired(distanceAU);
  }

  /// MaxDistanceAU = 0.5 + (EffectiveRange * 31.5 / 18)
  /// (Optional helper) MaxDistanceAU a ship can reach (may exceed 32, but mission generator should not create missions > 32):
  /// Asserts for examples:
  /// Top Tanker example: Fuel=14, AI=8 => EffectiveRange=18 => maxDistanceAU == 32
  /// Top Harvester example: Fuel=13, AI=20 => EffectiveRange=23 => maxDistanceAU ~ 40.75
  static double getMaxDistanceAU(int fuel, int ai) {
    double effectiveRange = getEffectiveRange(fuel, ai);
    double calculatedMax = minDistance + (effectiveRange * distanceSpan / rangeScale);
    
    // Assertions for example values (remove for release)
    // if (fuel == 14 && ai == 8) {
    //   assert((calculatedMax - 32.0).abs() < 0.01, "Tanker MaxDistanceAU mismatch: $calculatedMax");
    // }
    // if (fuel == 13 && ai == 20) {
    //   assert((calculatedMax - 40.75).abs() < 0.01, "Harvester MaxDistanceAU mismatch: $calculatedMax");
    // }

    return calculatedMax;
  }

  // --- MISSION DURATION ---

  /// EffectiveSpeed = max(0.5, Speed + 0.5 * AI)
  static double getEffectiveSpeed(int speed, int ai) {
    // Clamp AI to non-negative
    ai = max(0, ai);
    return max(0.5, speed + (aiSpeedEfficiency * ai));
  }

  /// Duration calculation logic, with Beta mode switch.
  /// Asserts for example:
  /// Warp Shadow example duration: Distance=12, Speed=20, AI=10 => EffectiveSpeed=25 => Live duration about 29m (not clamped)
  static Duration calculateMissionDuration({
    required double distanceAU,
    required int speed,
    required int ai,
    required bool isBetaTiming,
  }) {
    double d = distanceAU.clamp(minDistance, maxDistance);
    double effectiveSpeed = getEffectiveSpeed(speed, ai);

    // BaseSecondsLive = 36000 * pow(DistanceAU / 32.0, 0.5) * (2.0 / EffectiveSpeed)
    double baseSecondsLive = liveBaseSeconds * pow(d / maxDistance, distExponent) * (anchorSpeed / effectiveSpeed);

    double finalSeconds;

    if (isBetaTiming) {
      // BETA MODE
      double baseSecondsBeta = baseSecondsLive * betaScale;
      finalSeconds = baseSecondsBeta.clamp(betaMinSeconds, betaMaxSeconds);
    } else {
      // LIVE MODE
      finalSeconds = baseSecondsLive.clamp(liveMinSeconds, liveMaxSeconds);
    }
    
    // Assertions for example values (remove for release)
    // if (distanceAU == 12 && speed == 20 && ai == 10) {
    //   double expectedLiveMinutes = 29.0;
    //   double expectedLiveSeconds = expectedLiveMinutes * 60;
    //   // Check if within 1 second of expectation
    //   if (!isBetaTiming) {
    //     assert((finalSeconds - expectedLiveSeconds).abs() < 1.0,
    //         "Warp Shadow Live Duration mismatch: ${finalSeconds / 60}m");
    //   }
    // }

    return Duration(seconds: finalSeconds.toInt());
  }
}
