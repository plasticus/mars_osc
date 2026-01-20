import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/ship_model.dart';
import 'dry_dock_shipyard_screen.dart';
import 'dry_dock_upgrade_screen.dart';

class DryDockScreen extends StatefulWidget {
  const DryDockScreen({super.key});

  @override
  State<DryDockScreen> createState() => _DryDockScreenState();
}

class _DryDockScreenState extends State<DryDockScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    
    // dockedShips are those not on a mission (but might be being repaired/upgraded)
    final dockedShips = state.fleet.where((s) => s.missionEndTime == null).toList();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Hangar Space: ${state.fleet.length} / ${state.maxFleetSize}", style: const TextStyle(color: Colors.grey)),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DryDockShipyardScreen()),
                ),
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text("BUY NEW SHIP"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[800]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Expanded(
            child: dockedShips.isEmpty
                ? Center(
                    child: Text(
                      state.fleet.isEmpty 
                        ? "Dry Dock Empty. Buy your first ship!" 
                        : "All ships are currently out on missions.",
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: dockedShips.length,
                    itemBuilder: (context, index) {
                      return ShipCard(ship: dockedShips[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ShipCard extends StatelessWidget {
  final Ship ship;
  const ShipCard({super.key, required this.ship});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GameState>(context, listen: false);
    final bool isBusy = ship.busyUntil != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ship.nickname, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("${ship.modelName} (${ship.shipClass})", style: TextStyle(color: Colors.grey[400])),
                  ],
                ),
                _buildStatusChip(),
              ],
            ),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatIcon(icon: Icons.speed, label: "SPD", value: "${ship.speed}"),
                _StatIcon(icon: Icons.inventory_2, label: "CRG", value: "${ship.cargoCapacity}"),
                _StatIcon(icon: Icons.local_gas_station, label: "FUEL", value: "${ship.fuelCapacity}"),
                _StatIcon(icon: Icons.shield, label: "SHD", value: "${ship.shieldLevel}"),
                _StatIcon(icon: Icons.psychology, label: "AI", value: "${ship.aiLevel}"),
              ],
            ),
            
            const SizedBox(height: 16),
            const Text("Condition", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: ship.condition,
              backgroundColor: Colors.grey[800],
              color: ship.condition > 0.5 ? Colors.green : (ship.condition > 0.2 ? Colors.orange : Colors.red),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),

            if (isBusy) 
              _buildMaintenanceProgress(ship)
            else ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => DryDockUpgradeScreen(ship: ship),
                        );
                      },
                      icon: const Icon(Icons.upgrade),
                      label: const Text("UPGRADE"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[900],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (ship.condition < 1.0 && state.solars >= state.getRepairCost(ship)) 
                          ? () => state.repairShip(ship.id) 
                          : null,
                      icon: const Icon(Icons.build, size: 16),
                      label: Text("REPAIR (⁂${state.getRepairCost(ship)})"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    String label = "DOCKED";
    Color color = Colors.blueAccent;
    if (ship.currentTask != null) {
      label = ship.currentTask!.toUpperCase();
      color = Colors.orangeAccent;
    }

    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildMaintenanceProgress(Ship ship) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final now = DateTime.now();
        if (ship.busyUntil == null || now.isAfter(ship.busyUntil!)) {
          return const SizedBox.shrink();
        }

        final remaining = ship.busyUntil!.difference(now);
        final timeStr = "${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}";

        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${ship.currentTask} Progress...", style: const TextStyle(fontSize: 10, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                  Text(timeStr, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.orangeAccent)),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                backgroundColor: Colors.grey[800],
                color: Colors.orangeAccent,
                minHeight: 4,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatIcon({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }
}
