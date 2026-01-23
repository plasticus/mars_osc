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
          ? const Center(child: Text("No mission data on record.", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.black26,
            child: ListTile(
              leading: Icon(
                log.isPositive ? Icons.check_circle : Icons.warning,
                color: log.isPositive ? Colors.green : Colors.orange,
              ),
              title: Text(log.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${log.details}\n${log.timestamp.toString().split('.')[0]}",
                  style: const TextStyle(fontSize: 12)),
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
}