import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const DashRunnerApp());

class DashRunnerApp extends StatelessWidget {
  const DashRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.candyShop,
      title: 'Dash Runner',
      tagline: 'Jump, slide and dash through an endless neon world',
      emoji: '🏃',
      slug: 'dashrunner',
      howToPlay:
          '• Tap anywhere to jump over crates.\n• Swipe down to slide under birds.\n• Grab coins for bonus points — speed keeps rising!\n• One crash and the run is over. How far can you dash?',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => DashRunnerScreen(players: players, callbacks: cb),
    );
  }
}
