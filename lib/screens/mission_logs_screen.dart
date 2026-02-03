import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class MissionLogsScreen extends StatefulWidget {
  const MissionLogsScreen({super.key});

  @override
  State<MissionLogsScreen> createState() => _MissionLogsScreenState();
}

class _MissionLogsScreenState extends State<MissionLogsScreen> {
  String _versionLine = "…";

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();

    // pubspec version is like "0.9.4+12"
    // info.version => "0.9.4"
    // info.buildNumber => "12"
    final mode = kReleaseMode ? "RELEASE" : "DEBUG";

    if (!mounted) return;
    setState(() {
      _versionLine = "v${info.version}+${info.buildNumber} • $mode";
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final logs = state.missionLogs;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Operation Logs"),
            Text(
              _versionLine,
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
      ),
      body: logs.isEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Center(
                  child: Text(
                    "No mission data on record.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                _buildHiddenResetButton(context, state),
              ],
            )
          : ListView.builder(
              itemCount: logs.length + 1,
              itemBuilder: (context, index) {
                if (index == logs.length) {
                  return _buildHiddenResetButton(context, state);
                }
                final log = logs[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.black26,
                  child: ListTile(
                    leading: _getLogLeadingIcon(log),
                    title: Text(
                      log.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "${log.details}\n${log.timestamp.toString().split('.')[0]}",
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: log.solarChange != null
                        ? Text(
                            "${log.solarChange! >= 0 ? '+' : ''}${log.solarChange}",
                            style: TextStyle(
                              color: log.isPositive
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
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

  Widget _buildDebugButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.7)),
        borderRadius: BorderRadius.circular(6),
        color: Colors.cyanAccent.withOpacity(0.10),
      ),
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _getLogLeadingIcon(LogEntry entry) {
    // Define mapping for titles to specific icons
    if (entry.title.contains("ELITE")) {
      return const Icon(Icons.shield_moon, color: Colors.cyanAccent, size: 24);
    } else if (entry.title.contains("Base Upgraded")) {
      return const Icon(Icons.architecture,
          color: Colors.orangeAccent, size: 24);
    } else if (entry.title.contains("Mission Launched")) {
      return const Icon(Icons.rocket_launch,
          color: Colors.blueAccent, size: 24);
    } else if (entry.title.contains("Mission Return")) {
      return const Icon(Icons.assignment_turned_in,
          color: Colors.greenAccent, size: 24);
    } else if (entry.title.contains("Trade") || entry.title.contains("Market")) {
      return const Icon(Icons.currency_exchange,
          color: Colors.amberAccent, size: 24);
    } else if (entry.title.contains("Repair")) {
      return const Icon(Icons.build, color: Colors.lightBlueAccent, size: 24);
    }

    // Fallback
    return Icon(
      entry.isPositive ? Icons.check_circle : Icons.warning,
      color: entry.isPositive ? Colors.green : Colors.orange,
      size: 24,
    );
  }

  Widget _buildHiddenResetButton(BuildContext context, GameState state) {
    if (!enableDebugButtons) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 80),
      child: Center(
        child: Column(
          children: [
            // Purge Button (now debug-gated too)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
                borderRadius: BorderRadius.circular(6),
                color: Colors.redAccent.withOpacity(0.10),
              ),
              child: TextButton(
                onPressed: () => _showResetDialog(context, state),
                child: const Text(
                  "SYSTEM_PURGE_PROTOCOL_v1.0.6",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // DEBUG: Contracts Reset
            _buildDebugButton(
              label: "DEBUG: Contracts Reset",
              onPressed: () {
                state.generateNewMissions();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("DEBUG: Contract Board Replenished"),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // DEBUG: +1,000,000 SOLARS
            _buildDebugButton(
              label: "DEBUG: +⁂ 1,000,000",
              onPressed: () {
                state.solars += 1000000;
                state.notifyListeners();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✻ DEBUG: +⁂ 1,000,000"),
                  ),
                );
              },
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
          "Your fleet, company name, and credits will be purged from the galaxy.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              await state.nuclearReset();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Data Purged. Fly safe, Commander.")),
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