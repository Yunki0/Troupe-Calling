import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/roster_screen.dart';
import 'screens/history_screen.dart';
import 'screens/dashboard_screen.dart';
import 'db/database_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppelScoutApp());
}

Future<String?> _initializeApp() async {
  await initializeDateFormatting('fr_FR', null);
  return DatabaseHelper.instance.getSetting('troopName');
}

class AppelScoutApp extends StatelessWidget {
  const AppelScoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Appel Scout',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppDarkTheme(),
      themeMode: ThemeMode.system,
      home: SplashScreen(
        initialize: _initializeApp,
        nextBuilder: (context, troopName) =>
            RootShell(initialTroopName: troopName),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key, required this.initialTroopName});

  final String? initialTroopName;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  late String troopName;

  // Bump this to force child screens to reload roster/attendance after changes.
  int refreshTick = 0;

  @override
  void initState() {
    super.initState();
    final initialName = widget.initialTroopName?.trim();
    troopName = initialName == null || initialName.isEmpty
        ? 'Ma troupe'
        : initialName;
  }

  void triggerRefresh() {
    setState(() => refreshTick++);
  }

  @override
  Widget build(BuildContext context) {
    const destinations = ['Accueil', 'Appel', 'Jeunes', 'Historique'];
    final screens = [
      DashboardScreen(
        key: ValueKey('dashboard-$refreshTick'),
        onNavigate: (index) => setState(() => _index = index),
      ),
      ScanScreen(key: ValueKey('scan-$refreshTick')),
      RosterScreen(
        key: ValueKey('roster-$refreshTick'),
        onRosterChanged: triggerRefresh,
      ),
      HistoryScreen(
        key: ValueKey('history-$refreshTick'),
        onReunionChanged: triggerRefresh,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.explore_rounded,
                color: AppColors.khakiLight,
                size: 22,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    destinations[_index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                  ),
                  Text(
                    troopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.khakiLight,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Tooltip(
              message: 'Données enregistrées sur cet appareil',
              child: Icon(
                Icons.storage_rounded,
                size: 19,
                color: AppColors.khakiLight.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner_rounded),
            label: 'Appel',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_2_outlined),
            selectedIcon: Icon(Icons.groups_2_rounded),
            label: 'Jeunes',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Historique',
          ),
        ],
      ),
    );
  }
}
