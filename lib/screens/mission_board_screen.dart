import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/mission_model.dart';
import '../models/ship_model.dart';
import '../utils/game_formulas.dart'; // Import for range calc
import 'dart:math';
import 'dart:async';

class MissionBoardScreen extends StatefulWidget {
  const MissionBoardScreen({super.key});

  @override
  State<MissionBoardScreen> createState() => _MissionBoardScreenState();
}

class _MissionBoardScreenState extends State<MissionBoardScreen> {
  Timer? _refreshTimer;
  String _timeUntilRefresh = "--:--";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<GameState>(context, listen: false);
      if (state.availableMissions.isEmpty) {
        state.generateNewMissions();
      }
      _startTimer(state);
    });
  }

  void _startTimer(GameState state) {
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.nextMissionRefresh != null) {
        final remaining = state.nextMissionRefresh!.difference(DateTime.now());
        if (remaining.isNegative) {
          // It should have refreshed by game loop, but if not:
          setState(() => _timeUntilRefresh = "Refreshing...");
        } else {
          final hours = remaining.inHours.toString().padLeft(2, '0');
          final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
          final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
          setState(() {
            _timeUntilRefresh = "$hours:$minutes:$seconds";
          });
        }
      } else {
         setState(() => _timeUntilRefresh = "--:--");
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Returns true if any ship meets requirements AND is not busy
  bool _canAnyShipDoMissionNow(GameState state, Mission mission) {
    for (var ship in state.fleet) {
      bool isBusy = ship.missionEndTime != null || ship.busyUntil != null;
      if (!isBusy && mission.getMissingRequirement(ship) == null) {
        return true;
      }
    }
    return false;
  }

  int _estimateMissionValue(Mission mission) {
    int val = mission.rewardSolars;
    if (mission.rewardResource != null) {
      int price = 0;
      switch(mission.rewardResource) {
        case 'Ore': price = 10; break;
        case 'Gas': price = 25; break;
        case 'Crystals': price = 100; break;
      }
      val += (mission.rewardResourceAmount * price);
    }
    return val;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
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
                Text("${state.availableMissions.length} ACTIVE CONTRACTS", 
                  style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Icon(Icons.timer, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(_timeUntilRefresh,
                      style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'Courier')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: shipClasses.map((className) {
                final classMissions = state.availableMissions.where((m) => m.requiredClass == className).toList();
                
                classMissions.sort((a, b) {
                  bool aDoable = _canAnyShipDoMissionNow(state, a);
                  bool bDoable = _canAnyShipDoMissionNow(state, b);
                  
                  if (aDoable && !bDoable) return -1; 
                  if (!aDoable && bDoable) return 1;

                  int valA = _estimateMissionValue(a);
                  int valB = _estimateMissionValue(b);
                  return valB.compareTo(valA);
                });

                if (classMissions.isEmpty) {
                  return const Center(child: Text("No contracts available for this class.", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: classMissions.length,
                  itemBuilder: (context, index) {
                    final mission = classMissions[index];
                    final bool isDoable = _canAnyShipDoMissionNow(state, mission);
                    
                    // Fleet Stats Analysis for red highlighting
                    int maxShield = 0;
                    int maxCargo = 0;
                    double maxRange = 0.0;
                    
                    for (var s in state.fleet.where((s) => s.shipClass == mission.requiredClass)) {
                       maxShield = max(maxShield, s.shieldLevel);
                       maxCargo = max(maxCargo, s.cargoCapacity);
                       
                       double effRange = GameFormulas.getEffectiveRange(s.fuelCapacity, s.aiLevel);
                       maxRange = max(maxRange, effRange);
                    }
                    
                    bool shieldFail = maxShield < mission.minShieldLevel;
                    bool cargoFail = maxCargo < mission.minCargo;
                    
                    // Check if fleet Max Range is less than Required Range for this mission
                    int requiredRange = GameFormulas.getRangeRequired(mission.distanceAU);
                    bool rangeFail = maxRange < requiredRange;
                    
                    if (!state.fleet.any((s) => s.shipClass == mission.requiredClass)) {
                       shieldFail = true; cargoFail = true; rangeFail = true;
                    }

                    return MissionCard(
                      mission: mission, 
                      isDoable: isDoable,
                      shieldFail: shieldFail,
                      cargoFail: cargoFail,
                      rangeFail: rangeFail,
                      requiredRange: requiredRange,
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
  final bool rangeFail;
  final int requiredRange;

  const MissionCard({
    super.key, 
    required this.mission, 
    required this.isDoable,
    this.shieldFail = false,
    this.cargoFail = false,
    this.rangeFail = false,
    this.requiredRange = 0,
  });

  @override
  Widget build(BuildContext context) {
    final Color mainColor = isDoable ? Colors.deepOrange : Colors.grey;
    final Color textColor = isDoable ? Colors.white : Colors.grey;
    
    String rewardStr = "⁂ ${mission.rewardSolars}";
    if (mission.rewardResource != null && mission.rewardResourceAmount > 0) {
      if (mission.rewardSolars > 0) rewardStr += " + ";
      else rewardStr = "";
      rewardStr += "${mission.rewardResourceAmount} ${mission.rewardResource}";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDoable ? BorderSide.none : BorderSide(color: Colors.grey.withOpacity(0.2)),
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
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)
        ),
        subtitle: Text(
          "${mission.distanceAU.toStringAsFixed(2)} AU | $rewardStr",
          style: TextStyle(fontSize: 11, color: isDoable ? Colors.grey : Colors.grey[700]),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Text(mission.description, style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: textColor)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RequirementChip(
                      icon: Icons.shield, 
                      label: "SHD", 
                      value: "${mission.minShieldLevel}", 
                      active: isDoable,
                      failed: shieldFail
                    ),
                    _RequirementChip(
                      icon: Icons.inventory_2, 
                      label: "CRG", 
                      value: "${mission.minCargo}", 
                      active: isDoable,
                      failed: cargoFail
                    ),
                    _RequirementChip(
                      icon: Icons.local_gas_station,
                      label: "FUEL REQ", 
                      value: "$requiredRange", 
                      active: isDoable,
                      failed: rangeFail
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

    final compatibleClassShips = state.fleet.where((s) => s.shipClass == mission.requiredClass).toList();

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
              Text("COMPATIBLE ${mission.requiredClass.toUpperCase()} SHIPS", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: compatibleClassShips.length,
                  itemBuilder: (context, index) {
                    final ship = compatibleClassShips[index];
                    final String? error = mission.getMissingRequirement(ship);
                    final bool isBusy = ship.missionEndTime != null || ship.busyUntil != null;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: error == null && !isBusy,
                      leading: Icon(Icons.rocket_launch,
                          color: error == null && !isBusy ? Colors.deepOrange : Colors.grey[800]),
                      title: Text("${ship.isMaxed ? '[Elite] ' : ''}${ship.nickname}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(error ?? (isBusy ? "System Busy" : "Flight Ready"),
                        style: TextStyle(color: error == null && !isBusy ? Colors.greenAccent : Colors.redAccent, fontSize: 12)),
                      trailing: (error == null && !isBusy)
                          ? ElevatedButton(
                        onPressed: () {
                          state.startMission(ship.id, mission);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("${ship.isMaxed ? '[Elite] ' : ''}${ship.nickname} is away.")),
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
      iconColor = Colors.deepOrange; // Updated to Orange
      textColor = Colors.deepOrange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: failed ? Border.all(color: Colors.deepOrange.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
              Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
