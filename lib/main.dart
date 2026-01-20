import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/game_state.dart';
import 'screens/dry_dock_screen.dart';
import 'screens/mission_board_screen.dart';
import 'screens/operations_screen.dart';
import 'screens/mission_logs_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    // Added intl package might be needed for DateFormat in MissionLogsScreen
    // User might need to run 'flutter pub add intl' if not already present
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepOrange,
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Operations',
    'Dry Dock',
    'Mission Board',
    'Engineering',
    'Mission Logs',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();

    final List<Widget> screens = [
      const OperationsScreen(),
      const DryDockScreen(),
      const MissionBoardScreen(),
      const PlaceholderScreen(title: 'Engineering'),
      const MissionLogsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                "⁂ ${state.solars}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Ops'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Dry Dock'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Missions'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Eng'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Logs'),
        ],
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text("$title Screen (Coming Soon)"));
  }
}
