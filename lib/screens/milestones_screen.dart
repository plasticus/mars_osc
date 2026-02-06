import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../models/milestone_model.dart';

class MilestonesScreen extends StatelessWidget {
  const MilestonesScreen({super.key});

  void _showSeedConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Registry?"),
        content: const Text("This will re-initialize all milestones with current goals. Existing winners will be cleared!"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              _seedMilestones();
              Navigator.pop(context);
            },
            child: const Text("SEED", style: TextStyle(color: Colors.orangeAccent))
          ),
        ],
      ),
    );
  }

  Future<void> _seedMilestones() async {
    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance.collection('milestones');

    final List<Map<String, dynamic>> roster = [
      // Core Progress
      {'id': 'rename_company', 'title': 'Corporate Identity', 'description': 'First company to rename themselves', 'iconName': 'badge', 'goalValue': 1},
      {'id': 'solars_10m', 'title': 'Deca-Millionaire', 'description': 'First company worth 10M Solars', 'iconName': 'monetization_on', 'goalValue': 10000000},
      {'id': 'solars_50m', 'title': 'Centurion Club', 'description': 'First company worth 50M Solars', 'iconName': 'account_balance', 'goalValue': 50000000},

      // Logistics & Distance
      {'id': 'contracts_1000', 'title': 'Logistics Legend', 'description': 'First company to complete 1000 contracts', 'iconName': 'local_shipping', 'goalValue': 1000},
      {'id': 'dist_30au', 'title': 'Long Haul Hero', 'description': 'First company to complete a contract over 30 AU', 'iconName': 'explore', 'goalValue': 30},

      // Resource Milestones (Updated to 50k)
      {'id': 'ore_50000', 'title': 'Mineral Mogul', 'description': 'First company to mine 50,000 m3 of Ore', 'iconName': 'layers', 'goalValue': 50000},
      {'id': 'gas_50000', 'title': 'Atmospheric Tycoon', 'description': 'First company to harvest 50,000 m3 of Gas', 'iconName': 'air', 'goalValue': 50000},
      {'id': 'crystals_50000', 'title': 'Resonance King', 'description': 'First company to harvest 50,000 m3 of Crystals', 'iconName': 'diamond', 'goalValue': 50000},

      // Tier 5 Specialist Classes
      {'id': 'tier5_mule', 'title': 'Heavy Hauler Expert', 'description': 'First company to have a Tier 5 Mule', 'iconName': 'anchor', 'goalValue': 5},
      {'id': 'tier5_sprinter', 'title': 'Void Racer', 'description': 'First company to have a Tier 5 Sprinter', 'iconName': 'bolt', 'goalValue': 5},
      {'id': 'tier5_miner', 'title': 'Core Stripper', 'description': 'First company to have a Tier 5 Miner', 'iconName': 'precision_manufacturing', 'goalValue': 5},
      {'id': 'tier5_tanker', 'title': 'Gas Giant', 'description': 'First company to have a Tier 5 Tanker', 'iconName': 'ev_station', 'goalValue': 5},
      {'id': 'tier5_harvester', 'title': 'Rift Walker', 'description': 'First company to have a Tier 5 Harvester', 'iconName': 'auto_awesome', 'goalValue': 5},

      // End Game
      {'id': 'all_tier5', 'title': 'Fleet Master', 'description': 'First company to have a Tier 5 ship of every class', 'iconName': 'groups', 'goalValue': 5},
      {'id': 'max_base', 'title': 'Command Center', 'description': 'First company to Max out base upgrades', 'iconName': 'castle', 'goalValue': 5},
    ];

    for (var m in roster) {
      final docRef = collection.doc(m['id']);
      batch.set(docRef, {
        'title': m['title'],
        'description': m['description'],
        'iconName': m['iconName'],
        'goalValue': m['goalValue'], // Server now knows the target
        'winnerName': null,
        'wonAt': null,
      });
    }

    await batch.commit();
    debugPrint("🚀 REGISTRY: Seeding complete.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () => _showSeedConfirmation(context), // The "Magic" trigger
          child: const Text(
            "CORPORATE MILESTONES",
            style: TextStyle(letterSpacing: 1.5, fontSize: 16),
          ),
        ),
        backgroundColor: Colors.black45,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMilestoneStream()),
        ],
      ),
    );
  }

  Widget _buildMilestoneStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('milestones')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final milestones = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Milestone(
            id: doc.id,
            title: data['title'] ?? 'Unknown',
            description: data['description'] ?? '',
            icon: Milestone.getIconFromString(data['iconName']), // Now works!
            winnerName: data['winnerName'],
            wonAt: (data['wonAt'] as Timestamp?)?.toDate(),
          );
        }).toList();

        if (milestones.isEmpty) {
          return const Center(child: Text("Registry empty. Long-press title to seed.", style: TextStyle(color: Colors.grey)));
        }

        return ListView.separated(
          itemCount: milestones.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
          itemBuilder: (context, index) {
            return _MilestoneTile(milestone: milestones[index], isEven: index % 2 == 0);
          },
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blueGrey.withValues(alpha: 0.1),
      child: const Row(
        children: [
          Icon(Icons.emoji_events, color: Colors.amberAccent, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Public record of historical firsts achieved by registered shipping companies.",
              style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

// Ensure this class is included at the bottom of the same file
class _MilestoneTile extends StatelessWidget {
  final Milestone milestone;
  final bool isEven;

  const _MilestoneTile({required this.milestone, required this.isEven});

  @override
  Widget build(BuildContext context) {
    final bool claimed = milestone.isClaimed;
    final Color textColor = claimed ? Colors.white : Colors.white38;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isEven ? Colors.transparent : Colors.white.withValues(alpha: 0.02),
      child: Row(
        children: [
          Icon(
            milestone.icon,
            size: 28,
            color: claimed ? Colors.greenAccent : Colors.blueGrey[400],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.title.toUpperCase(),
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  milestone.description,
                  style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                claimed ? (milestone.winnerName ?? "ERROR").toUpperCase() : "UNCLAIMED",
                style: TextStyle(
                  color: claimed ? Colors.orangeAccent : Colors.grey[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (claimed && milestone.wonAt != null)
                Text(
                  "${milestone.wonAt!.year}-${milestone.wonAt!.month.toString().padLeft(2, '0')}-${milestone.wonAt!.day.toString().padLeft(2, '0')}",
                  style: TextStyle(color: Colors.grey[700], fontSize: 9),
                ),
            ],
          ),
        ],
      ),
    );
  }
}