import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';

class MissionLogsScreen extends StatelessWidget {
  const MissionLogsScreen({super.key});

  // Manual time formatting helper
  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();

    return Column(
      children: [
        if (state.missionLogs.isEmpty)
          const Expanded(child: Center(child: Text("No logs recorded yet.")))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: state.missionLogs.length,
              itemBuilder: (context, index) {
                final entry = state.missionLogs[index];
                final timeStr = _formatTime(entry.timestamp);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      entry.solarChange != null
                          ? (entry.isPositive ? Icons.add_circle : Icons.remove_circle)
                          : Icons.info_outline,
                      color: entry.solarChange != null
                          ? (entry.isPositive ? Colors.greenAccent : Colors.redAccent)
                          : Colors.blueAccent,
                    ),
                    title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(entry.details),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        if (entry.solarChange != null)
                          Text(
                            "${entry.isPositive ? '+' : '-'} ⁂${entry.solarChange!.abs()}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: entry.isPositive ? Colors.greenAccent : Colors.redAccent,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        
        // DEBUG RESET BUTTON (Hidden at bottom of logs)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Opacity(
            opacity: 0.3, // Faded so it's not distracting
            child: TextButton.icon(
              onPressed: () => _confirmReset(context, state),
              icon: const Icon(Icons.refresh, size: 14, color: Colors.red),
              label: const Text("DEBUG: RESET PROGRESS", style: TextStyle(fontSize: 10, color: Colors.red)),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmReset(BuildContext context, GameState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Emergency Protocol"),
        content: const Text("Warning: This will clear all fleet data, logs, and solar reserves. Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ABORT")),
          TextButton(
            onPressed: () {
              state.resetProgress();
              Navigator.pop(context);
            },
            child: const Text("CONFIRM RESET", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
