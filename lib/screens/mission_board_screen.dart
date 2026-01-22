import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/mission_model.dart';
import 'dart:math';

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

  /// True if ship is currently busy (mission running or cooldown in future).
  bool _isShipBusy(dynamic ship) {
    final now = DateTime.now();
    final missionBusy =
        ship.missionEndTime != null && ship.missionEndTime.isAfter(now);
    final cooldownBusy =
        ship.busyUntil != null && ship.busyUntil.isAfter(now);
    return missionBusy || cooldownBusy;
  }

  // Returns true if any ship meets requirements AND is not busy
  bool _canAnyShipDoMissionNow(GameState state, Mission mission) {
    for (var ship in state.fleet) {
      if (!_isShipBusy(ship) && mission.getMissingRequirement(ship) == null) {
        return true;
      }
    }
    return false;
  }

  int _estimateMissionValue(Mission mission) {
    int val = mission.rewardSolars;
    if (mission.rewardResource != null) {
      int price = 0;
      switch (mission.rewardResource) {
        case 'Ore':
          price = 10;
          break;
        case 'Gas':
          price = 25;
          break;
        case 'Crystals':
          price = 100;
          break;
        default:
          price = 0;
          break;
      }
      val += (mission.rewardResourceAmount * price);
    }
    return val;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();

    // Requested order: Mule-Sprinter-Miner-Tanker-Harvester
    final shipClasses = ["Mule", "Sprinter", "Miner", "Tanker", "Harvester"];

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
                Text(
                  "${state.availableMissions.length} ACTIVE CONTRACTS",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                final classMissions = state.availableMissions
                    .where((m) => m.requiredClass == className)
                    .toList();

                // Precompute fleet maxima ONCE per class tab for red highlighting
                final classShips =
                state.fleet.where((s) => s.shipClass == className).toList();

                int maxShield = 0;
                int maxCargo = 0;
                int maxFuel = 0;

                for (final s in classShips) {
                  maxShield = max(maxShield, s.shieldLevel);
                  maxCargo = max(maxCargo, s.cargoCapacity);
                  maxFuel = max(maxFuel, s.fuelCapacity);
                }

                final hasAnyShipOfClass = classShips.isNotEmpty;

                classMissions.sort((a, b) {
                  final aDoable = _canAnyShipDoMissionNow(state, a);
                  final bDoable = _canAnyShipDoMissionNow(state, b);

                  if (aDoable && !bDoable) return -1;
                  if (!aDoable && bDoable) return 1;

                  final valA = _estimateMissionValue(a);
                  final valB = _estimateMissionValue(b);
                  return valB.compareTo(valA);
                });

                if (classMissions.isEmpty) {
                  return const Center(
                    child: Text(
                      "No contracts available for this class.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: classMissions.length,
                  itemBuilder: (context, index) {
                    final mission = classMissions[index];
                    final bool isDoable = _canAnyShipDoMissionNow(state, mission);

                    // Use precomputed maxima for the class to decide failures
                    final bool shieldFail =
                        !hasAnyShipOfClass || maxShield < mission.minShieldLevel;
                    final bool cargoFail =
                        !hasAnyShipOfClass || maxCargo < mission.minCargo;
                    final bool fuelFail =
                        !hasAnyShipOfClass || (maxFuel * 10) < mission.distanceAU;

                    return MissionCard(
                      mission: mission,
                      isDoable: isDoable,
                      shieldFail: shieldFail,
                      cargoFail: cargoFail,
                      fuelFail: fuelFail,
                    );
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
  final bool isDoable;
  final bool shieldFail;
  final bool cargoFail;
  final bool fuelFail;

  const MissionCard({
    super.key,
    required this.mission,
    required this.isDoable,
    this.shieldFail = false,
    this.cargoFail = false,
    this.fuelFail = false,
  });

  bool _isShipBusy(dynamic ship) {
    final now = DateTime.now();
    final missionBusy =
        ship.missionEndTime != null && ship.missionEndTime.isAfter(now);
    final cooldownBusy =
        ship.busyUntil != null && ship.busyUntil.isAfter(now);
    return missionBusy || cooldownBusy;
  }

  @override
  Widget build(BuildContext context) {
    final Color mainColor = isDoable ? Colors.deepOrange : Colors.grey;
    final Color textColor = isDoable ? Colors.white : Colors.grey;

    String rewardStr = "⁂ ${mission.rewardSolars}";
    if (mission.rewardResource != null && mission.rewardResourceAmount > 0) {
      if (mission.rewardSolars > 0) {
        rewardStr += " + ";
      } else {
        rewardStr = "";
      }
      rewardStr += "${mission.rewardResourceAmount} ${mission.rewardResource}";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDoable
            ? BorderSide.none
            : BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      color: isDoable ? null : Colors.black12,
      child: ExpansionTile(
        iconColor: mainColor,
        collapsedIconColor: mainColor,
        leading: CircleAvatar(
          backgroundColor: mainColor.withOpacity(0.1),
          child: Icon(Icons.assignment_outlined, color: mainColor, size: 20),
        ),
        title: Text(
          mission.title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        subtitle: Text(
          "${mission.distanceAU.toStringAsFixed(2)} AU | $rewardStr",
          style: TextStyle(
            fontSize: 11,
            color: isDoable ? Colors.grey : Colors.grey[700],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Text(
                  mission.description,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RequirementChip(
                      icon: Icons.shield,
                      label: "SHD",
                      value: "${mission.minShieldLevel}",
                      active: isDoable,
                      failed: shieldFail,
                    ),
                    _RequirementChip(
                      icon: Icons.inventory_2,
                      label: "CRG",
                      value: "${mission.minCargo}",
                      active: isDoable,
                      failed: cargoFail,
                    ),
                    _RequirementChip(
                      icon: Icons.local_gas_station,
                      label: "RNG",
                      value: "${mission.distanceAU.toStringAsFixed(2)} AU",
                      active: isDoable,
                      failed: fuelFail,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isDoable ? () => _selectShipForMission(context) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange[900],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white10,
                      disabledForegroundColor: Colors.grey[700],
                    ),
                    child: Text(isDoable ? "ASSIGN SHIP & LAUNCH" : "FLEET BUSY / INCAPABLE"),
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
        // "COMPATIBLE SHIPS" should actually be filtered by class
        final ships = state.fleet
            .where((s) => s.shipClass == mission.requiredClass)
            .toList();

        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mission.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "Class: ${mission.requiredClass} | Distance: ${mission.distanceAU.toStringAsFixed(2)} AU",
                style: const TextStyle(color: Colors.grey),
              ),
              const Divider(height: 32),
              const Text(
                "COMPATIBLE SHIPS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ships.isEmpty
                    ? const Center(
                  child: Text(
                    "No ships of this class in your fleet.",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  itemCount: ships.length,
                  itemBuilder: (context, index) {
                    final ship = ships[index];
                    final String? error = mission.getMissingRequirement(ship);
                    final bool isBusy = _isShipBusy(ship);

                    final canLaunch = error == null && !isBusy;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: canLaunch,
                      leading: Icon(
                        Icons.rocket_launch,
                        color: canLaunch ? Colors.deepOrange : Colors.grey[800],
                      ),
                      title: Text(
                        ship.nickname,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        error ?? (isBusy ? "System Busy" : "Flight Ready"),
                        style: TextStyle(
                          color: canLaunch ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                      trailing: canLaunch
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
                          : const Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: Colors.grey,
                      ),
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
  final bool active;
  final bool failed;

  const _RequirementChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
    this.failed = false,
  });

  @override
  Widget build(BuildContext context) {
    Color iconColor = active ? Colors.orangeAccent : Colors.grey;
    Color? textColor = active ? null : Colors.grey;

    if (failed) {
      iconColor = Colors.redAccent;
      textColor = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: failed ? Border.all(color: Colors.redAccent.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
              Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
