import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'attendance_home_screen.dart';
import 'attendance_calendar_screen.dart';
import 'attendance_records_screen.dart';
import 'attendance_reports_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const Color _bg = Color(0xFF15171E);
  static const Color _surface = Color(0xFF20232C);
  static const Color _border = Color(0x14FFFFFF);
  static const Color _accent = Color(0xFF2DD4BF);
  static const Color _indicator = Color(0xFF164E49);
  static const Color _inactive = Color(0xFF6B7180);

  int _selectedIndex = 0;

  // Screens stay alive in the IndexedStack, so scroll position and
  // filters are kept when switching tabs.
  late final List<Widget> _screens = const [
    AttendanceHomeScreen(),
    AttendanceCalendarScreen(),
    AttendanceRecordsScreen(),
    AttendanceReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Each screen draws its own header, so the shell has no AppBar.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _surface,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: IndexedStack(index: _selectedIndex, children: _screens),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _border)),
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: _surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              height: 68,
              indicatorColor: _indicator,
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return IconThemeData(
                  size: 24,
                  color: selected ? _accent : _inactive,
                );
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _accent : _inactive,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                if (index == _selectedIndex) return;
                setState(() => _selectedIndex = index);
              },
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Calendar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Records',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Reports',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
