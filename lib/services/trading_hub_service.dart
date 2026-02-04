import 'dart:async';
import 'dart:math';
import '../models/log_entry.dart';

class TradingHubService {
  Timer? _marketTimer;

  // Configuration
  static const Duration onlineTickRate = Duration(minutes: 1);

  // Callback to update the GameState
  final Function(int solars, int ore, int gas, int crystals, LogEntry? log) onTradeExecuted;

  TradingHubService({required this.onTradeExecuted});

  /// Starts the minute-by-minute online seller
  void startTradingLoop({
    required Function() requestCurrentState, // Callback to get fresh data
  }) {
    _marketTimer?.cancel();
    _marketTimer = Timer.periodic(onlineTickRate, (_) {
      final state = requestCurrentState();
      _performOnlineTick(
        tradeDepotLevel: state['level'],
        maxStorage: state['maxStorage'],
        ore: state['ore'],
        gas: state['gas'],
        crystals: state['crystals'],
      );
    });
  }

  void stop() {
    _marketTimer?.cancel();
  }

  // --- ONLINE LOGIC ---

  void _performOnlineTick({
    required int tradeDepotLevel,
    required int maxStorage,
    required int ore,
    required int gas,
    required int crystals,
  }) {
    // 1. Calculate Total Quota (User Approved: % of Max Storage)
    double basePercent = tradeDepotLevel * 0.01; // 1% per level
    int totalQuota = (maxStorage * basePercent).round();
    totalQuota = max(1, totalQuota); // Always sell at least 1 if possible

    // 2. Calculate the Equitable Split (33/33/33 Rollover)
    final sales = _calculateEquitableSales(
      totalQuota: totalQuota,
      ore: ore,
      gas: gas,
      crystals: crystals
    );

    int soldOre = sales['Ore']!;
    int soldGas = sales['Gas']!;
    int soldCrystals = sales['Crystals']!;

    if (soldOre == 0 && soldGas == 0 && soldCrystals == 0) return;

    // 3. Calculate Revenue
    int revenue = _calculateRevenue(soldOre, soldGas, soldCrystals);
    double bonusMult = 1.0 + (tradeDepotLevel * 0.05);
    revenue = (revenue * bonusMult).toInt();

    // 4. Execute with DATA fields for chips
    onTradeExecuted(
      revenue,
      -soldOre,
      -soldGas,
      -soldCrystals,
      LogEntry(
        timestamp: DateTime.now(),
        title: "Auto-Trade",
        // The text now only shows what is LEFT
        details: "Remaining: ${ore - soldOre} Ore | ${gas - soldGas} Gas | ${crystals - soldCrystals} Crystals",
        solarChange: revenue,
        isPositive: true,
        // Pass data for chips
        oreSold: soldOre,
        gasSold: soldGas,
        crystalsSold: soldCrystals,
      )
    );
  }

  // --- OFFLINE LOGIC ---

