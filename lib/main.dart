import 'package:flutter/material.dart';

import 'game/hub_game.dart';
import 'ui/game_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SaessakApp());
}

class SaessakApp extends StatefulWidget {
  const SaessakApp({super.key});

  @override
  State<SaessakApp> createState() => _SaessakAppState();
}

class _SaessakAppState extends State<SaessakApp> {
  final HubGame game = HubGame();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: C.bg,
        colorScheme: const ColorScheme.dark(primary: C.accent),
      ),
      home: Scaffold(body: GameScreen(game)),
    );
  }
}