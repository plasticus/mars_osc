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
      appBar: AppBar(title: const Text("Operation Logs")),
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
              leading: Icon(
                log.isPositive ? Icons.check_circle : Icons.warning,
                color: log.isPositive ? Colors.green : Colors.orange,
              ),
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

  Widget _buildHiddenResetButton(BuildContext context, GameState state) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 60),
      child: Center(
        child: Opacity(
          opacity: 0.15, // Barely visible to keep it a secret
          child: TextButton(
            onPressed: () => _showResetDialog(context, state),
            child: const Text(
              "SYSTEM_PURGE_PROTOCOL_v1.0.6",
              style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  letterSpacing: 2
              ),
            ),
          ),
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