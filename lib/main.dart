
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Required when running SQLite on Flutter Web.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  runApp(const TimeTrackApp());
}

class TimeTrackApp extends StatelessWidget {
  const TimeTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF15171E);
    const surface = Color(0xFF20232C);
    const primary = Color(0xFF14B8A6);

    return MaterialApp(
      title: 'TimeTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,

        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: Color(0xFF5EEAD4),
          surface: surface,
          error: Color(0xFFEF4444),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          centerTitle: false,
        ),

        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white10),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: primary,
              width: 1.5,
            ),
          ),
        ),

        floatingActionButtonTheme:
            const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.black,
        ),
      ),
      home: const AppShell(),
    );
  }
}
