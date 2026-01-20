import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/mission_model.dart';
import '../services/mission_service.dart';

class MissionBoardScreen extends StatefulWidget {
  const MissionBoardScreen({super.key});

  @override
  State<MissionBoardScreen> createState() => _MissionBoardScreenState();
}

class _MissionBoardScreenState extends State<MissionBoardScreen> {
  final MissionService _missionService = MissionService();

  @override
  void initState() {
    super.initState();
    // Generate missions if the board is empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<GameState>(context, listen: false);
      if (state.availableMissions.isEmpty) {
        state.updateMissions(_missionService.generateMissions(state.scanArrayLevel));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Missions"),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showBoardInfo(context),
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: state.availableMissions.length,
        itemBuilder: (context, index) {
          final mission = state.availableMissions[index];
          return MissionCard(mission: mission);
        },
      ),
    );
  }

  void _showBoardInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mission Board"),
        content: const Text("Missions refresh every 12 hours. Ensure your ship meets the Fuel, Shield, and Cargo requirements before launching."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Got it"))],
      ),
    );
  }
}

class MissionCard extends StatelessWidget {
  final Mission mission;
  const MissionCard({super.key, required this.mission});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepOrange.withOpacity(0.2),
          child: const Icon(Icons.rocket_launch, color: Colors.deepOrange),
        ),
        title: Text(mission.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${mission.distanceAU} AU | ⁂ ${mission.rewardSolars}"),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mission.description),
                const Divider(),
                const Text("Requirements:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                _reqRow(Icons.shield, "Shield Level: ${mission.minShieldLevel}"),
                _reqRow(Icons.inventory_2, "Min Cargo: ${mission.minCargo}"),
                _reqRow(Icons.timer, "Est. Duration: ${mission.baseDurationMinutes}m"),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _selectShipForMission(context),
                    child: const Text("ASSIGN SHIP"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reqRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _selectShipForMission(BuildContext context) {
    final state = Provider.of<GameState>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FIXED: Removed backslash from string interpolation
              Text("Select Ship for ${mission.title}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              // FIXED: Removed backslash from string interpolation
              Text("Requires: ${mission.requiredClass} | ${mission.distanceAU} AU",
                  style: const TextStyle(color: Colors.grey)),
              const Divider(height: 30),
              Expanded(
                child: ListView.builder(
                  itemCount: state.fleet.length,
                  itemBuilder: (context, index) {
                    final ship = state.fleet[index];
                    final String? error = mission.getMissingRequirement(ship);
                    final bool isBusy = ship.missionEndTime != null || ship.isRepairing;

                    return ListTile(
                      enabled: error == null && !isBusy,
                      leading: Icon(Icons.rocket,
                          color: error == null && !isBusy ? Colors.deepOrange : Colors.grey),
                      title: Text(ship.nickname),
                      subtitle: Text(error ?? (isBusy ? "Currently Busy" : "Ready for Launch")),
                      trailing: error == null && !isBusy
                          ? ElevatedButton(
                        onPressed: () {
                          state.startMission(ship.id, mission);
                          Navigator.pop(context); // Close sheet
                          Navigator.pop(context); // Return to Hangar
                          ScaffoldMessenger.of(context).showSnackBar(
                            // FIXED: Removed backslash from string interpolation
                            SnackBar(content: Text("${ship.nickname} launched!")),
                          );
                        },
                        child: const Text("LAUNCH"),
                      )
                          : const Icon(Icons.lock_outline, size: 16),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}