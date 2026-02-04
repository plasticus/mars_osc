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
import 'screens/corporate_hub_screen.dart'; // Updated import
import 'screens/engineering_screen.dart';
import 'screens/new_user_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the generated options
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
        // 1) Waiting for Firebase Auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final state = context.watch<GameState>();
        final user = snapshot.data;

        // 2) Wait until local load is done before doing cloud work
        // (Your GameState sets isLoading false after _loadData finishes now.)
        if (state.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Loading Local Save...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        // 3) Run connect/restore logic ONCE after local load is done
        final uid = user?.uid;

        if (_lastUid != uid) {
          _lastUid = uid;

          Future.microtask(() async {
            if (!mounted) return;
            if (uid != null) {
              await state.connectCloudSession(uid);

              if (!state.hasLocalSave) {
                await state.restoreFromCloudIfNewer(force: true);
              }
            }

            state.startLoopsIfNeeded();
          });
        }


        // 4) Handle Errors or New Users
        return Consumer<GameState>(
          builder: (context, state, child) {
            if (state.initError != null || state.isNewUser) {
              return const NewUserScreen();
            }

            // If not logged in
            if (user == null) {
              return const LoginScreen();
            }

            // Everything is good
            return child!;
          },
          child: const MainNavigationScreen(),
        );
      },
    );
  }
}


class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with AutomaticKeepAliveClientMixin {
  int _selectedIndex = 0;

  @override
  bool get wantKeepAlive => true;

  // Updated titles for the AppBar
  final List<String> _titles = [
    'Operations',
    'Dry Dock',
    'Contract Board',
    'Engineering',
    'Corporate Hub',
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final state = context.watch<GameState>();

    // Updated screen list to include the new Hub
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
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Contracts'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Eng'),
          BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Hub'),
        ],
      ),
    );
  }
}
