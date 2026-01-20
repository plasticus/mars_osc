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

    return state.missionLogs.isEmpty
        ? const Center(child: Text("No logs recorded yet."))
        : ListView.builder(
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
          );
  }
}
