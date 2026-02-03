import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // We use context.watch here so the UI rebuilds when GameState updates
    final state = context.watch<GameState>();

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: _buildBody(context, state),
        ),
      ),
    );
  }

// Inside login_screen.dart
  Widget _buildBody(BuildContext context, GameState state) {
    if (state.initError != null && !state.isLoading) { // Show error if not loading
      return _buildErrorState(state);
    }

    if (state.isLoading) {
      // FIX: Pass the 'state' variable here
      return _buildLoadingState(state);
    }

    return _buildLoginUI(state);
  }

  Widget _buildLoadingState(GameState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Colors.deepOrange),
        const SizedBox(height: 24),
        Text(
            state.initError ?? "ESTABLISHING LINK...",
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70,
                letterSpacing: 1.5,
                fontSize: 10,
                fontFamily: 'monospace' // Makes it look like a terminal
            )
        ),
      ],
    );
  }

  Widget _buildErrorState(GameState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.signal_wifi_off, size: 64, color: Colors.redAccent),
        const SizedBox(height: 24),
        Text(state.initError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => state.initializeUserSession(state.currentUid!),
          child: const Text("RETRY COMMAND LINK"),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => state.setInitialCompanyName(state.companyName),
          child: const Text("ABANDON LINK & START NEW CORP",
              style: TextStyle(color: Colors.white24, fontSize: 10)),
        ),
      ],
    );
  }

  Widget _buildLoginUI(GameState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.rocket_launch, size: 80, color: Colors.deepOrange),
        const SizedBox(height: 24),
        const Text(
          "MARS ORBITAL\nSHIPPING CO.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 64),
        ElevatedButton.icon(
          onPressed: () async => await state.signInWithGoogle(),
          icon: const Icon(Icons.login),
          label: const Text("CONNECT GOOGLE ACCOUNT"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "ENCRYPTED AUTHENTICATION REQUIRED",
          style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 1.2),
        ),
      ],
    );
  }
}