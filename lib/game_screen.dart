import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Dash Runner — endless neon runner: tap to jump, swipe down to slide.
class DashRunnerScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const DashRunnerScreen({super.key, required this.players, required this.callbacks});

  @override
  State<DashRunnerScreen> createState() => _DashRunnerScreenState();
}

enum _Kind { crate, tallCrate, bird }

class _Ob {
  double x;
  final _Kind kind;
  double bob = 0;
  _Ob(this.x, this.kind);
}

class _Coin {
  double x, y;
  bool taken = false;
  _Coin(this.x, this.y);
}

class _DashRunnerScreenState extends State<DashRunnerScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _last = Duration.zero;

  bool started = false;
  bool over = false;

  double y = 0; // height above ground, px
  double vy = 0;
  bool sliding = false;
  double slideT = 0;

  double dist = 0;
  double speed = 340;
  int coins = 0;
  double time = 0;

  final List<_Ob> obs = [];
  final List<_Coin> cs = [];
  double spawnT = 1.0;
  final rng = Random();

  int best = 0;
  Size view = Size.zero;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => best = p.getInt('dashrunner_best') ?? 0);
    });
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.016 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!mounted || over || !started) return;
    if (ModalRoute.of(context)?.isCurrent != true) return; // pause overlay: freeze world
    final dtc = dt.clamp(0.0, 0.05);
    setState(() => _step(dtc));
  }

  void _step(double dt) {
    time += dt;
    speed = 340 + min(dist / 40, 560);
    dist += speed * dt;

    // player physics
    if (y > 0 || vy != 0) {
      vy -= 2600 * dt;
      y += vy * dt;
      if (y <= 0) {
        y = 0;
        vy = 0;
        Sfx.tap();
      }
    }
    if (sliding) {
      slideT -= dt;
      if (slideT <= 0) sliding = false;
    }

    // spawn obstacles
    spawnT -= dt;
    if (spawnT <= 0) {
      spawnT = max(0.55, 1.2 - dist / 5000) * (0.8 + rng.nextDouble() * 0.5);
      final r = rng.nextDouble();
      final kind = r < 0.42
          ? _Kind.crate
          : r < 0.68
              ? _Kind.tallCrate
              : (dist > 250 ? _Kind.bird : _Kind.crate);
      obs.add(_Ob(view.width + 60, kind));
      // coin arc sometimes
      if (rng.nextDouble() < 0.6) {
        final baseY = rng.nextDouble() < 0.5 ? 130.0 : 40.0;
        for (int i = 0; i < 5; i++) {
          cs.add(_Coin(view.width + 80 + i * 44, baseY - sin(i / 4 * pi) * 50));
        }
      }
    }

    final groundY = _groundY();
    final px = view.width * 0.28;
    final pW = 44.0, pH = sliding ? 34.0 : 62.0;
    final pTop = groundY - y - pH;

    // move + collide obstacles
    for (final o in obs) {
      o.x -= speed * dt;
      if (o.kind == _Kind.bird) o.bob += dt * 6;
    }
    obs.removeWhere((o) => o.x < -80);

    for (final o in obs) {
      final dims = _dims(o);
      final oTop = dims.$3;
      final overlap = o.x < px + pW - 8 &&
          o.x + dims.$1 > px + 8 &&
          pTop < oTop + dims.$2 &&
          pTop + pH > oTop + 6;
      if (overlap) {
        _gameOver();
        return;
      }
    }

    // coins
    for (final c in cs) {
      c.x -= speed * dt;
      if (!c.taken &&
          c.x > px - 10 &&
          c.x < px + pW + 10 &&
          (groundY - c.y) > y - 40 &&
          (groundY - c.y) < y + pH + 40) {
        c.taken = true;
        coins++;
        Sfx.click();
      }
    }
    cs.removeWhere((c) => c.x < -40 || c.taken);
  }

  /// (width, height, top offset above ground)
  (double, double, double) _dims(_Ob o) {
    final groundY = _groundY();
    switch (o.kind) {
      case _Kind.crate:
        return (46, 46, groundY - 46);
      case _Kind.tallCrate:
        return (46, 86, groundY - 86);
      case _Kind.bird:
        return (52, 36, groundY - 118 + sin(o.bob) * 12);
    }
  }

  double _groundY() => view.height * 0.78;

  void _jump() {
    if (!started || over) return;
    if (y == 0) {
      sliding = false;
      vy = 980;
      y = 0.1;
      Sfx.move();
    }
  }

  void _slide() {
    if (!started || over || y > 4) return;
    sliding = true;
    slideT = 0.65;
    Sfx.tap();
  }

  Future<void> _gameOver() async {
    over = true;
    Sfx.lose();
    final d = dist.toInt();
    final total = d + coins * 10;
    widget.players[0].score = total;
    widget.callbacks.refreshHud();
    final prefs = await SharedPreferences.getInstance();
    final isBest = d > best;
    if (isBest) {
      await prefs.setInt('dashrunner_best', d);
      if (mounted) setState(() => best = d);
    }
    if (!mounted) return;
    widget.callbacks.finish(
      headline: 'You dashed $d m! 🏃',
      subline: isBest ? 'NEW BEST! 🥇  $coins coins snagged.' : '$coins coins snagged. Best: $best m.',
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return LayoutBuilder(
      builder: (_, constraints) {
        view = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!started && !over) {
              setState(() => started = true);
            } else {
              _jump();
            }
          },
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) > 250) _slide();
          },
          child: Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _RunnerPainter(
                  dist: dist,
                  y: y,
                  sliding: sliding,
                  time: time,
                  obs: obs,
                  coins: cs,
                  groundY: _groundY(),
                  px: view.width * 0.28,
                  theme: t,
                  started: started,
                ),
              ),
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _hud('${dist.toInt()} m', t),
                    _hud('🪙 $coins', t),
                    _hud('🏆 $best', t),
                  ],
                ),
              ),
              if (!started && !over)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                    decoration: BoxDecoration(color: t.surface, borderRadius: t.radius),
                    child: Text('Tap to start!\n👆 jump · ⬇ swipe to slide',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.text, fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
              if (started && !over && dist < 400)
                Positioned(
                  bottom: 26,
                  left: 0,
                  right: 0,
                  child: Text('👆 jump · swipe ⬇ slide',
                      textAlign: TextAlign.center, style: TextStyle(color: t.muted, fontSize: 13)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _hud(String s, GameTheme t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration:
            BoxDecoration(color: t.surface.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(14)),
        child: Text(s, style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 15)),
      );
}

class _RunnerPainter extends CustomPainter {
  final double dist, y, time, groundY, px;
  final bool sliding, started;
  final List<_Ob> obs;
  final List<_Coin> coins;
  final GameTheme theme;

  _RunnerPainter({
    required this.dist,
    required this.y,
    required this.time,
    required this.groundY,
    required this.px,
    required this.theme,
    required this.started,
    required this.sliding,
    required this.obs,
    required this.coins,
  });

  // day -> dusk -> night -> day over 2400m
  Color _sky(double phase) {
    const keys = [Color(0xFF7ED0FF), Color(0xFFFF9E6B), Color(0xFF0B1035), Color(0xFF7ED0FF)];
    final p = (phase % 1) * 3;
    final i = p.floor();
    return Color.lerp(keys[i], keys[i + 1], p - i)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final phase = (dist / 2400) % 1;
    final sky = _sky(phase);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = sky);

    // stars at night
    final nightness = (phase > 0.58 && phase < 0.95) ? 1.0 : 0.0;
    if (nightness > 0) {
      final sp = Paint()..color = Colors.white.withValues(alpha: 0.8);
      for (int i = 0; i < 30; i++) {
        final sx = (i * 197.3) % size.width;
        final sy = (i * 131.7) % (groundY * 0.6);
        canvas.drawCircle(Offset(sx, sy), 1.6, sp);
      }
      canvas.drawCircle(Offset(size.width * 0.8, 70), 26, Paint()..color = const Color(0xFFF4F1DE));
    } else {
      // sun
      canvas.drawCircle(Offset(size.width * 0.8, 80), 30, Paint()..color = const Color(0xFFFFD93D));
    }

    // parallax hills
    final hillP = Paint()..color = sky.computeLuminance() > 0.4 ? const Color(0xFF5BA86B) : const Color(0xFF123B33);
    for (int layer = 0; layer < 2; layer++) {
      final off = (dist * (0.15 + layer * 0.25)) % 320;
      for (int i = -1; i < size.width / 320 + 1; i++) {
        final hx = i * 320 - off + layer * 120;
        canvas.drawArc(Rect.fromCenter(center: Offset(hx, groundY), width: 300, height: 190 - layer * 50),
            pi, pi, true, hillP..color = hillP.color.withValues(alpha: 0.75 - layer * 0.25));
      }
    }

    // ground
    final gCol = sky.computeLuminance() > 0.4 ? const Color(0xFF2E7D5B) : const Color(0xFF0F2E2A);
    canvas.drawRect(Rect.fromLTWH(0, groundY, size.width, size.height - groundY), Paint()..color = gCol);
    canvas.drawRect(Rect.fromLTWH(0, groundY, size.width, 6), Paint()..color = theme.accent);

    // ground stripes
    final stripeP = Paint()..color = Colors.white.withValues(alpha: 0.12);
    final soff = dist % 90;
    for (double sx = -soff; sx < size.width; sx += 90) {
      canvas.drawRect(Rect.fromLTWH(sx, groundY + 14, 46, 8), stripeP);
    }

    // coins
    final cp = Paint()..color = const Color(0xFFFFD93D);
    for (final c in coins) {
      final cy = groundY - c.y + sin(time * 6 + c.x * 0.05) * 5;
      canvas.drawCircle(Offset(c.x, cy), 13, cp);
      canvas.drawCircle(Offset(c.x, cy), 13, Paint()..style = PaintingStyle.stroke..color = const Color(0xFFB8860B)..strokeWidth = 3);
      canvas.drawCircle(Offset(c.x, cy), 6, Paint()..color = const Color(0xFFFFF3B0));
    }

    // obstacles
    for (final o in obs) {
      switch (o.kind) {
        case _Kind.crate:
        case _Kind.tallCrate:
          final h = o.kind == _Kind.crate ? 46.0 : 86.0;
          final r = RRect.fromLTRBR(o.x, groundY - h, o.x + 46, groundY, const Radius.circular(8));
          canvas.drawRRect(r, Paint()..color = const Color(0xFFC46A3B));
          canvas.drawRRect(r, Paint()..style = PaintingStyle.stroke..color = const Color(0xFF7A3E1F)..strokeWidth = 3);
          canvas.drawLine(Offset(o.x, groundY - h / 2), Offset(o.x + 46, groundY - h / 2),
              Paint()..color = const Color(0xFF7A3E1F)..strokeWidth = 3);
          canvas.drawLine(Offset(o.x + 23, groundY - h), Offset(o.x + 23, groundY),
              Paint()..color = const Color(0xFF7A3E1F)..strokeWidth = 3);
        case _Kind.bird:
          final by = groundY - 118 + sin(o.bob) * 12;
          final flap = sin(time * 14) * 14;
          final bp = Paint()..color = const Color(0xFF9B5DE5);
          // wings
          canvas.drawOval(Rect.fromCenter(center: Offset(o.x + 10, by + 8), width: 30, height: 14 + flap), bp);
          canvas.drawOval(Rect.fromCenter(center: Offset(o.x + 42, by + 8), width: 30, height: 14 - flap), bp);
          // body
          canvas.drawOval(Rect.fromCenter(center: Offset(o.x + 26, by + 18), width: 52, height: 30), bp);
          canvas.drawCircle(Offset(o.x + 34, by + 14), 4, Paint()..color = Colors.white);
          canvas.drawCircle(Offset(o.x + 35, by + 14), 2, Paint()..color = Colors.black);
          // beak
          final beak = Path()
            ..moveTo(o.x + 50, by + 16)
            ..lineTo(o.x + 60, by + 20)
            ..lineTo(o.x + 50, by + 24)
            ..close();
          canvas.drawPath(beak, Paint()..color = const Color(0xFFFF9E2C));
      }
    }

    // player
    final pH = sliding ? 34.0 : 62.0;
    final pTop = groundY - y - pH;
    final pr = RRect.fromLTRBR(px, pTop, px + 44, groundY - y, const Radius.circular(14));
    final bodyP = Paint()..color = theme.primary;
    canvas.drawRRect(pr, bodyP);
    // visor
    canvas.drawRRect(RRect.fromLTRBR(px + 8, pTop + 10, px + 36, pTop + 24, const Radius.circular(7)),
        Paint()..color = Colors.white.withValues(alpha: 0.9));
    // legs
    if (!sliding && y == 0) {
      final legSwing = sin(time * 22) * 10;
      final lp = Paint()
        ..color = theme.primary
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(px + 14, groundY - y), Offset(px + 14 + legSwing, groundY - y + 20), lp);
      canvas.drawLine(Offset(px + 30, groundY - y), Offset(px + 30 - legSwing, groundY - y + 20), lp);
    }
    if (sliding) {
      // speed lines
      final slp = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 3;
      for (int i = 0; i < 3; i++) {
        canvas.drawLine(Offset(px - 10, pTop + 8 + i * 10), Offset(px - 34, pTop + 8 + i * 10), slp);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RunnerPainter old) => true;
}
