import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/runner_themes.dart';
import 'menu_screen.dart';
import 'widgets.dart';

/// Single launch splash with two moments:
/// 1. WAJIHA company splash (official logo, unaltered) — brief brand moment.
/// 2. Game splash: logo + name + animated loading line + "Credits: WAJIHA".
/// Audio clips are pre-warmed during the company moment so menu music starts
/// instantly on menu entry.
class SplashScreen extends StatefulWidget {
  final DashAudio audio;
  final DashSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _gameMoment = false;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Company moment: pre-warm audio behind the scenes.
    widget.audio.prewarm();
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    setState(() => _gameMoment = true);
    widget.audio.startMenuMusic();
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            MenuScreen(audio: widget.audio, settings: widget.settings),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.settings.theme;
    return Scaffold(
      backgroundColor: const Color(0xFF241A10),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _gameMoment ? _gameSplash(t) : _companyMoment(),
      ),
    );
  }

  Widget _companyMoment() => Container(
        key: const ValueKey('company'),
        color: const Color(0xFF0B0B0E),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/wajiha_logo.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 18),
              const Text(
                'W A J I H A',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 6,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _gameSplash(RunnerThemeDef t) => Container(
        key: const ValueKey('game'),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A2A16), Color(0xFF1E140B)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: t.accent, width: 4),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black87,
                        offset: Offset(0, 10),
                        blurRadius: 24),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/dashrunner_logo.png',
                    fit: BoxFit.cover),
              ),
              const SizedBox(height: 22),
              Text('DASH RUNNER', style: display(46, t)),
              const SizedBox(height: 6),
              Text('JUMP · SLIDE · DASH',
                  style: body(13, t,
                      color: Colors.white70, weight: FontWeight.w700)),
              const SizedBox(height: 30),
              SizedBox(
                width: 220,
                child: AnimatedBuilder(
                  animation: _loader,
                  builder: (_, _) => Column(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.black.withValues(alpha: 0.5),
                          border: Border.all(
                              color: t.accent.withValues(alpha: 0.5)),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _loader.value.clamp(0.02, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: t.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _loader.value < 1
                            ? 'Lacing up the trail shoes…'
                            : 'Ready!',
                        style: body(13, t, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 44),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/wajiha_logo.png',
                      width: 30, height: 30, fit: BoxFit.contain),
                  const SizedBox(width: 10),
                  Text('Credits: WAJIHA',
                      style: body(14, t, weight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      );
}
