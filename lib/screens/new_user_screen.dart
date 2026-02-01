import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';

class NewUserScreen extends StatelessWidget {
  const NewUserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.rocket_launch, color: Colors.deepOrange, size: 80),
              const SizedBox(height: 20),
              const Text("MARS ORBITAL SHIPPING CO.",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const Divider(color: Colors.white24, height: 40),

              if (state.initError != null) ...[
                // ERROR VIEW
                Text(state.initError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => state.initializeUserSession(state.currentUser!.uid),
                  child: const Text("RETRY CONNECTION"),
                ),
              ] else ...[
                // WELCOME VIEW
                const Text("WELCOME, DIRECTOR", style: TextStyle(color: Colors.orangeAccent)),
                const SizedBox(height: 30),
                const Text(
                  "You have been granted ⁂50,000 Solars to establish a new shipping outfit in Martian orbit.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                const Text("YOUR ASSIGNED DESIGNATION:", style: TextStyle(color: Colors.grey, fontSize: 10)),
                Text(state.companyName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                  onPressed: () {
                    // This is where we officially "create" them in the cloud
                    state.setInitialCompanyName(state.companyName);
                  },
                  child: const Text("BEGIN OPERATIONS", style: TextStyle(color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
