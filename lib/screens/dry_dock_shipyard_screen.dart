import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/ship_model.dart';
import '../models/ship_templates.dart';

class DryDockShipyardScreen extends StatelessWidget {
  const DryDockShipyardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final shipClasses = ["Mule", "Sprinter", "Tanker", "Miner", "Harvester"];

    return DefaultTabController(
      length: shipClasses.length,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("SHIPYARD CATALOG"),
              Text("⁂ ${state.solars}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabs: shipClasses.map((c) => Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c),
                  if (!state.isClassUnlocked(c)) 
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Icon(Icons.lock, size: 12, color: Colors.grey),
                    ),
                ],
              ),
            )).toList(),
          ),
        ),
        body: TabBarView(
          children: shipClasses.map((className) {
            final isUnlocked = state.isClassUnlocked(className);
            
            if (!isUnlocked) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text("$className Class Locked", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text("Upgrade the Deep-Space Relay in Engineering", style: TextStyle(color: Colors.grey)),
                    const Text("to unlock this sector of the shipyard.", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            final classShips = ShipTemplate.all.where((s) => s.shipClass == className).toList();
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: classShips.length,
              itemBuilder: (context, index) {
                return ShipTemplateCard(template: classShips[index], state: state);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class ShipTemplateCard extends StatelessWidget {
  final ShipTemplate template;
  final GameState state;

  const ShipTemplateCard({super.key, required this.template, required this.state});

  @override
  Widget build(BuildContext context) {
    bool canAfford = state.solars >= template.price;
    bool hasSpace = state.fleet.length < state.maxFleetSize;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(template.modelName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("⁂ ${template.price}", style: TextStyle(color: canAfford ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatMini(label: "SPD", value: "${template.baseSpeed}/${template.maxSpeed}"),
                _StatMini(label: "CRG", value: "${template.baseCargo}/${template.maxCargo}"),
                _StatMini(label: "FUEL", value: "${template.baseFuel}/${template.maxFuel}"),
                _StatMini(label: "SHD", value: "${template.baseShield}/${template.maxShield}"),
                _StatMini(label: "AI", value: "${template.baseAI}/${template.maxAI}"),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (canAfford && hasSpace) ? () => _buyShip(context) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
                child: Text(hasSpace ? "PURCHASE" : "HANGAR FULL"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _buyShip(BuildContext context) {
    final newShip = Ship(
      id: "ship_${DateTime.now().millisecondsSinceEpoch}",
      nickname: template.modelName,
      modelName: template.modelName,
      shipClass: template.shipClass,
      speed: template.baseSpeed,
      maxSpeed: template.maxSpeed,
      cargoCapacity: template.baseCargo,
      maxCargo: template.maxCargo,
      fuelCapacity: template.baseFuel,
      maxFuel: template.maxFuel,
      shieldLevel: template.baseShield,
      maxShield: template.maxShield,
      aiLevel: template.baseAI,
      maxAI: template.maxAI,
    );

    if (state.buyShip(newShip, template.price)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${template.modelName} added to fleet!")),
      );
      Navigator.pop(context);
    }
  }
}

class _StatMini extends StatelessWidget {
  final String label;
  final String value;
  const _StatMini({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }
}
