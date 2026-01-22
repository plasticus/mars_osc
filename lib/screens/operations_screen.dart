import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/ship_model.dart';

class OperationsScreen extends StatelessWidget {
  const OperationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    int currentStorage = state.ore + state.gas + state.crystals;
    
    // Sort fleet by Value (Ascending)
    List<Ship> sortedFleet = List.from(state.fleet);
    sortedFleet.sort((a, b) => state.getShipSaleValue(a).compareTo(state.getShipSaleValue(b)));

    // Calculate current AI Bonus
    int bonusPercent = 100 + (state.tradeDepotLevel * 5);

    return Column(
      children: [
        // Resource Inventory Header
        if (currentStorage > 0)
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("INVENTORY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text("$currentStorage / ${state.maxStorage} m³", 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: currentStorage >= state.maxStorage ? Colors.redAccent : Colors.grey
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (state.ore > 0) _ResourceChip(icon: Icons.landscape, label: "Ore", value: state.ore, color: Colors.brown),
                      if (state.gas > 0) _ResourceChip(icon: Icons.cloud, label: "Gas", value: state.gas, color: Colors.cyan),
                      if (state.crystals > 0) _ResourceChip(icon: Icons.diamond, label: "Crystals", value: state.crystals, color: Colors.purpleAccent),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (currentStorage / state.maxStorage).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[800],
                    color: currentStorage >= state.maxStorage ? Colors.red : Colors.blueGrey,
                    minHeight: 4,
                  ),
                  const SizedBox(height: 16),
                  
                  // Sell Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          "Wait for AI Auto-Sell to earn $bonusPercent% market value.",
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => state.manualSellAll(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text("SELL NOW (100%)", style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Fleet List
        Expanded(
          child: sortedFleet.isEmpty
              ? const Center(child: Text("No ships in fleet. Visit the Shipyard!"))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: sortedFleet.length,
                  itemBuilder: (context, index) {
                    final ship = sortedFleet[index];
                    return ShipSummaryCard(ship: ship);
                  },
                ),
        ),
        
        // DEBUG / BETA BUTTON
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => state.debugCompleteAllMissions(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text("BETA: COMPLETE ALL"),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResourceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _ResourceChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text("$value m³", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.black26,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class ShipSummaryCard extends StatelessWidget {
  final Ship ship;
  const ShipSummaryCard({super.key, required this.ship});

  @override
  Widget build(BuildContext context) {
    String displayName = ship.nickname;
    if (ship.isMaxed) {
      displayName = "[Elite] $displayName";
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          ListTile(
            onTap: () => _showShipDetails(context, ship),
            title: Text(displayName, style: TextStyle(fontWeight: FontWeight.bold, color: ship.isMaxed ? Colors.amberAccent : null)),
            subtitle: Text("${ship.modelName} (${ship.shipClass})"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatusText(ship),
                const SizedBox(height: 4),
                SizedBox(
                  width: 60,
                  child: LinearProgressIndicator(
                    value: ship.condition,
                    backgroundColor: Colors.grey[800],
                    color: ship.condition > 0.5 ? Colors.green : (ship.condition > 0.2 ? Colors.orange : Colors.red),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          if (ship.missionEndTime != null) _buildMissionProgress(ship),
        ],
      ),
    );
  }

  Widget _buildMissionProgress(Ship ship) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final now = DateTime.now();
        
        // Safety check: if missionEndTime is null (completed), return empty
        if (ship.missionEndTime == null) return const SizedBox.shrink();

        // If completed but not yet processed by GameState loop
        if (now.isAfter(ship.missionEndTime!)) {
           return const SizedBox(height: 4, child: LinearProgressIndicator(color: Colors.greenAccent));
        }

        final totalDuration = ship.missionEndTime!.difference(ship.missionStartTime!);
        final elapsed = now.difference(ship.missionStartTime!);
        double progress = elapsed.inSeconds / totalDuration.inSeconds;

        final remaining = ship.missionEndTime!.difference(now);
        final timeStr = "${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}";

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("MISSION PROGRESS", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(timeStr, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.purpleAccent)),
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
          ),
        );
      },
    );
  }

  Widget _buildStatusText(Ship ship) {
    if (ship.missionEndTime != null) {
      return const Text("ON MISSION", style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold));
    }
    if (ship.busyUntil != null) {
      // Explicitly check for busy status (repairing/upgrading)
      return Text(ship.currentTask!.toUpperCase(), style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold));
    }
    if (ship.condition < 0.3) {
      return const Text("CRITICAL", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold));
    }
    return const Text("READY", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold));
  }

  void _showShipDetails(BuildContext context, Ship ship) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ShipDetailSheet(ship: ship),
    );
  }
}

class ShipDetailSheet extends StatefulWidget {
  final Ship ship;
  const ShipDetailSheet({super.key, required this.ship});

  @override
  State<ShipDetailSheet> createState() => _ShipDetailSheetState();
}

class _ShipDetailSheetState extends State<ShipDetailSheet> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ship.nickname);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final ship = state.fleet.firstWhere((s) => s.id == widget.ship.id, orElse: () => widget.ship);
    final isSelling = ship.missionEndTime != null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Ship Nickname",
                    border: InputBorder.none,
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  onSubmitted: (value) => state.renameShip(ship.id, value),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                onPressed: () => state.renameShip(ship.id, _nameController.text),
              ),
            ],
          ),
          Text("${ship.modelName} - ${ship.shipClass} Class", style: TextStyle(color: Colors.grey[400])),
          const Divider(height: 32),
          
          const Text("SYSTEM STATS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DetailStat(label: "Speed", value: ship.speed, icon: Icons.speed),
              _DetailStat(label: "Cargo", value: ship.cargoCapacity, icon: Icons.inventory_2),
              _DetailStat(label: "Fuel", value: ship.fuelCapacity, icon: Icons.local_gas_station),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DetailStat(label: "Shields", value: ship.shieldLevel, icon: Icons.shield),
              _DetailStat(label: "AI Core", value: ship.aiLevel, icon: Icons.psychology),
              _DetailStat(label: "Condition", value: "${(ship.condition * 100).toInt()}%", icon: Icons.handyman),
            ],
          ),
          
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ESTIMATED VALUE", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text("⁂ ${state.getShipSaleValue(ship)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                ],
              ),
              ElevatedButton(
                onPressed: isSelling ? null : () {
                  _confirmDecommission(context, state, ship);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[900],
                  foregroundColor: Colors.white,
                ),
                child: const Text("DECOMMISSION"),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _confirmDecommission(BuildContext context, GameState state, Ship ship) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Decommission"),
        content: Text("Are you sure you want to sell ${ship.nickname}? You will receive ⁂ ${state.getShipSaleValue(ship)}."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              state.sellShip(ship.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close sheet
            },
            child: const Text("SELL", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final dynamic value;
  final IconData icon;

  const _DetailStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(height: 4),
        Text("$value", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
