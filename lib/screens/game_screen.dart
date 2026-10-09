import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/dash_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/runner_themes.dart';
import 'widgets.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.dashrunner';

/// The run screen. The [DashEngine] owns every phase and transition; this
/// widget renders, forwards input, and narrates events. The world can never
/// get stuck: the engine's watchdog recovers every phase.
class GameScreen extends StatefulWidget {
  final DashAudio audio;
  final DashSettings settings;
  final DashMode mode;

  const GameScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.mode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late DashEngine _engine;
  late Ticker _ticker;
  Duration _last = Duration.zero;
  final List<_Toast> _toasts = [];
  int _toastSeq = 0;
  bool _recorded = false;
  bool _isBest = false;
  int _lastCountdown = 4;

  RunnerThemeDef get _t => widget.settings.theme;
  RunnerStyle get _rs =>
      RunnerStyles.byId(widget.settings.runnerStyleId);
  ObstacleStyle get _os =>
      ObstacleStyles.byId(widget.settings.obstacleStyleId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = DashEngine(mode: widget.mode);
    _engine.onPhase = _onPhase;
    _engine.onEvent = _onEvent;
    _ticker = createTicker(_tick)..start();
    widget.audio.startGameMusic();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding mid-run freezes the world: the pause overlay shows when
    // the user returns, and music resumes exactly where it paused.
    if (state == AppLifecycleState.paused &&
        _engine.phase == DashPhase.running) {
      _engine.pause();
    }
  }

  void _onPhase(DashPhase p) {
    if (!mounted) return;
    setState(() {});
  }

