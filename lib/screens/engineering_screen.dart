import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import 'trade_depot_screen.dart';

class EngineeringScreen extends StatelessWidget {
  const EngineeringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();


    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _UpgradeCard(
          title: "Hangar Expansion",
          icon: Icons.home_repair_service,
          currentLevel: state.hangarLevel,
          maxLevel: 5,
          upgrades: {
            2: _BaseUpgradeData(5000, "+2 Ship Slots (4 total)"),
            3: _BaseUpgradeData(15000, "+2 Ship Slots (6 total)"),
            4: _BaseUpgradeData(40000, "+2 Ship Slots (8 total)"),
            5: _BaseUpgradeData(100000, "+2 Ship Slots (10 total)"),
          },
          onUpgrade: (cost) => state.upgradeBase('Hangar', cost),
        ),

        _UpgradeCard(
          title: "Deep-Space Relay",
          icon: Icons.settings_remote,
          currentLevel: state.relayLevel,
          maxLevel: 4,
          upgrades: {
            2: _BaseUpgradeData(10000, "Unlocks Class: Miner + Belt missions"),
            3: _BaseUpgradeData(30000, "Unlocks Class: Tanker + Gas missions"),
            4: _BaseUpgradeData(75000, "Unlocks Class: Harvester + Rift missions"),
          },
          onUpgrade: (cost) => state.upgradeBase('Relay', cost),
        ),

        _UpgradeCard(
          title: "Broadcasting Array",
          icon: Icons.radar,
          currentLevel: state.broadcastingArrayLevel,
          maxLevel: 5,
          infoLine: state.broadcastingArrayPrestige > 0
              ? "Bonus Mission Value: +${(state.broadcastingArrayPrestige * 0.1).toStringAsFixed(1)}%"
              : null,
          upgrades: {
            2: _BaseUpgradeData(7500, "+2 Missions per category"),
            3: _BaseUpgradeData(25000, "+2 Missions per category"),
            4: _BaseUpgradeData(60000, "+2 Missions per category"),
            5: _BaseUpgradeData(120000, "+2 Missions per category (Max 10/cat)"),
          },
          onUpgrade: (cost) => state.upgradeBase('Broadcasting', cost),
          prestigeTitle: "Brand Reach",
          prestigeLevel: state.broadcastingArrayPrestige,
          prestigeEffect: "+0.1% Mission Value",
          prestigeCost: state.getBroadcastingArrayPrestigeCost(),
          onPrestigeUpgrade: () => state.upgradeBroadcastingArrayPrestige(),
        ),

        _UpgradeCard(
          title: "Neural Server Farm",
          icon: Icons.memory,
          currentLevel: state.serverFarmLevel,
          maxLevel: 3,
          infoLine: "Contract Speed Bonus: +${(state.serverFarmPrestige * 0.1).toStringAsFixed(1)}%",
          upgrades: {
            1: _BaseUpgradeData(8000, "All Fleet AI +0.5"),
            2: _BaseUpgradeData(20000, "All Fleet AI +1.0"),
            3: _BaseUpgradeData(50000, "All Fleet AI +2.0"),
          },
          onUpgrade: (cost) => state.upgradeBase('Server', cost),

          prestigeTitle: "Contract Overclock",
          prestigeLevel: state.serverFarmPrestige,
          prestigeEffect: "+0.1% Travel Speed",
          prestigeCost: state.getServerFarmPrestigeCost(),
          onPrestigeUpgrade: () => state.upgradeServerFarmPrestige(),
        ),


