import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/game_state.dart';
import 'mission_logs_screen.dart';

class CorporateHubScreen extends StatelessWidget {
  const CorporateHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildHubTile(
            context,
            "CORPORATE PROFILE",
            "View assets and rebrand branch",
            Icons.business_center,
            Colors.blueGrey,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CorporateInfoView())),
          ),
          const SizedBox(height: 16),
          _buildHubTile(
            context,
            "GALACTIC LEADERBOARD",
            "Real-time corporate rankings",
            Icons.leaderboard,
            Colors.amber,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardView())),
          ),
          const SizedBox(height: 16),
          _buildHubTile(
            context,
            "OPERATION LOGS",
            "Historical mission data",
            Icons.history,
            Colors.deepOrange,
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MissionLogsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildHubTile(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

// --- SUB-VIEW: CORPORATE INFO ---
class CorporateInfoView extends StatelessWidget {
  const CorporateInfoView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();

    // Net Worth = Solars + Total Ship Sale Value
    int fleetValue = state.fleet.fold(0, (sum, ship) => sum + state.getShipSaleValue(ship));
    int netWorth = state.solars + fleetValue;

    return Scaffold(
      appBar: AppBar(title: const Text("Corporate Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("BRANCH DESIGNATION", style: TextStyle(color: Colors.grey, fontSize: 12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(state.companyName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepOrange))),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: state.solars >= 1000000 ? () => _showRenameDialog(context, state) : null,
                ),
              ],
            ),
            if (state.solars < 1000000)
              const Text("⁂ 1,000,000 required to rebrand", style: TextStyle(color: Colors.redAccent, fontSize: 10)),

            const SizedBox(height: 32),
            _buildDataPoint("Solars on Hand", "⁂ ${state.solars}", Icons.account_balance_wallet),
            const SizedBox(height: 16),
            _buildDataPoint("Fleet Appraisal", "⁂ $fleetValue", Icons.rocket_launch),
            const SizedBox(height: 16),
            _buildDataPoint("Facility Investment", "⁂ ${state.calculateBaseUpgradeInvestment()}", Icons.engineering), // Use a comma here!
            const Divider(height: 40, color: Colors.white10),
            _buildDataPoint("TOTAL NET WORTH", "⁂ $netWorth", Icons.trending_up, highlight: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDataPoint(String label, String value, IconData icon, {bool highlight = false}) {
    return Row(
      children: [
        Icon(icon, color: highlight ? Colors.orangeAccent : Colors.grey, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: highlight ? FontWeight.bold : FontWeight.normal, color: highlight ? Colors.orangeAccent : Colors.white)),
          ],
        ),
      ],
    );
  }

  void _showRenameDialog(BuildContext context, GameState state) {
    final controller = TextEditingController(text: state.companyName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rebrand Branch"),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: "New Name")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              state.solars -= 1000000;
              state.setInitialCompanyName(controller.text); // Updates name and syncs to cloud
              Navigator.pop(context);
            },
            child: const Text("PAY ⁂ 1M"),
          ),
        ],
      ),
    );
  }
}

// --- SUB-VIEW: LEADERBOARD ---
class LeaderboardView extends StatefulWidget {
  const LeaderboardView({super.key});

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> {
  String _activeCategory = 'cashOnHand'; // Default Category 1
  final Map<String, String> _titles = {
    'cashOnHand': 'Cash On Hand',
    'netWorth': 'Corporate Value',
    'topShipValue': 'Most Valuable Ship',
    'totalDeliveries': 'Total Deliveries',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Galactic Rankings"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _titles.keys.map((key) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Text(_titles[key]!),
                  selected: _activeCategory == key,
                  onSelected: (bool selected) {
                    if (selected) setState(() => _activeCategory = key);
                  },
                ),
              )).toList(),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leaderboard')
            .orderBy(_activeCategory, descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: Text("#${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                title: Text(data['companyName'] ?? "Unknown"),
                subtitle: _activeCategory == 'topShipValue'
                    ? Text("${data['topShipNickname']} (${data['topShipClass']})")
                    : null,
                trailing: Text(_getTrailingText(data),
                    style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
              );
            },
          );
        },
      ),
    );
  }

  String _getTrailingText(Map<String, dynamic> data) {
    if (_activeCategory == 'totalDeliveries') return "${data['totalDeliveries'] ?? 0} runs";
    return "⁂ ${data[_activeCategory] ?? 0}";
  }
}