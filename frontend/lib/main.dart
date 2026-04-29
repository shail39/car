import 'package:flutter/material.dart';
import 'screens/dashboard.dart';
import 'screens/cars_list.dart';
import 'screens/partners.dart';
import 'screens/market_analyzer.dart';

void main() {
  runApp(const CarManagerApp());
}

class CarManagerApp extends StatelessWidget {
  const CarManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WrenchLogs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
  int _idx = 0;

  static const _screens = [
    DashboardScreen(),
    CarsListScreen(),
    PartnersScreen(),
    MarketAnalyzerScreen(),
  ];

  static const _destinations = [
    (icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
    (icon: Icons.directions_car_outlined, activeIcon: Icons.directions_car, label: 'Cars'),
    (icon: Icons.people_outline, activeIcon: Icons.people, label: 'Partners'),
    (icon: Icons.insights_outlined, activeIcon: Icons.insights, label: 'Analyzer'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    if (isWide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _idx,
            onDestinationSelected: (i) => setState(() => _idx = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(children: [
                Icon(Icons.build_circle, size: 32, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 4),
                Text('WrenchLogs',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 11)),
              ]),
            ),
            destinations: _destinations
                .map((d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.activeIcon),
                      label: Text(d.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _screens[_idx]),
        ]),
      );
    }

    return Scaffold(
      body: _screens[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: _destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.activeIcon),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}