        _UpgradeCard(
          title: "Trade Depot / Silos",
          icon: Icons.store,
          currentLevel: state.tradeDepotLevel,
          maxLevel: 5,
          infoLine: "Max Storage: ${state.maxStorage} m³",
          upgrades: {
            2: _BaseUpgradeData(12000, "Max 1000 m³ + Auto-Sell @ 110%"),
            3: _BaseUpgradeData(35000, "Max 1500 m³ + Auto-Sell @ 115%"),
            4: _BaseUpgradeData(60000, "Max 2000 m³ + Auto-Sell @ 120%"),
            5: _BaseUpgradeData(100000, "Max 2500 m³ + Auto-Sell @ 125%"),
          },
          onUpgrade: (cost) => state.upgradeBase('Depot', cost),
          onOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TradeDepotScreen()),
            );
          },
          openLabel: "ENTER DEPOT",

          // Prestige (only used once base maxed)
          prestigeTitle: "Overflow Storage",
          prestigeLevel: state.tradeDepotPrestige,
          prestigeEffect: "+100 m³ Storage",
          prestigeCost: state.getTradeDepotPrestigeCost(),
          onPrestigeUpgrade: () => state.upgradeTradeDepotPrestige(),
        ),

        _UpgradeCard(
          title: "Repair Gantry",
          icon: Icons.construction,
          currentLevel: state.repairGantryLevel,
          maxLevel: 3,
          upgrades: {
            1: _BaseUpgradeData(6000, "-10% Maintenance Fees"),
            2: _BaseUpgradeData(18000, "-25% Maintenance Fees"),
            3: _BaseUpgradeData(45000, "Ships repair 2x faster"),
          },
          onUpgrade: (cost) => state.upgradeBase('Gantry', cost),
        ),
      ],
    );
  }
}

class _BaseUpgradeData {
  final int cost;
  final String effect;
  _BaseUpgradeData(this.cost, this.effect);
}

class _UpgradeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int currentLevel;
  final int maxLevel;
  final Map<int, _BaseUpgradeData> upgrades;
  final Function(int) onUpgrade;
  final VoidCallback? onOpen;
  final String? openLabel;
  final String? infoLine;

  // Prestige (optional)
  final String? prestigeTitle;
  final int? prestigeLevel;
  final String? prestigeEffect;
  final int? prestigeCost;
  final VoidCallback? onPrestigeUpgrade;

  const _UpgradeCard({
    required this.title,
    required this.icon,
    required this.currentLevel,
    required this.maxLevel,
    required this.upgrades,
    required this.onUpgrade,
    this.onOpen,
    this.openLabel,
    this.prestigeTitle,
    this.prestigeLevel,
    this.prestigeEffect,
    this.prestigeCost,
    this.onPrestigeUpgrade,
    this.infoLine,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();

    final nextLevel = currentLevel + 1;
    final upgradeData = upgrades[nextLevel];
    final bool isMaxed = currentLevel >= maxLevel;
    final bool hasPrestige =
        prestigeLevel != null && prestigeCost != null && onPrestigeUpgrade != null;
    final bool prestigeReady = isMaxed && hasPrestige;

    final bool canAffordUpgrade =
        upgradeData != null && state.solars >= upgradeData.cost;

    final bool canAffordPrestige =
        prestigeReady && state.solars >= (prestigeCost ?? 0);

    final String rightLabel = prestigeReady
        ? "Prestige ${prestigeLevel!}"
        : "Lv. $currentLevel";

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.orangeAccent),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(rightLabel, style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const Divider(height: 24),

            // Info line always visible when provided
            if (infoLine != null) ...[
              Text(
                infoLine!,
                style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
            ],

            // Open button (like ENTER DEPOT)
            if (onOpen != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onOpen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(openLabel ?? "OPEN"),
                  ),
                ),
              ),

            // -------- MAIN ACTION AREA --------
            if (!isMaxed && upgradeData != null) ...[
              Text(
                "Upgrade to Lv $nextLevel:",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                upgradeData.effect,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canAffordUpgrade ? () => onUpgrade(upgradeData.cost) : null,
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  label: Text("UPGRADE (⁂${upgradeData.cost})"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAffordUpgrade ? Colors.blue : Colors.blueGrey[800],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ] else if (prestigeReady) ...[
              Text(
                prestigeTitle ?? "Prestige",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              if (prestigeEffect != null) ...[
                Text(
                  prestigeEffect!,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canAffordPrestige ? onPrestigeUpgrade : null,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: Text("PRESTIGE (⁂${prestigeCost!})"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAffordPrestige ? Colors.purple : Colors.blueGrey[800],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ] else ...[
              const Text(
                "Systems fully operational.",
                style: TextStyle(color: Colors.greenAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
