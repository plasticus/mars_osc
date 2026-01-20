import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/mission_model.dart';

class MissionBoardScreen extends StatefulWidget {
  const MissionBoardScreen({super.key});

  @override
  State<MissionBoardScreen> createState() => _MissionBoardScreenState();
}

class _MissionBoardScreenState extends State<MissionBoardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<GameState>(context, listen: false);
      if (state.availableMissions.isEmpty) {
        state.generateNewMissions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final shipClasses = ["Mule", "Sprinter", "Tanker", "Miner", "Harvester"];

    return DefaultTabController(
      length: shipClasses.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: shipClasses.map((c) => Tab(text: c)).toList(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${state.availableMissions.length} ACTIVE CONTRACTS", 
                  style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => state.generateNewMissions(),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text("REFRESH", style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: shipClasses.map((className) {
                final classMissions = state.availableMissions.where((m) => m.requiredClass == className).toList();
                
                if (classMissions.isEmpty) {
                  return const Center(child: Text("No contracts available for this class.", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: classMissions.length,
                  itemBuilder: (context, index) {
                    return MissionCard(mission: classMissions[index]);
                  },
                );
              }).toList(),
            ),
          ),
        ],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepOrange.withOpacity(0.1),
          child: const Icon(Icons.assignment_outlined, color: Colors.deepOrange, size: 20),
        ),
        title: Text(mission.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        subtitle: Text(
          "${mission.distanceAU.toStringAsFixed(2)} AU | Reqs: ${mission.minShieldLevel} SHD, ${mission.minCargo} CRG | ⁂ ${mission.rewardSolars}",
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Text(mission.description, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RequirementChip(icon: Icons.shield, label: "SHD", value: "${mission.minShieldLevel}"),
                    _RequirementChip(icon: Icons.inventory_2, label: "CRG", value: "${mission.minCargo}"),
                    _RequirementChip(icon: Icons.timer, label: "TIME", value: "${mission.baseDurationMinutes}m"),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _selectShipForMission(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange[900],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("ASSIGN SHIP & LAUNCH"),
                  ),
                ),
              ],
            ),
          ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mission.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("Class: ${mission.requiredClass} | Distance: ${mission.distanceAU.toStringAsFixed(2)} AU",
                  style: const TextStyle(color: Colors.grey)),
              const Divider(height: 32),
              const Text("COMPATIBLE SHIPS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: state.fleet.length,
                  itemBuilder: (context, index) {
                    final ship = state.fleet[index];
                    final String? error = mission.getMissingRequirement(ship);
                    final bool isBusy = ship.missionEndTime != null || ship.busyUntil != null;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: error == null && !isBusy,
                      leading: Icon(Icons.rocket_launch,
                          color: error == null && !isBusy ? Colors.deepOrange : Colors.grey[800]),
                      title: Text(ship.nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(error ?? (isBusy ? "System Busy" : "Flight Ready"),
                        style: TextStyle(color: error == null && !isBusy ? Colors.greenAccent : Colors.redAccent, fontSize: 12)),
                      trailing: (error == null && !isBusy)
                          ? ElevatedButton(
                        onPressed: () {
                          state.startMission(ship.id, mission);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("${ship.nickname} is away.")),
                          );
                        },
                        child: const Text("LAUNCH"),
                      )
                          : const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
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

class _RequirementChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RequirementChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.orangeAccent),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
