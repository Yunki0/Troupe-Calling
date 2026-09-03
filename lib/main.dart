import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/roster_screen.dart';
import 'screens/history_screen.dart';
import 'screens/dashboard_screen.dart';
import 'db/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  runApp(const AppelScoutApp());
}

class AppelScoutApp extends StatelessWidget {
  const AppelScoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Troupe Manager',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(next: RootShell()),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  String troopName = 'Troupe Manager';

  // Bump this to force child screens to reload roster/attendance after changes.
  int refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _loadTroopName();
  }

  Future<void> _loadTroopName() async {
    final name = await DatabaseHelper.instance.getSetting('troopName');
    if (name != null && name.isNotEmpty && mounted) {
      setState(() => troopName = name);
    }
  }

  void triggerRefresh() {
    setState(() => refreshTick++);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(key: ValueKey('dashboard-$refreshTick')),
      ScanScreen(key: ValueKey('scan-$refreshTick')),
      RosterScreen(
        key: ValueKey('roster-$refreshTick'),
        onTroopNameChanged: (v) =>
            setState(() => troopName = v.trim().isEmpty ? 'Troupe Manager' : v.trim()),
        onRosterChanged: triggerRefresh,
      ),
      HistoryScreen(
        key: ValueKey('history-$refreshTick'),
        onReunionChanged: triggerRefresh,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(troopName)),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() {
          _index = i;
          if (i == 3) triggerRefresh(); // recalcule les stats à chaque ouverture
        }),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_customize), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Appel'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Jeunes'),
          BottomNavigationBarItem(icon: Icon(Icons.event_note), label: 'Historique'),
        ],
      ),
    );
  }
}
