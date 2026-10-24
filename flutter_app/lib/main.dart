import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/hive_stores.dart';
import 'screens/growth_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'services/watch_service.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final events = await HiveEventStore.open();
  final profile = await HiveProfileStore.open();
  final watch = WatchService()..init();
  runApp(
    ProviderScope(
      overrides: [
        eventStoreProvider.overrideWithValue(events),
        profileStoreProvider.overrideWithValue(profile),
        watchServiceProvider.overrideWithValue(watch),
      ],
      child: const MiyaBabyApp(),
    ),
  );
}

class MiyaBabyApp extends ConsumerStatefulWidget {
  const MiyaBabyApp({super.key});

  @override
  ConsumerState<MiyaBabyApp> createState() => _MiyaBabyAppState();
}

class _MiyaBabyAppState extends ConsumerState<MiyaBabyApp> {
  @override
  void initState() {
    super.initState();
    // Wire watch actions to the event logic once providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final watch = ref.read(watchServiceProvider);
      final events = ref.read(eventsProvider.notifier);
      watch.onWatchMessage = WatchService.buildHandler(
        logInstant: events.logInstant,
        startTimer: events.startTimer,
        stopTimer: events.stopTimer,
      );
      // Only now can Dart act on watch messages; let iOS flush its buffer.
      watch.markReady();
      // Push an initial snapshot so the watch isn't empty.
      events.pushSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Miya Baby',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    HistoryScreen(),
    StatsScreen(),
    GrowthScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Stats'),
          NavigationDestination(
              icon: Icon(Icons.show_chart_outlined),
              selectedIcon: Icon(Icons.show_chart),
              label: 'Growth'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }
}
