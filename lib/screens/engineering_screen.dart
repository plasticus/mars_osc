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
            2: _BaseUpgradeData(10000, "Unlocks Tankers + New distant missions"),
            3: _BaseUpgradeData(30000, "Unlocks Miners + Belt mining missions"),
            4: _BaseUpgradeData(75000, "Unlocks Harvesters + Rift missions"),
          },
          onUpgrade: (cost) => state.upgradeBase('Relay', cost),
        ),
        _UpgradeCard(
          title: "Broadcasting Array",
          icon: Icons.radar,
          currentLevel: state.broadcastingArrayLevel,
          maxLevel: 4,
          upgrades: {
            2: _BaseUpgradeData(7500, "10 Active Contracts available"),
            3: _BaseUpgradeData(25000, "20 Active Contracts available"),
            4: _BaseUpgradeData(60000, "40 Active Contracts available"),
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
          maxLevel: 3,
          upgrades: {
            1: _BaseUpgradeData(12000, "Auto-sell AI avoids 'Bottom' 10% of prices"),
            2: _BaseUpgradeData(35000, "Auto-sell AI avoids 'Bottom' 25% of prices"),
            3: _BaseUpgradeData(90000, "Holding Silos unlocked (Manual hold/sell)"),
          },
          onUpgrade: (cost) => state.upgradeBase('Depot', cost),
          onOpen: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const TradeDepotScreen()));
          },
          openLabel: "ENTER DEPOT",
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

  const _UpgradeCard({
    required this.title,
    required this.icon,
    required this.currentLevel,
    required this.maxLevel,
    required this.upgrades,
    required this.onUpgrade,
    this.onOpen,
    this.openLabel,
  });

  @override
  Widget build(BuildContext context) {
    final nextLevel = currentLevel + 1;
    final upgradeData = upgrades[nextLevel];
    final bool isMaxed = currentLevel >= maxLevel;
    final state = Provider.of<GameState>(context, listen: false);
    final bool canAfford = upgradeData != null && state.solars >= upgradeData.cost;

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
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text("Lv. $currentLevel", style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const Divider(height: 24),
            
            // OPEN BUTTON (If applicable)
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

            if (isMaxed)
              const Text("Systems fully operational.", style: TextStyle(color: Colors.greenAccent))
            else if (upgradeData != null) ...[
              Text("Next: ${upgradeData.effect}", style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canAfford ? () => onUpgrade(upgradeData.cost) : null,
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  label: Text("UPGRADE (⁂${upgradeData.cost})"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[800],
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
