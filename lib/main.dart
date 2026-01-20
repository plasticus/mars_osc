import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// These are the files we created earlier
import 'firebase_options.dart';
import 'providers/game_state.dart';
import 'screens/hangar_screen.dart';

void main() async {
  // 1. Ensure Flutter is ready to handle async calls before the app starts
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase using the settings you generated with flutterfire configure
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    // 3. Wrap the whole app in your GameState provider
    // This allows every screen to access solars, ships, and missions
    ChangeNotifierProvider(
      create: (context) => GameState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MOSC Fleet Manager',
      debugShowCheckedModeBanner: false, // Removes that "Debug" banner

      // Use a dark theme to fit the sci-fi/space vibe
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepOrange,
        useMaterial3: true,
      ),

      // The Hangar Screen is your new starting point
      home: const HangarScreen(),
    );
  }
}