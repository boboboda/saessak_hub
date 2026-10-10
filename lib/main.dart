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
      // 카이로소프트풍 밝은 테마: 크림 창 + 갈색 글씨 + 도트 폰트
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: kFont,
        scaffoldBackgroundColor: C.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: C.accent, primary: C.accent, surface: C.panel),
      ).copyWith(
        textTheme: ThemeData.light().textTheme.apply(fontFamily: kFont, bodyColor: C.text, displayColor: C.text),
      ),
      home: Scaffold(body: GameScreen(game)),
    );
  }
}