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
          upgrades: {
            2: _BaseUpgradeData(7500, "+2 Missions per category"),
            3: _BaseUpgradeData(25000, "+2 Missions per category"),
            4: _BaseUpgradeData(60000, "+2 Missions per category"),
            5: _BaseUpgradeData(120000, "+2 Missions per category (Max 10/cat)"),
          },
          onUpgrade: (cost) => state.upgradeBase('Broadcasting', cost),
        ),

        _UpgradeCard(
          title: "Neural Server Farm",
          icon: Icons.memory,
          currentLevel: state.serverFarmLevel,
          maxLevel: 3,
          upgrades: {
            1: _BaseUpgradeData(8000, "All Fleet AI +0.5"),
            2: _BaseUpgradeData(20000, "All Fleet AI +1.0"),
            3: _BaseUpgradeData(50000, "All Fleet AI +2.0"),
          },
          onUpgrade: (cost) => state.upgradeBase('Server', cost),
        ),

        _UpgradeCard(
          title: "Trade Depot / Silos",
          icon: Icons.store,
          currentLevel: state.tradeDepotLevel,
          maxLevel: 5,
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

          // --- Prestige (only shows once base level is max) ---
          prestigeTitle: "Overflow Storage",
          prestigeLevel: state.tradeDepotPrestige,
          prestigeEffect: "+100 m³ Max Storage",
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

  // --- Prestige (optional) ---
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
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();

    final nextLevel = currentLevel + 1;
    final upgradeData = upgrades[nextLevel];
    final bool isMaxed = currentLevel >= maxLevel;

    final bool canAfford =
        upgradeData != null && state.solars >= upgradeData.cost;

    final bool showPrestige =
        isMaxed && prestigeLevel != null && prestigeCost != null && onPrestigeUpgrade != null;

    final bool canAffordPrestige =
        showPrestige && state.solars >= (prestigeCost ?? 0);

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
                Text("Lv. $currentLevel", style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const Divider(height: 24),

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
                  onPressed: canAfford ? () => onUpgrade(upgradeData.cost) : null,
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  label: Text("UPGRADE (⁂${upgradeData.cost})"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAfford ? Colors.blue : Colors.blueGrey[800],
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

            if (showPrestige) ...[
              const Divider(height: 28),
              Text(
                prestigeTitle ?? "Prestige",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Text(
                "Prestige Lv. ${prestigeLevel!}",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              if (prestigeEffect != null) ...[
                const SizedBox(height: 4),
                Text(prestigeEffect!, style: const TextStyle(fontSize: 13)),
              ],
              const SizedBox(height: 14),
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
            ],
          ],
        ),
      ),
    );
  }
}
