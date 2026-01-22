import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';

class TradeDepotScreen extends StatelessWidget {
  const TradeDepotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("TRADE DEPOT"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _ResourceCard(
              name: "Ore", 
              icon: Icons.landscape, 
              color: Colors.brown, 
              amount: state.ore, 
              price: state.getResourcePrice("Ore"),
              onSell: () => state.sellResource("Ore", state.ore),
            ),
            _ResourceCard(
              name: "Gas", 
              icon: Icons.cloud, 
              color: Colors.cyan, 
              amount: state.gas, 
              price: state.getResourcePrice("Gas"),
              onSell: () => state.sellResource("Gas", state.gas),
            ),
            _ResourceCard(
              name: "Crystals", 
              icon: Icons.diamond, 
              color: Colors.purpleAccent, 
              amount: state.crystals, 
              price: state.getResourcePrice("Crystals"),
              onSell: () => state.sellResource("Crystals", state.crystals),
            ),
            
            const Spacer(),
            const Divider(),
            const Text(
              "Market prices fluctuate based on global demand.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final int amount;
  final int price;
  final VoidCallback onSell;

  const _ResourceCard({
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
    required this.price,
    required this.onSell,
  });

  @override
  Widget build(BuildContext context) {
    int totalValue = amount * price;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("Stock: $amount m³", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text("Current Price: ⁂$price / m³", style: TextStyle(color: color, fontSize: 12)),
                ],
              ),
            ),
            Column(
              children: [
                Text("⁂ $totalValue", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: amount > 0 ? onSell : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[800],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("SELL ALL"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
