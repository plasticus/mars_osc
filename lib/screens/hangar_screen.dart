import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/ship_model.dart';
import 'mission_board_screen.dart';
import 'shipyard_screen.dart';

class HangarScreen extends StatelessWidget {
  const HangarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Listening to GameState for balance and fleet updates
    final state = context.watch<GameState>();

    return Scaffold(
      appBar: AppBar(
        title: Text("${state.companyName}"),
        actions: [
          // Navigation to Shipyard
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: "Visit Shipyard",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ShipyardScreen()),
            ),
          ),
          // Solars Display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                "⁂ ${state.solars}",
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orangeAccent
                ),
              ),
            ),
          ),
        ],
      ),
      body: state.fleet.isEmpty
          ? const Center(child: Text("Hangar Empty. Visit the Shipyard to buy your first ship!"))
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: state.fleet.length,
        itemBuilder: (context, index) {
          return ShipCard(ship: state.fleet[index]);
        },
      ),
      // Main button to find work
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MissionBoardScreen()),
          );
        },
        label: const Text("Mission Board"),
        icon: const Icon(Icons.assignment),
        backgroundColor: Colors.deepOrange,
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Nickname and Status Chip
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
            const SizedBox(height: 16),

            // Row 2: Condition Bar
            const Text("Condition", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: ship.condition,
              backgroundColor: Colors.grey[800],
              color: ship.condition > 0.5 ? Colors.green : (ship.condition > 0.2 ? Colors.orange : Colors.red),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),

            // Repair Button (Only shows if ship is docked and damaged)
            if (ship.missionEndTime == null && ship.condition < 1.0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => state.repairShip(ship.id),
                  icon: const Icon(Icons.build, size: 16),
                  label: Text("Repair (⁂${((1.0 - ship.condition) * 500).toInt()})"),
                  style: TextButton.styleFrom(foregroundColor: Colors.orangeAccent),
                ),
              ),

            // Row 3: Mission Progress (Only shows if on mission)
            if (ship.missionEndTime != null && ship.missionStartTime != null)
              _buildMissionProgress(context, ship),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionProgress(BuildContext context, Ship ship) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final now = DateTime.now();

        // CHECK: Is the mission finished?
        if (now.isAfter(ship.missionEndTime!)) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Provider.of<GameState>(context, listen: false).completeMission(ship.id);
                },
                child: const Text("COLLECT REWARD & DOCK"),
              ),
            ),
          );
        }

        // Timer and Progress Bar Calculation
        final totalDuration = ship.missionEndTime!.difference(ship.missionStartTime!);
        final elapsed = now.difference(ship.missionStartTime!);
        double progress = elapsed.inSeconds / totalDuration.inSeconds;

        final remaining = ship.missionEndTime!.difference(now);
        final timeStr = "${remaining.inHours}:${(remaining.inMinutes % 60).toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}";

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("In Transit", style: TextStyle(fontSize: 12)),
                Text(timeStr, style: const TextStyle(fontFamily: 'monospace', color: Colors.purpleAccent)),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[800],
              color: Colors.purpleAccent,
              minHeight: 4,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusChip() {
    String label = "READY";
    Color color = Colors.blue;
    if (ship.isRepairing) {
      label = "REPAIRING";
      color = Colors.orange;
    } else if (ship.missionEndTime != null) {
      label = "IN TRANSIT";
      color = Colors.purple;
    }

    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}