  void _onEvent(DashEvent e) {
    if (!mounted) return;
    switch (e.kind) {
      case DashEventKind.jump:
        widget.audio.jump();
      case DashEventKind.slide:
        widget.audio.slide();
      case DashEventKind.land:
        widget.audio.land();
      case DashEventKind.coin:
        widget.audio.coin();
      case DashEventKind.nearMiss:
        widget.audio.nearMiss();
      case DashEventKind.milestone:
        widget.audio.milestone();
      case DashEventKind.crash:
        widget.audio.crash();
      case DashEventKind.finished:
        break;
    }
    // Juicy narration: every scored event pops a toast.
    if (e.points > 0 || e.kind == DashEventKind.crash) {
      setState(() {
        _toasts.add(_Toast(_toastSeq++, e.narration, e.kind));
      });
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) {
          setState(() {
            _toasts.removeWhere(
                (t) => t.id < _toastSeq - 3); // keep the latest few
          });
        }
      });
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.016
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!mounted) return;
    _engine.step(dt);
    // countdown ticks
    final c = _engine.countdownT.ceil();
    if (_engine.phase == DashPhase.countdown && c != _lastCountdown) {
      _lastCountdown = c;
      widget.audio.countdown();
    }
    if (_engine.phase == DashPhase.over && !_recorded) {
      _recorded = true;
      _onRunOver();
    }
    setState(() {}); // repaint every frame while the ticker lives
  }

  Future<void> _onRunOver() async {
    widget.audio.lose();
    final wasBest = await widget.settings.recordRun(
      modeId: widget.mode.id,
      score: _engine.score,
      distance: _engine.dist.toInt(),
      coins: _engine.coins,
    );
    if (wasBest && _engine.score > 0) {
      widget.audio.newBest();
      _isBest = true;
      // Sensible review moment: celebrate a new personal best.
      if (widget.settings.gamesPlayed >= 3) _requestReview();
    }
    if (mounted) setState(() {});
  }

  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (_) {
      // Unavailable on this build: stay silent, no fake UI.
    }
  }

  Future<void> _share() async {
    widget.audio.click();
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'I scored ${_engine.score} pts in Dash Runner (${widget.mode.name})! Can you beat it? $_storeUrl',
        ),
      );
    } catch (_) {}
  }

  void _restart() {
    widget.audio.gameStart();
    setState(() {
      _recorded = false;
      _isBest = false;
      _toasts.clear();
      _lastCountdown = 4;
      _engine.restart();
      _engine.start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _engine.dispose();
    widget.audio.startMenuMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (_, constraints) {
          _engine.viewW = constraints.maxWidth;
          _engine.viewH = constraints.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_engine.phase == DashPhase.ready) {
                widget.audio.gameStart();
                _engine.start();
              } else if (_engine.phase == DashPhase.running) {
                _engine.jump();
              }
            },
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 250) _engine.slide();
            },
            child: Stack(
              children: [
                CustomPaint(
                  size: Size.infinite,
                  painter: _RunnerPainter(
                    engine: _engine,
                    theme: t,
                    runner: _rs,
                    obstacles: _os,
                  ),
                ),
                _hud(t),
                _eventToasts(t),
                if (_engine.phase == DashPhase.ready) _readyCard(t),
                if (_engine.phase == DashPhase.countdown)
                  _countdownOverlay(t),
                if (_engine.phase == DashPhase.paused) _pausedOverlay(t),
                if (_engine.phase == DashPhase.over) _overPanel(t),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hud(RunnerThemeDef t) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: SafeArea(
        child: Row(
          children: [
            _pill('${_engine.dist.toInt()} m', t),
            const SizedBox(width: 8),
            _pill('🪙 ${_engine.coins}', t),
            const SizedBox(width: 8),
            _pill('⭐ ${_engine.score}', t),
            if (widget.mode == DashMode.scoreAttack) ...[
              const SizedBox(width: 8),
              _pill('⏱ ${_engine.scoreAttackT.ceil()}s', t,
                  hot: _engine.scoreAttackT < 10),
            ],
            const Spacer(),
            GestureDetector(
              onTap: () {
                widget.audio.click();
                _engine.pause();
              },
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.accent, width: 1.5),
                ),
                child: const Icon(Icons.pause,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String s, RunnerThemeDef t, {bool hot = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: hot ? const Color(0xFFE74C3C) : t.accent, width: 1.5),
        ),
        child: Text(s,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
      );

  /// Floating narration toasts for scored events.
  Widget _eventToasts(RunnerThemeDef t) {
    return Positioned(
      top: 110,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Column(
          children: [
            for (final toast in _toasts.reversed.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  toast.text,
                  style: TextStyle(
                    fontSize: toast.kind == DashEventKind.crash ? 30 : 19,
                    fontWeight: FontWeight.w900,
                    color: toast.kind == DashEventKind.crash
                        ? const Color(0xFFFF6B5E)
                        : Colors.white,
                    shadows: const [
                      Shadow(
                          color: Colors.black87,
                          offset: Offset(0, 2),
                          blurRadius: 5)
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _readyCard(RunnerThemeDef t) {
    return Center(
      child: WoodCard(
        theme: t,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.settings.playerName,
                style: display(24, t, color: Colors.white)),
            const SizedBox(height: 4),
            Text(widget.mode.name, style: display(30, t)),
            const SizedBox(height: 6),
            Text(widget.mode.blurb,
                textAlign: TextAlign.center,
                style: body(14, t, color: Colors.white70)),
            const SizedBox(height: 10),
            Text('👆 tap to jump · swipe ⬇ to slide',
                style: body(14, t, color: Colors.white70)),
            const SizedBox(height: 16),
            TrailButton(
              label: 'START RUN',
              icon: Icons.play_arrow,
              theme: t,
              onPressed: () {
                widget.audio.gameStart();
                _engine.start();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _countdownOverlay(RunnerThemeDef t) {
    final n = _engine.countdownT.ceil().clamp(1, 3);
    return Center(
      child: Text('$n',
          style: TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.w900,
            color: t.accent,
            shadows: const [
              Shadow(color: Colors.black87, offset: Offset(0, 6), blurRadius: 12)
            ],
          )),
    );
  }

  Widget _pausedOverlay(RunnerThemeDef t) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: WoodCard(
          theme: t,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PAUSED', style: display(32, t)),
              const SizedBox(height: 16),
              TrailButton(
                label: 'RESUME',
                icon: Icons.play_arrow,
                theme: t,
                onPressed: () {
                  widget.audio.click();
                  _engine.resume();
                },
              ),
              const SizedBox(height: 10),
              TrailButton(
                label: 'RESTART',
                icon: Icons.refresh,
                theme: t,
                primary: false,
                onPressed: () {
                  // pause -> crashed isn't allowed; go via a fresh engine
                  setState(() {
                    _engine.dispose();
                    _engine = DashEngine(mode: widget.mode);
                    _engine.onPhase = _onPhase;
                    _engine.onEvent = _onEvent;
                    _recorded = false;
                    _isBest = false;
                    _toasts.clear();
                    _lastCountdown = 4;
                    _engine.start();
                  });
                },
              ),
              const SizedBox(height: 10),
              TrailButton(
                label: 'QUIT',
                icon: Icons.home,
                theme: t,
                primary: false,
                onPressed: () {
                  widget.audio.click();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overPanel(RunnerThemeDef t) {
    final e = _engine;
    return Container(
      color: Colors.black54,
      child: Center(
        child: SingleChildScrollView(
          child: WoodCard(
            theme: t,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    e.phase == DashPhase.over && e.scoreAttackT == 0
                        ? "TIME'S UP!"
                        : 'WIPEOUT!',
                    style: display(34, t)),
                if (_isBest)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A017),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('🏆 NEW BEST!',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2B1B0E))),
                  ),
                const SizedBox(height: 10),
                Text('${e.score} pts',
                    style: display(44, t, color: Colors.white)),
                const SizedBox(height: 10),
                _row('🏃 Distance', '${e.dist.toInt()} m', t),
                _row('🪙 Coins', '${e.coins} × 10 = ${e.coins * 10}', t),
                _row('😱 Near misses',
                    '${e.nearMisses} × 5 = ${e.nearMisses * 5}', t),
                _row('🚩 Milestones',
                    '${e.milestones} × 25 = ${e.milestoneBonus}', t),
                const SizedBox(height: 6),
                Text(
                    'Best (${widget.mode.name}): ${widget.settings.bestScore[widget.mode.id] ?? 0} pts',
                    style: body(13, t, color: Colors.white70)),
                const SizedBox(height: 16),
                TrailButton(
                  label: 'RUN AGAIN',
                  icon: Icons.refresh,
                  theme: t,
                  onPressed: _restart,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TrailButton(
                      label: 'SHARE',
                      icon: Icons.share,
                      theme: t,
                      primary: false,
                      small: true,
                      onPressed: _share,
                    ),
                    const SizedBox(width: 10),
                    TrailButton(
                      label: 'MENU',
                      icon: Icons.home,
                      theme: t,
                      primary: false,
                      small: true,
                      onPressed: () {
                        widget.audio.click();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v, RunnerThemeDef t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(k, style: body(14, t, color: Colors.white70)),
            const SizedBox(width: 14),
            Text(v,
                style: body(14, t,
                    color: Colors.white, weight: FontWeight.w800)),
          ],
        ),
      );
}

class _Toast {
  final int id;
  final String text;
  final DashEventKind kind;
  _Toast(this.id, this.text, this.kind);
}

// ---------------------------------------------------------------------------
// Painter — pseudo-3D physical materials: painted sky cycle, layered hills,
// dusty ground, wooden/stone obstacles, a real runner with weight.
class _RunnerPainter extends CustomPainter {
  final DashEngine engine;
  final RunnerThemeDef theme;
  final RunnerStyle runner;
  final ObstacleStyle obstacles;

  _RunnerPainter({
    required this.engine,
    required this.theme,
    required this.runner,
    required this.obstacles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final e = engine;
    final phase = (e.dist / 2400) % 1;
    final sky = theme.sky(phase);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = sky);
    final dark = theme.isDark(phase);
    final gY = e.groundY;

    // sun / moon + stars
    if (dark) {
      final sp = Paint()..color = Colors.white.withValues(alpha: 0.75);
      for (int i = 0; i < 34; i++) {
        final sx = (i * 197.3) % size.width;
        final sy = (i * 131.7) % (gY * 0.55);
        canvas.drawCircle(Offset(sx, sy), 1.5, sp);
      }
      canvas.drawCircle(Offset(size.width * 0.82, 64), 24,
          Paint()..color = const Color(0xFFF4F1DE));
      canvas.drawCircle(Offset(size.width * 0.82 - 9, 58), 20, Paint()..color = sky);
    } else {
      canvas.drawCircle(Offset(size.width * 0.82, 70), 28,
          Paint()..color = const Color(0xFFFFD93D));
      canvas.drawCircle(Offset(size.width * 0.82, 70), 36,
          Paint()..color = const Color(0xFFFFD93D).withValues(alpha: 0.25));
    }

    // parallax hills
    for (int layer = 0; layer < 2; layer++) {
      final col = layer == 0 ? theme.hillFar : theme.hillNear;
      final off = (e.dist * (0.12 + layer * 0.22)) % 340;
      for (int i = -1; i < size.width / 340 + 1; i++) {
        final hx = i * 340 - off + layer * 130;
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(hx, gY), width: 320, height: 200 - layer * 55),
          pi,
          pi,
          true,
          Paint()..color = col.withValues(alpha: 0.85 - layer * 0.2),
        );
      }
      // pine silhouettes on the near layer
      if (layer == 1) {
        final tp = Paint()..color = theme.hillNear;
        for (int i = 0; i < size.width / 170 + 2; i++) {
          final tx = i * 170 - (e.dist * 0.34) % 170;
          final th = 46.0 + (i * 37 % 30);
          final path = Path()
            ..moveTo(tx, gY - 60 - th)
            ..lineTo(tx - 16, gY - 60)
            ..lineTo(tx + 16, gY - 60)
            ..close();
          canvas.drawPath(path, tp);
        }
      }
    }

    // ground
    canvas.drawRect(Rect.fromLTWH(0, gY, size.width, size.height - gY),
        Paint()..color = theme.ground);
    canvas.drawRect(Rect.fromLTWH(0, gY, size.width, 6),
        Paint()..color = theme.groundLine);
    // shadow under the ground lip for depth
    canvas.drawRect(Rect.fromLTWH(0, gY + 6, size.width, 5),
        Paint()..color = Colors.black.withValues(alpha: 0.25));

    // moving ground texture: pebbles + grass tufts
    final soff = e.dist % 110;
    for (double sx = -soff; sx < size.width; sx += 110) {
      final h1 = (sx * 13.7).abs() % 40;
      canvas.drawCircle(Offset(sx + h1, gY + 26 + (h1 % 18)),
          3.2, Paint()..color = Colors.black.withValues(alpha: 0.18));
      // grass tuft
      final gp = Paint()
        ..color = theme.hillNear
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      final gx = sx + 60 + (h1 % 25);
      canvas.drawLine(Offset(gx, gY + 30), Offset(gx - 5, gY + 18), gp);
      canvas.drawLine(Offset(gx + 4, gY + 30), Offset(gx + 7, gY + 16), gp);
    }

    // coins: spinning gold discs with physical glint
    for (final c in e.coinsList) {
      final cy = gY - c.y + sin(e.time * 6 + c.x * 0.05) * 5;
      final squash = (sin(e.time * 5 + c.x * 0.1) * 0.35 + 0.65).abs();
      final w = 13 * (0.45 + 0.55 * squash);
      canvas.drawOval(Rect.fromCenter(center: Offset(c.x, cy), width: w * 2, height: 26),
          Paint()..color = theme.coinOuter);
      canvas.drawOval(Rect.fromCenter(center: Offset(c.x, cy), width: w * 2, height: 26),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFF8A6D1A)
            ..strokeWidth = 3);
      canvas.drawOval(Rect.fromCenter(center: Offset(c.x - 3, cy - 3), width: w, height: 13),
          Paint()..color = Colors.white.withValues(alpha: 0.55));
    }

    // obstacles
    for (final o in e.obstacles) {
      _drawObstacle(canvas, o);
    }

    // runner
    _drawRunner(canvas, size);
  }

  void _drawObstacle(Canvas canvas, Obstacle o) {
    final e = engine;
    final d = e.dimsOf(o);
    final w = d.$1, h = d.$2, top = d.$3;
    final main = Paint()..color = obstacles.main;
    final darkP = Paint()..color = obstacles.dark;
    final lightP = Paint()..color = obstacles.light;

    switch (o.kind) {
      case ObstacleKind.flyer:
        final bx = o.x + w / 2;
        final by = top + h / 2;
        final flap = sin(e.time * 14) * 13;
        final bp = Paint()..color = theme.flyer;
        canvas.drawOval(
            Rect.fromCenter(center: Offset(bx - 16, by + 6), width: 28, height: 13 + flap), bp);
        canvas.drawOval(
            Rect.fromCenter(center: Offset(bx + 16, by + 6), width: 28, height: 13 - flap), bp);
        canvas.drawOval(Rect.fromCenter(center: Offset(bx, by + 14), width: 50, height: 28), bp);
        canvas.drawCircle(Offset(bx + 8, by + 9), 4,
            Paint()..color = Colors.white);
        canvas.drawCircle(Offset(bx + 9, by + 9), 2,
            Paint()..color = Colors.black);
        final beak = Path()
          ..moveTo(bx + 24, by + 11)
          ..lineTo(bx + 34, by + 15)
          ..lineTo(bx + 24, by + 19)
          ..close();
        canvas.drawPath(beak, Paint()..color = const Color(0xFFE8A33D));
      case ObstacleKind.crate:
      case ObstacleKind.tallCrate:
        final segs = o.kind == ObstacleKind.tallCrate ? 2 : 1;
        final sh = h / segs;
        for (int s = 0; s < segs; s++) {
          final sy = top + s * sh;
          if (obstacles.id == 'ice') {
            final r = RRect.fromLTRBR(o.x, sy, o.x + w, sy + sh, const Radius.circular(6));
            canvas.drawRRect(r, main);
            canvas.drawRRect(r, Paint()
              ..style = PaintingStyle.stroke
              ..color = obstacles.dark
              ..strokeWidth = 3);
            canvas.drawLine(Offset(o.x + 8, sy + 8), Offset(o.x + w - 12, sy + sh - 8),
                Paint()..color = Colors.white.withValues(alpha: 0.6)..strokeWidth = 4);
          } else if (obstacles.id == 'cones') {
            final path = Path()
              ..moveTo(o.x + w / 2, sy)
              ..lineTo(o.x + 6, sy + sh)
              ..lineTo(o.x + w - 6, sy + sh)
              ..close();
            canvas.drawPath(path, main);
            canvas.drawRect(Rect.fromLTWH(o.x + 10, sy + sh * 0.55, w - 20, sh * 0.16),
                Paint()..color = Colors.white);
            canvas.drawRect(Rect.fromLTWH(o.x, sy + sh - 4, w, 4), darkP);
          } else if (obstacles.id == 'barrels') {
            final r = RRect.fromLTRBR(o.x, sy, o.x + w, sy + sh, const Radius.circular(10));
            canvas.drawRRect(r, main);
            canvas.drawRRect(r, Paint()
              ..style = PaintingStyle.stroke
              ..color = obstacles.dark
              ..strokeWidth = 3);
            for (final fy in [0.3, 0.7]) {
              canvas.drawLine(Offset(o.x + 3, sy + sh * fy), Offset(o.x + w - 3, sy + sh * fy),
                  Paint()..color = obstacles.dark..strokeWidth = 4);
            }
            canvas.drawLine(Offset(o.x + w / 2, sy + 4), Offset(o.x + w / 2, sy + sh - 4),
                Paint()..color = obstacles.light..strokeWidth = 2);
          } else if (obstacles.id == 'totems') {
            final r = RRect.fromLTRBR(o.x + 8, sy, o.x + w - 8, sy + sh, const Radius.circular(8));
            canvas.drawRRect(r, main);
            canvas.drawCircle(Offset(o.x + w / 2, sy + sh * 0.3), 7, darkP);
            canvas.drawCircle(Offset(o.x + w / 2, sy + sh * 0.3), 3.4, lightP);
            canvas.drawLine(Offset(o.x + 14, sy + sh * 0.62), Offset(o.x + w - 14, sy + sh * 0.62),
                darkP..strokeWidth = 5);
          } else {
            // default wooden crate look
            final r = RRect.fromLTRBR(o.x, sy, o.x + w, sy + sh, const Radius.circular(6));
            canvas.drawRRect(r, main);
            canvas.drawRRect(r, Paint()
              ..style = PaintingStyle.stroke
              ..color = obstacles.dark
              ..strokeWidth = 3);
            canvas.drawLine(Offset(o.x, sy + sh / 2), Offset(o.x + w, sy + sh / 2),
                Paint()..color = obstacles.dark..strokeWidth = 3);
            canvas.drawLine(Offset(o.x + w / 2, sy), Offset(o.x + w / 2, sy + sh),
                Paint()..color = obstacles.dark..strokeWidth = 3);
            canvas.drawLine(Offset(o.x + 6, sy + 6), Offset(o.x + 18, sy + 6),
                Paint()..color = obstacles.light..strokeWidth = 3);
          }
          // drop shadow under each segment
          canvas.drawRect(Rect.fromLTWH(o.x + 4, sy + sh - 2, w - 8, 3),
              Paint()..color = Colors.black.withValues(alpha: 0.25));
        }
      case ObstacleKind.boulder:
        final cx = o.x + w / 2, cy = top + h / 2;
        canvas.drawOval(Rect.fromCenter(center: Offset(cx + 4, top + h - 2), width: w, height: 10),
            Paint()..color = Colors.black.withValues(alpha: 0.3));
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: w, height: h), main);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx - 9, cy - 9), width: w * 0.55, height: h * 0.5),
            lightP..color = obstacles.light.withValues(alpha: 0.7));
        canvas.drawArc(Rect.fromCenter(center: Offset(cx, cy), width: w * 0.8, height: h * 0.8),
            0.4, 1.4, false, Paint()..color = obstacles.dark..style = PaintingStyle.stroke..strokeWidth = 3);
      case ObstacleKind.cactus:
        final cx = o.x + w / 2;
        if (obstacles.id == 'brambles') {
          // thorn bush: dark spiky mass
          final bp = Paint()..color = obstacles.main;
          for (int i = 0; i < 7; i++) {
            final a = pi + i * pi / 6;
            final bx = cx + cos(a) * w * 0.32;
            final byy = top + h - 6 + sin(a) * h * 0.42;
            canvas.drawLine(Offset(cx, top + h), Offset(bx, byy),
                Paint()..color = obstacles.main..strokeWidth = 9..strokeCap = StrokeCap.round);
          }
          canvas.drawCircle(Offset(cx, top + h * 0.45), w * 0.34, bp);
          canvas.drawCircle(Offset(cx - 6, top + h * 0.38), 4, lightP);
        } else {
          final cp = Paint()..color = obstacles.main..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(cx, top + h), Offset(cx, top + 8),
              cp..strokeWidth = 22);
          canvas.drawLine(Offset(cx, top + h * 0.55), Offset(cx - 14, top + h * 0.55),
              cp..strokeWidth = 13);
          canvas.drawLine(Offset(cx - 14, top + h * 0.55), Offset(cx - 14, top + h * 0.3),
              cp..strokeWidth = 13);
          canvas.drawLine(Offset(cx, top + h * 0.4), Offset(cx + 14, top + h * 0.4),
              cp..strokeWidth = 13);
          canvas.drawLine(Offset(cx + 14, top + h * 0.4), Offset(cx + 14, top + h * 0.18),
              cp..strokeWidth = 13);
          canvas.drawLine(Offset(cx - 4, top + 12), Offset(cx - 4, top + h - 6),
              Paint()..color = obstacles.light..strokeWidth = 3);
        }
    }
  }

  void _drawRunner(Canvas canvas, Size size) {
    final e = engine;
    final gY = e.groundY;
    final px = e.playerX;
    final sliding = e.sliding;
    final pH = sliding ? 36.0 : 64.0;
    final pTop = gY - e.y - pH;

    canvas.save();
    if (e.phase == DashPhase.crashed) {
      // death tumble: tip forward and spin while flashing
      final t = (e.crashT / 1.1).clamp(0.0, 1.0);
      canvas.translate(px + 22, pTop + pH / 2);
      canvas.rotate(t * 2.6);
      canvas.translate(-(px + 22), -(pTop + pH / 2));
    }

    final bodyP = Paint()..color = runner.body;
    final trimP = Paint()..color = runner.trim;
    final skinP = Paint()..color = runner.skin;

    if (sliding) {
      // low slide: body horizontal, dust kicking up
      final r = RRect.fromLTRBR(px, pTop, px + 52, pTop + pH, const Radius.circular(16));
      canvas.drawRRect(r, bodyP);
      canvas.drawCircle(Offset(px + 42, pTop + 12), 9, skinP); // head
      canvas.drawRRect(RRect.fromLTRBR(px + 34, pTop + 5, px + 52, pTop + 12, const Radius.circular(4)),
          trimP); // cap
      // dust puffs
      final dp = Paint()..color = Colors.brown.withValues(alpha: 0.5);
      for (int i = 0; i < 3; i++) {
        final dx = px - 8 - ((e.time * 160 + i * 26) % 60);
        canvas.drawCircle(Offset(dx, gY - 6 - i * 5), 7 - i * 1.6, dp);
      }
      // speed lines
      final slp = Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = 3;
      for (int i = 0; i < 3; i++) {
        canvas.drawLine(Offset(px - 12, pTop + 8 + i * 10),
            Offset(px - 38, pTop + 8 + i * 10), slp);
      }
    } else {
      // upright runner with real leg swing
      final r = RRect.fromLTRBR(px + 4, pTop + 18, px + 40, pTop + pH, const Radius.circular(14));
      canvas.drawRRect(r, bodyP);
      // jacket stripe
      canvas.drawRect(Rect.fromLTWH(px + 4, pTop + 34, 36, 6), trimP);
      // head + cap
      canvas.drawCircle(Offset(px + 22, pTop + 10), 11, skinP);
      canvas.drawRRect(RRect.fromLTRBR(px + 10, pTop - 2, px + 36, pTop + 8, const Radius.circular(5)),
          trimP);
      canvas.drawRect(Rect.fromLTWH(px + 32, pTop + 4, 12, 4), trimP); // cap brim
      // visor-less determined eye
      canvas.drawCircle(Offset(px + 27, pTop + 11), 2.2, Paint()..color = Colors.black87);
      // arms pumping
      final swing = e.y > 0.5 ? 0.4 : sin(e.time * 20) * 0.9;
      final ap = Paint()
        ..color = runner.body
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(px + 10, pTop + 26),
          Offset(px + 10 + swing * 14, pTop + 42), ap);
      canvas.drawLine(Offset(px + 34, pTop + 26),
          Offset(px + 34 - swing * 14, pTop + 42), ap);
      // legs
      final lp = Paint()
        ..color = runner.trim
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round;
      if (e.y > 0.5) {
        // tucked jump pose
        canvas.drawLine(Offset(px + 14, pTop + pH), Offset(px + 4, pTop + pH + 14), lp);
        canvas.drawLine(Offset(px + 30, pTop + pH), Offset(px + 40, pTop + pH + 8), lp);
      } else {
        final legSwing = sin(e.time * 20) * 11;
        canvas.drawLine(Offset(px + 15, pTop + pH),
            Offset(px + 15 + legSwing, gY + 18), lp);
        canvas.drawLine(Offset(px + 29, pTop + pH),
            Offset(px + 29 - legSwing, gY + 18), lp);
      }
    }
    // soft contact shadow
    final shScale = (1 - (e.y / 420).clamp(0.0, 0.6));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(px + 22, gY + 6), width: 56 * shScale, height: 10),
        Paint()..color = Colors.black.withValues(alpha: 0.3 * shScale));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RunnerPainter old) => true;
}
