import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/game_state.dart';
import 'screens/login_screen.dart';
import 'screens/dry_dock_screen.dart';
import 'screens/mission_board_screen.dart';
import 'screens/operations_screen.dart';
import 'screens/corporate_hub_screen.dart';
import 'screens/engineering_screen.dart';
import 'screens/new_user_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
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
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/home': (context) => const MainNavigationScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _lastUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final state = context.watch<GameState>();
        final user = snapshot.data;

        if (state.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    "Loading Local Save...",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        final uid = user?.uid;

        if (_lastUid != uid) {
          _lastUid = uid;
          Future.microtask(() async {
            if (!mounted) return;

            if (uid != null) {
              await state.connectCloudSession(uid);

              if (!state.hasLocalSave) {
                debugPrint("⚡ MAIN: No local save. Triggering FORCE restore...");
                await state.restoreFromCloudIfNewer(force: true);
              }
            }

            state.startLoopsIfNeeded();
          });
        }

        return Consumer<GameState>(
          builder: (context, state, child) {
            if (state.initError != null || state.isNewUser) {
              return const NewUserScreen();
            }

            if (user == null) {
              return const LoginScreen();
            }

            return child!;
          },
          child: const MainLifecycleWrapper(),
        );
      },
    );
  }
}

/// Handles save-on-exit + conflict dialog for the whole session
class MainLifecycleWrapper extends StatefulWidget {
  const MainLifecycleWrapper({super.key});

  @override
  State<MainLifecycleWrapper> createState() => _MainLifecycleWrapperState();
}

class _MainLifecycleWrapperState extends State<MainLifecycleWrapper>
    with WidgetsBindingObserver {
  bool _conflictDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final gs = context.read<GameState>();
    gs.addListener(() {
      final conflict = gs.activeConflict;
      if (conflict != null && !_conflictDialogOpen) {
        _conflictDialogOpen = true;

        // Ensure dialog opens after build/frame (safer)
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await _showConflictDialog(context, gs, conflict);
          _conflictDialogOpen = false;
        });
      }
    });

    context.read<GameState>().milestoneService.initializeGlobalListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      debugPrint("🛰️ LIFECYCLE: App minimized. Pushing Registry to cloud...");
      context.read<GameState>().uploadLocalSaveToCloud();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MainNavigationScreen();
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with AutomaticKeepAliveClientMixin {
  int _selectedIndex = 0;

  @override
  bool get wantKeepAlive => true;

  final List<String> _titles = [
    'Operations',
    'Dry Dock',
    'Contract Board',
    'Engineering',
    'Corporate Hub',
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final state = context.watch<GameState>();

    final List<Widget> screens = [
      const OperationsScreen(),
      const DryDockScreen(),
      const MissionBoardScreen(),
      const EngineeringScreen(),
      const CorporateHubScreen(),
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
                  color: Colors.orangeAccent,
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
          setState(() => _selectedIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Ops'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Dry Dock'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Contracts'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Eng'),
          BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Hub'),
        ],
      ),
    );
  }
}

// Helper to keep the dialog code clean
Widget _buildChoiceCard(
  String label,
  DateTime time,
  int worth,
  int contracts,
  Color color,
) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: color.withOpacity(0.5)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        Text(
          "Saved: ${time.hour}:${time.minute.toString().padLeft(2, '0')}",
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          "Net Worth: ⁂$worth",
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          "Contracts: $contracts",
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

Future<void> _showConflictDialog(
  BuildContext context,
  GameState state,
  SaveConflict conflict,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text(
        "TIMELINE DISCREPANCY",
        style: TextStyle(color: Colors.orangeAccent),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChoiceCard(
            "PHONE (Local)",
            conflict.localTime,
            conflict.localNetWorth,
            conflict.localContracts,
            Colors.blue,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Icon(Icons.compare_arrows, color: Colors.grey),
          ),
          _buildChoiceCard(
            "RELAY (Cloud)",
            conflict.cloudTime,
            conflict.cloudNetWorth,
            conflict.cloudContracts,
            Colors.green,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            state.resolveConflict(useCloud: false);
          },
          child: const Text("KEEP PHONE"),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            state.resolveConflict(useCloud: true);
          },
          child: const Text("RESTORE CLOUD"),
        ),
      ],
    ),
  );
}
