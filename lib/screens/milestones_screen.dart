import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // REQUIRED
import '../models/milestone_model.dart';
import '../services/milestone_service.dart';

class MilestonesScreen extends StatelessWidget {
  const MilestonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "CORPORATE MILESTONES",
          style: TextStyle(letterSpacing: 1.5, fontSize: 16),
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