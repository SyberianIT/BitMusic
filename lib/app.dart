import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

class BitMusicApp extends StatelessWidget {
  const BitMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BitMusic',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _light(),
      darkTheme: _dark(),
      home: const HomeScreen(),
    );
  }

  ThemeData _light() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      );

  ThemeData _dark() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
          surface: const Color(0xFF12121F),
          onSurface: Colors.white,
        ).copyWith(
          surfaceContainer: const Color(0xFF1C1C2E),
          surfaceContainerHighest: const Color(0xFF252540),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
        cardColor: const Color(0xFF1C1C2E),
      );
}
