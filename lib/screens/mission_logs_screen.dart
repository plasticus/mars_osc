import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Needed for kDebugMode
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/log_entry.dart';

class MissionLogsScreen extends StatelessWidget {
  const MissionLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final logs = state.missionLogs;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Operation Logs", style: TextStyle(letterSpacing: 1.0)),
        backgroundColor: Colors.black45,
        elevation: 0,
      ),
      body: logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.satellite_alt, size: 64, color: Colors.grey.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  const Text("No records found.", style: TextStyle(color: Colors.grey)),
                  // Show debug buttons even if list is empty
                  _buildDebugSection(context, state),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              // +1 for the Debug Footer
              itemCount: logs.length + 1,
              itemBuilder: (context, index) {
                // If it's the last item, render the Debug Section
                if (index == logs.length) {
                  return _buildDebugSection(context, state);
                }
                return _LogCard(log: logs[index]);
              },
            ),
    );
  }

  Widget _buildDebugSection(BuildContext context, GameState state) {
    // SECURITY GATE: Returns an empty box if we are in Release Mode
    if (kReleaseMode) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 80),
      child: Center(
        child: Column(
          children: [
            const Divider(color: Colors.white24),
            const Text("DEVELOPER TOOLS", style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1.5)),
            const SizedBox(height: 20),

            // 1. SIMULATE 15 MINS (Purple)
            _buildDebugButton(
              context,
              label: "🧪 SIMULATE 15m OFFLINE",
              color: Colors.purpleAccent,
              icon: Icons.history_toggle_off,
              onPressed: () {
                state.debugSimulateOfflineTime(15);
                _showSnack(context, "Simulating 15m gap...", Colors.purple);
              },
            ),

            const SizedBox(height: 12),

            // 2. FORCE SAVE (Green)
            _buildDebugButton(
              context,
              label: "DEBUG: 💾 FORCE CLOUD SAVE",
              color: Colors.greenAccent,
              icon: Icons.save,
              onPressed: () {
                state.debugSave();
                _showSnack(context, "State saved to disk.", Colors.green);
              },
            ),

            const SizedBox(height: 12),

            // 3. REPLENISH CONTRACTS (Blue)
            _buildDebugButton(
              context,
              label: "DEBUG: 🔄 REFRESH CONTRACTS",
              color: Colors.blueAccent,
              icon: Icons.refresh,
              onPressed: () {
                state.generateNewMissions();
                _showSnack(context, "Contract board regenerated.", Colors.blue);
              },
            ),

            const SizedBox(height: 12),

            // 4. ADD CASH (Gold)
            _buildDebugButton(
              context,
              label: "DEBUG: 💰 +⁂ 1,000,000",
              color: Colors.amberAccent,
              icon: Icons.attach_money,
              onPressed: () {
                state.solars += 1000000;
                state.forceRefresh();
                _showSnack(context, "Funding secured.", Colors.amber);
              },
            ),

            const SizedBox(height: 30),

            // 5. NUCLEAR OPTION (Red)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
                borderRadius: BorderRadius.circular(6),
                color: Colors.redAccent.withOpacity(0.10),
              ),
              child: TextButton(
                onPressed: () => state.nuclearReset(), // Assuming you have this method
                child: const Text(
                  "DEBUG: ☢️ SYSTEM_PURGE_PROTOCOL",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    letterSpacing: 2,
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

  Widget _buildDebugButton(BuildContext context, {required String label, required Color color, required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 250,
      height: 45,
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(milliseconds: 600)),
    );
  }
}

class _LogCard extends StatelessWidget {
  final LogEntry log;

  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final style = _getLogStyle(log);

    // Split "Contract Completed: Ship Name" into two parts
    String titleText = log.title;
    String? subTitleText;

    if (log.title.contains(":")) {
      final parts = log.title.split(":");
      titleText = parts[0].trim();
      if (parts.length > 1) {
        subTitleText = parts[1].trim();
      }
    }

    // Calculate Efficiency / Yield for Trade Logs
    String? efficiencyText;
        Color efficiencyColor = Colors.lightBlueAccent;

        if (log.title.contains("Trade") || log.title.contains("Offline")) {
          // 5% bonus per level. Level 1 = 105%, Level 5 = 125%
          int bonusPct = 100 + (log.tradeDepotLevel * 5);
          efficiencyText = "$bonusPct% Yield";

          // Color Code based on how good the tech is
          if (log.tradeDepotLevel >= 4) {
            efficiencyColor = Colors.greenAccent; // High Tech
          } else if (log.tradeDepotLevel >= 2) {
            efficiencyColor = Colors.cyanAccent; // Mid Tech
          } else {
            efficiencyColor = Colors.blueGrey; // Basic Tech
          }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // LEFT COLOR STRIP
            Container(width: 4, color: style.color),

            // MAIN CONTENT
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER ROW (Icon + Title + Time)
                    Row(
                      children: [
                        Icon(style.icon, size: 24, color: style.color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            titleText.toUpperCase(),
                            style: TextStyle(
                              color: style.color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(log.timestamp),
                          style: TextStyle(color: Colors.grey[600], fontSize: 10),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // SUBTITLE (Ship Name)
                    if (subTitleText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0, left: 36),
                        child: Text(
                          subTitleText,
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),

                    // CHIPS (Resources Sold)
                    if (log.oreSold > 0 || log.gasSold > 0 || log.crystalsSold > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 6, left: 36),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (log.oreSold > 0) _ResourceChip(icon: Icons.landscape, label: "Ore", value: "-${log.oreSold}", color: Colors.brown),
                            if (log.gasSold > 0) _ResourceChip(icon: Icons.cloud, label: "Gas", value: "-${log.gasSold}", color: Colors.cyan),
                            if (log.crystalsSold > 0) _ResourceChip(icon: Icons.diamond, label: "Crystals", value: "-${log.crystalsSold}", color: Colors.purpleAccent),

                            // Efficiency Tag
                            if (efficiencyText != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(left: 4),
                                decoration: BoxDecoration(
                                  color: efficiencyColor.withValues(alpha:0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: efficiencyColor.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  efficiencyText,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: efficiencyColor),
                                ),
                            ),
                          ],
                        ),
                      ),

                    // DETAILS BODY
                    Padding(
                      padding: const EdgeInsets.only(left: 36),
                      child: _RichSolarText(text: log.details),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  _LogStyle _getLogStyle(LogEntry log) {
    // 1. TRADING (Green)
    if (log.title.contains("Transaction") || log.title.contains("Trade") || log.title.contains("Liquidate") || log.title.contains("Offline")) {
      return _LogStyle(Icons.currency_exchange, Colors.greenAccent);
    }
    // 2. CONTRACTS COMPLETE (Light Blue)
    if (log.title.contains("Completed") || log.title.contains("Return")) {
      return _LogStyle(Icons.assignment_turned_in, Colors.lightBlueAccent);
    }
    // 3. CONTRACTS LAUNCH (Deep Orange)
    if (log.title.contains("Launched") || log.title.contains("Sent")) {
      return _LogStyle(Icons.rocket_launch, Colors.deepOrangeAccent);
    }
    // 4. MAINTENANCE (Teal)
    if (log.title.contains("Repair") || log.title.contains("Maintenance")) {
      if (log.title.contains("Complete")) {
        return _LogStyle(Icons.verified, Colors.tealAccent);
      }
      return _LogStyle(Icons.build_circle, Colors.amber);
    }
    // 5. FLEET / UPGRADES
    if (log.title.contains("Expansion") || log.title.contains("Purchased")) {
      return _LogStyle(Icons.add_shopping_cart, Colors.yellow);
    }
    if (log.title.contains("Upgrade") || log.title.contains("Base")) {
      return _LogStyle(Icons.foundation, Colors.purpleAccent);
    }
    if (log.title.contains("ELITE")) {
      return _LogStyle(Icons.military_tech, Colors.amberAccent);
    }
    if (log.title.contains("Decommissioned")) {
      return _LogStyle(Icons.recycling, Colors.grey);
    }

    return _LogStyle(Icons.info_outline, Colors.grey);
  }
}

class _LogStyle {
  final IconData icon;
  final Color color;
  _LogStyle(this.icon, this.color);
}

class _ResourceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ResourceChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text("$value $label", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _RichSolarText extends StatelessWidget {
  final String text;

  const _RichSolarText({required this.text});

  @override
  Widget build(BuildContext context) {
    List<TextSpan> spans = [];
    final regex = RegExp(r'(⁂)');

    text.splitMapJoin(
      regex,
      onMatch: (m) {
        spans.add(const TextSpan(
          text: "⁂",
          style: TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 14),
        ));
        return "⁂";
      },
      onNonMatch: (n) {
        if (n.isNotEmpty) {
          spans.add(TextSpan(
            text: n,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)
          ));
        }
        return n;
      },
    );

    return RichText(text: TextSpan(children: spans));
  }
}