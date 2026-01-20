import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/ship_model.dart';

class DryDockUpgradeScreen extends StatelessWidget {
  final Ship ship;
  const DryDockUpgradeScreen({super.key, required this.ship});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("UPGRADE: ${ship.nickname}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
          const SizedBox(height: 8),
          Text("${ship.modelName} Class Systems", style: TextStyle(color: Colors.grey[400])),
          const Divider(height: 32),

          _UpgradeRow(label: "Speed", current: ship.speed, max: ship.maxSpeed, statKey: 'speed', ship: ship),
          _UpgradeRow(label: "Cargo", current: ship.cargoCapacity, max: ship.maxCargo, statKey: 'cargo', ship: ship),
          _UpgradeRow(label: "Fuel", current: ship.fuelCapacity, max: ship.maxFuel, statKey: 'fuel', ship: ship),
          _UpgradeRow(label: "Shields", current: ship.shieldLevel, max: ship.maxShield, statKey: 'shield', ship: ship),
          _UpgradeRow(label: "AI Core", current: ship.aiLevel, max: ship.maxAI, statKey: 'ai', ship: ship),
          
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CLOSE SYSTEMS ACCESS"),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  final String label;
  final int current;
  final int max;
  final String statKey;
  final Ship ship;

  const _UpgradeRow({
    required this.label,
    required this.current,
    required this.max,
    required this.statKey,
    required this.ship,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GameState>(context);
    final bool isMaxed = current >= max;
    final int cost = state.getUpgradeCost(ship, current);
    final bool canAfford = state.solars >= cost;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("Level $current / $max", style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: max > 0 ? current / max : 1.0,
              backgroundColor: Colors.grey[900],
              color: isMaxed ? Colors.greenAccent : Colors.orangeAccent,
              minHeight: 6,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: ElevatedButton(
              onPressed: (isMaxed || !canAfford) ? null : () => state.upgradeShipStat(ship.id, statKey),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                backgroundColor: Colors.blueGrey[800],
              ),
              child: Text(isMaxed ? "MAX" : "⁂$cost", style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
