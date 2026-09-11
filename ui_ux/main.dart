import 'package:flutter/material.dart';
import 'design_system.dart';
import 'home_screen.dart';

void main() {
  runApp(const PrestoMataaApp());
}

class PrestoMataaApp extends StatefulWidget {
  const PrestoMataaApp({super.key});

  @override
  State<PrestoMataaApp> createState() => _PrestoMataaAppState();
}

class _PrestoMataaAppState extends State<PrestoMataaApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Presto x Mataa Super-App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: const HomeScreen(),
    );
  }
}
