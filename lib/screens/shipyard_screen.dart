import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/ship_model.dart';

class ShipyardScreen extends StatelessWidget {
  const ShipyardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();

    return Scaffold(
      appBar: AppBar(title: const Text("Deimos Shipyard")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buyCard(context, state, "Mule Mk II", "Mule", 2500, 20, 3, 2),
          _buyCard(context, state, "Void Runner", "Sprinter", 5000, 5, 5, 4),
          _buyCard(context, state, "Asteroid Hauler", "Tanker", 12000, 10, 15, 6),
        ],
      ),
    );
  }

  Widget _buyCard(BuildContext context, GameState state, String name, String sClass, int cost, int cargo, int fuel, int speed) {
    bool canAfford = state.solars >= cost;

    return Card(
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Class: $sClass | Cargo: $cargo | Fuel: $fuel | Speed: $speed"),
        trailing: ElevatedButton(
          onPressed: canAfford ? () {
            final newShip = Ship(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              nickname: "New $name",
              modelName: name,
              shipClass: sClass,
              speed: speed,
              cargoCapacity: cargo,
              fuelCapacity: fuel,
              shieldLevel: 1,
              aiLevel: 1,
            );
            state.buyShip(newShip, cost);
            Navigator.pop(context);
          } : null,
          child: Text("⁂$cost"),
        ),
      ),
    );
  }
}
