import 'package:flutter/material.dart';
import 'alerts_screen.dart';
import 'ranking_screen.dart';
import 'settings_screen.dart';
import 'simulator_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  static const List<Widget> _pages = <Widget>[
    RankingScreen(),
    AlertsScreen(),
    SimulatorScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (int i) => setState(() => _i = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.leaderboard), label: 'Classement'),
          NavigationDestination(icon: Icon(Icons.notifications_active), label: 'Alertes'),
          NavigationDestination(icon: Icon(Icons.science), label: 'Simulateur'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Reglages'),
        ],
      ),
    );
  }
}
