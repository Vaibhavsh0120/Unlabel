import 'package:flutter/material.dart';

import '../features/scanner/presentation/foundation_home.dart';

class UnlabelApp extends StatefulWidget {
  const UnlabelApp({super.key});

  @override
  State<UnlabelApp> createState() => _UnlabelAppState();
}

class _UnlabelAppState extends State<UnlabelApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unlabel',
      debugShowCheckedModeBanner: false,
      // Stock Material roles are temporary. No brand palette is selected.
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: _themeMode,
      home: FoundationHome(
        themeMode: _themeMode,
        onThemeModeChanged: (value) => setState(() => _themeMode = value),
      ),
    );
  }
}
