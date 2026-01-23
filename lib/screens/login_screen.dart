import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<GameState>();

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                  Icons.rocket_launch,
                  size: 80,
                  color: Colors.deepOrange
              ),
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

              // Google Sign In Button with Troubleshooting
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    debugPrint("COREY_LOG: Starting Google Sign-In...");
                    await state.signInWithGoogle();
                  } catch (e) {
                    debugPrint("COREY_LOG: Login Error: $e");

                    // Show full error on screen so we can see the code (e.g., 10 or 12500)
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("COMMAND LINK FAILED: $e"),
                          backgroundColor: Colors.red.shade900,
                          duration: const Duration(seconds: 15),
                          action: SnackBarAction(
                            label: 'RETRY',
                            textColor: Colors.white,
                            onPressed: () {},
                          ),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.login),
                label: const Text("CONNECT GOOGLE ACCOUNT"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                "ENCRYPTED AUTHENTICATION REQUIRED",
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}