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
              style: ElevatedButton.styleFrom(
                // Keep the background very subtle so it's not "too gray"
                backgroundColor: Colors.blue.withValues(alpha: 0.05),
                // Make the solars and text blue
                foregroundColor: Colors.blueAccent,
                side: BorderSide(
                  // Use a matching blue border to define the button shape
                  color: Colors.blueAccent.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero,
                elevation: 0,
              ),
              onPressed: (isMaxed || !canAfford) ? null : () {
                bool becameElite = state.upgradeShipStat(ship.id, statKey);
                Navigator.pop(context);
                if (becameElite) {
                  _showEliteTransformationDialog(context, ship);
                }
              },
              child: Text(
                isMaxed ? "MAX" : "⁂${cost.toString()}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEliteTransformationDialog(BuildContext context, Ship ship) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("ELITE TRANSFORMATION",
            style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${ship.nickname} has achieved Elite Status.",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(height: 32, color: Colors.white10),
            const Text("Attributes Gained:", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
          // Inside _showEliteTransformationDialog in dry_dock_upgrade_screen.dart
            _buildEliteFeature(Icons.timer, "Priority Docking", "Significantly faster mission turnaround."),
            _buildEliteFeature(Icons.trending_up, "Vanguard Honorarium", "Increased ⁂ Solars on all contracts."),
            _buildEliteFeature(Icons.analytics, "Bleeding Edge Tech", "Maximum appraisal value for corporate assets."),
            _buildEliteFeature(Icons.verified, "Legacy Designation", "Vessel identity locked into corporate history."),
            const SizedBox(height: 16),
            // Flavor text only for vessels that received a Legacy Name from the crew
            if (ship.renameLocked && !ship.hasBeenRenamed) ...[
              const Text("Notice:", style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text(
               "Since no custom designation was assigned prior, the Captain has issued a new name (${ship.nickname}) to honor this vessel's service.",
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ACKNOWLEDGED", style: TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildEliteFeature(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.orangeAccent),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: "$title: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  TextSpan(text: desc, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