  void processOfflineCatchup({
    required DateTime lastActiveTime,
    required int tradeDepotLevel,
    required int maxStorage,
    required int ore,
    required int gas,
    required int crystals,
  }) {
    final now = DateTime.now();
    final minutesAway = now.difference(lastActiveTime).inMinutes;

    // If away less than 5 minutes, skip (prevents glitches on quick switching)
    if (minutesAway < 5) return;

    // 1. Calculate Total Potential Capacity
    // We assume the same speed as Online, but capped at 24 hours (1440 mins)
    int validMinutes = min(minutesAway, 1440);

    double basePercent = tradeDepotLevel * 0.01;
    int quotaPerMinute = (maxStorage * basePercent).round();
    quotaPerMinute = max(1, quotaPerMinute);

    // To be safe, we apply an 80% efficiency factor for offline operations
    int totalOfflineQuota = (quotaPerMinute * validMinutes * 0.8).toInt();

    // 2. Cap Quota at Actual Inventory (Can't sell what we don't have)
    int totalInventory = ore + gas + crystals;
    int finalQuota = min(totalOfflineQuota, totalInventory);

    if (finalQuota <= 0) return;

    // 3. Calculate the Split (Using the same Equitable Logic)
    final sales = _calculateEquitableSales(
      totalQuota: finalQuota,
      ore: ore,
      gas: gas,
      crystals: crystals
    );

    int soldOre = sales['Ore']!;
    int soldGas = sales['Gas']!;
    int soldCrystals = sales['Crystals']!;

    // 4. Calculate Revenue (Use Flat Prices for Offline to be fair)
    int revenue = (soldOre * 10) + (soldGas * 25) + (soldCrystals * 100);
    double bonusMult = 1.0 + (tradeDepotLevel * 0.05);
    revenue = (revenue * bonusMult).toInt();

    if (revenue > 0) {
      onTradeExecuted(
        revenue,
        -soldOre,
        -soldGas,
        -soldCrystals,
        LogEntry(
          timestamp: now,
          title: "Offline Operations ($validMinutes mins)",
          details: "Remaining: ${ore - soldOre} Ore | ${gas - soldGas} Gas | ${crystals - soldCrystals} Crystals",
          solarChange: revenue,
          isPositive: true,
          oreSold: soldOre,
          gasSold: soldGas,
          crystalsSold: soldCrystals,
          tradeDepotLevel: tradeDepotLevel, // <--- SNAPSHOT LEVEL
        )
      );
    }
  }

  // --- THE ALGORITHM: EQUITABLE ROLLOVER ---

  Map<String, int> _calculateEquitableSales({
    required int totalQuota,
    required int ore,
    required int gas,
    required int crystals,
  }) {
    int remainingQuota = totalQuota;
    int currentOre = ore;
    int currentGas = gas;
    int currentCrystals = crystals;

    int sellOre = 0;
    int sellGas = 0;
    int sellCrystals = 0;

    // We do a few passes to distribute the quota evenly.
    // Pass 1: Try to give everyone 1/3
    // Pass 2: If anyone couldn't take their 1/3, give the remainder to the others
    // We loop until quota is gone or inventory is empty.

    while (remainingQuota > 0 && (currentOre > 0 || currentGas > 0 || currentCrystals > 0)) {
      // Count how many types still have stock
      int activeTypes = 0;
      if (currentOre > 0) activeTypes++;
      if (currentGas > 0) activeTypes++;
      if (currentCrystals > 0) activeTypes++;

      if (activeTypes == 0) break; // Should be caught by while loop, but safety first

      // Determine "fair share" for this pass
      // We take a chunk (e.g., 10% of remainder) to allow smooth convergence,
      // OR just divide by activeTypes.
      // To get the "33/33/33" perfectly, we just divide the total remainder by active types.
      int targetPerType = (remainingQuota / activeTypes).ceil();

      // Apply to Ore
      if (currentOre > 0) {
        int actual = min(targetPerType, remainingQuota); // Cap at global remainder
        actual = min(actual, currentOre); // Cap at actual stock

        sellOre += actual;
        currentOre -= actual;
        remainingQuota -= actual;
      }

      if (remainingQuota <= 0) break;

      // Apply to Gas
      if (currentGas > 0) {
        int actual = min(targetPerType, remainingQuota);
        actual = min(actual, currentGas);

        sellGas += actual;
        currentGas -= actual;
        remainingQuota -= actual;
      }

      if (remainingQuota <= 0) break;

      // Apply to Crystals
      if (currentCrystals > 0) {
        int actual = min(targetPerType, remainingQuota);
        actual = min(actual, currentCrystals);

        sellCrystals += actual;
        currentCrystals -= actual;
        remainingQuota -= actual;
      }
    }

    return {
      'Ore': sellOre,
      'Gas': sellGas,
      'Crystals': sellCrystals,
    };
  }

  int _calculateRevenue(int ore, int gas, int crystals) {
    // Sine wave variance
    double variance = 1.0 + (sin(DateTime.now().minute / 10) * 0.2);
    return ((ore * 10 * variance) + (gas * 25 * variance) + (crystals * 100 * variance)).toInt();
  }
}