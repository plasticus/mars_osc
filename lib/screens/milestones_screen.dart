import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/milestone_model.dart';
// Import your service here once integrated

class MilestonesScreen extends StatelessWidget {
  const MilestonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Eventually, you'll fetch this list from your MilestoneService/Backend
    final List<Milestone> milestones = []; // Placeholder for your data

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("CORPORATE MILESTONES", style: TextStyle(letterSpacing: 1.5, fontSize: 16)),
        backgroundColor: Colors.black45,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: milestones.isEmpty
              ? const Center(child: Text("Connecting to Galactic Registry...", style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  itemCount: milestones.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final m = milestones[index];
                    return _MilestoneTile(milestone: m, isEven: index % 2 == 0);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blueGrey.withOpacity(0.1),
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
      color: isEven ? Colors.transparent : Colors.white.withOpacity(0.02),
      child: Row(
        children: [
          // STATUS ICON
          Icon(
            claimed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: claimed ? Colors.greenAccent : Colors.grey[800],
          ),
          const SizedBox(width: 16),

          // TEXT CONTENT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.title.toUpperCase(),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  milestone.description,
                  style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11),
                ),
              ],
            ),
          ),

          // WINNER DISPLAY
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                claimed ? milestone.winnerName!.toUpperCase() : "UNCLAIMED",
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