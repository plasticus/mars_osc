import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';

class MissionLogsScreen extends StatelessWidget {
  const MissionLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final logs = state.missionLogs;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Operation Logs"),
            Text("v0.9.4-BETA", style: TextStyle(fontSize: 10, color: Colors.white54)),
          ],
        ),
      ),
      body: logs.isEmpty
          ? Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Center(
              child: Text("No mission data on record.",
                  style: TextStyle(color: Colors.grey)
              )
          ),
          // Still allow reset if logs are empty (for troubleshooting)
          _buildHiddenResetButton(context, state),
        ],
      )
          : ListView.builder(
        // +1 creates the extra slot at the bottom for the reset button
        itemCount: logs.length + 1,
        itemBuilder: (context, index) {
          // Check if we are at the end of the list
          if (index == logs.length) {
            return _buildHiddenResetButton(context, state);
          }

          final log = logs[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.black26,
            child: ListTile(
              leading: _getLogLeadingIcon(log),
              title: Text(log.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)
              ),
              subtitle: Text(
                "${log.details}\n${log.timestamp.toString().split('.')[0]}",
                style: const TextStyle(fontSize: 12),
              ),
              trailing: log.solarChange != null
                  ? Text(
                "${log.solarChange! >= 0 ? '+' : ''}${log.solarChange}",
                style: TextStyle(
                  color: log.isPositive ? Colors.greenAccent : Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                ),
              )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _getLogLeadingIcon(LogEntry entry) {
    // Define mapping for titles to specific icons
    if (entry.title.contains("ELITE")) {
      return const Icon(Icons.shield_moon, color: Colors.cyanAccent, size: 24);
    } else if (entry.title.contains("Base Upgraded")) {
      return const Icon(Icons.architecture, color: Colors.orangeAccent, size: 24);
    } else if (entry.title.contains("Mission Launched")) {
      return const Icon(Icons.rocket_launch, color: Colors.blueAccent, size: 24);
    } else if (entry.title.contains("Mission Return")) {
      return const Icon(Icons.assignment_turned_in, color: Colors.greenAccent, size: 24);
    } else if (entry.title.contains("Trade") || entry.title.contains("Market")) {
      return const Icon(Icons.currency_exchange, color: Colors.amberAccent, size: 24);
    } else if (entry.title.contains("Repair")) {
      return const Icon(Icons.build, color: Colors.lightBlueAccent, size: 24);
    }

    // Fallback to your existing logic if no title matches
    return Icon(
      entry.isPositive ? Icons.check_circle : Icons.warning,
      color: entry.isPositive ? Colors.green : Colors.orange,
      size: 24,
    );
  }

// Locate the _buildHiddenResetButton method in mission_logs_screen.dart and update it:

  Widget _buildHiddenResetButton(BuildContext context, GameState state) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 80),
      child: Center(
        child: Column(
          children: [
            // Existing Purge Button
            Opacity(
              opacity: 0.8,
              child: Container(
                color: Colors.red.withValues(alpha: 0.2),
                child: TextButton(
                  onPressed: () => _showResetDialog(context, state),
                  child: const Text(
                    "SYSTEM_PURGE_PROTOCOL_v1.0.6",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        letterSpacing: 2
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20), // Spacing between buttons
            // NEW Debug Button
            Opacity(
              opacity: 0.6,
              child: TextButton(
                onPressed: () {
                  state.generateNewMissions(); // Calls your existing 2-hour logic
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("DEBUG: Contract Board Replenished"))
                  );
                },
                child: const Text(
                  "DEBUG: Contracts Reset",
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  void _showResetDialog(BuildContext context, GameState state) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force them to choose
      builder: (context) => AlertDialog(
        title: const Text("NUCLEAR RESET"),
        content: const Text(
            "This will wipe all local and cloud data permanently. "
                "Your fleet, company name, and credits will be purged from the galaxy."
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL")
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
            onPressed: () async {
              await state.nuclearReset();
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Data Purged. Fly safe, Commander."))
                );
              }
            },
            child: const Text("DELETE EVERYTHING"),
          ),
        ],
      ),
    );
  }
}
