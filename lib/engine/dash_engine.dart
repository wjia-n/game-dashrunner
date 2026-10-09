import 'dart:async';
import 'dart:math';

/// Dash Runner engine — the engine owns ALL run state and ALL phases.
///
/// Phases:
///  - [ready]:     waiting for the player to tap start. Only forward action: start().
///  - [countdown]: 3-2-1 owned by engine time (stepped by the ticker). Auto -> running.
///  - [running]:   live physics. jump()/slide() accepted here.
///  - [paused]:    world frozen by app lifecycle or pause button. resume() only.
///  - [crashed]:   death animation owned by engine timer (1.1s). Auto -> over.
///  - [over]:      terminal. restart() or toMenu() only.
///
/// Watchdog: a 250ms periodic timer audits every phase. Any phase found
/// without a live liveness timestamp past its budget is force-recovered:
/// a stalled countdown finishes instantly, a crashed run that never reached
/// [over] is completed, a [running] phase that stops receiving step() calls
/// (e.g. a frozen ticker) has its clock resynced so the world never freezes
/// or jumps. Stuck states are impossible by construction.
///
/// The UI never mutates game state directly; it renders [snapshot] and calls
/// the input methods. All scoring is emitted as [DashEvent]s so every point
/// has a visible, narrated cause — no silent scoring.
enum DashPhase { ready, countdown, running, paused, crashed, over }

/// Game modes with difficulty-owned tuning.
enum DashMode { chill, trail, extreme, scoreAttack }

extension DashModeInfo on DashMode {
  String get id {
    switch (this) {
      case DashMode.chill:
        return 'chill';
      case DashMode.trail:
        return 'trail';
      case DashMode.extreme:
        return 'extreme';
      case DashMode.scoreAttack:
        return 'score';
    }
  }

  String get name {
    switch (this) {
      case DashMode.chill:
        return 'Chill Dash';
      case DashMode.trail:
        return 'Trail Run';
      case DashMode.extreme:
        return 'Extreme Dash';
      case DashMode.scoreAttack:
        return 'Score Attack';
    }
  }

  String get blurb {
    switch (this) {
      case DashMode.chill:
        return 'Gentle pace, simple trail. Learn the ropes.';
      case DashMode.trail:
        return 'The classic run — speed and traffic keep rising.';
      case DashMode.extreme:
        return 'Blistering speed, dense obstacles. Pro only.';
      case DashMode.scoreAttack:
        return '90 seconds. Max distance + coins. Go!';
    }
  }

  double get baseSpeed {
    switch (this) {
      case DashMode.chill:
        return 280;
      case DashMode.trail:
        return 340;
      case DashMode.extreme:
        return 420;
      case DashMode.scoreAttack:
        return 340;
    }
  }

  double get maxSpeed {
    switch (this) {
      case DashMode.chill:
        return 620;
      case DashMode.trail:
        return 900;
      case DashMode.extreme:
        return 1080;
      case DashMode.scoreAttack:
        return 900;
    }
  }

  double get spawnBase {
    switch (this) {
      case DashMode.chill:
        return 1.45;
      case DashMode.trail:
        return 1.2;
      case DashMode.extreme:
        return 0.95;
      case DashMode.scoreAttack:
        return 1.2;
    }
  }

  double get spawnMin {
    switch (this) {
      case DashMode.chill:
        return 0.8;
      case DashMode.trail:
        return 0.55;
      case DashMode.extreme:
        return 0.4;
      case DashMode.scoreAttack:
        return 0.55;
    }
  }

  static DashMode fromId(String id) {
    for (final m in DashMode.values) {
      if (m.id == id) return m;
    }
    return DashMode.trail;
  }
}

enum ObstacleKind { crate, tallCrate, boulder, cactus, flyer }

/// A scored event — every point in the run has a narrated cause.
enum DashEventKind {
  jump,
  slide,
  land,
  coin,
  nearMiss,
  milestone,
  crash,
  finished,
}

class DashEvent {
  final DashEventKind kind;
  final String narration;
  final int points;
  DashEvent(this.kind, this.narration, this.points);
}

class Obstacle {
  double x;
  final ObstacleKind kind;
  double bob = 0;
  bool counted = false; // near-miss evaluated once it passes the player
  Obstacle(this.x, this.kind);
}

class Coin {
  double x, y;
  bool taken = false;
  Coin(this.x, this.y);
}

/// Immutable-ish per-frame snapshot for the painter. The engine mutates its
/// internals; the UI reads these fields only.
class DashEngine {
  final DashMode mode;
  final Random _rng;

  DashPhase phase = DashPhase.ready;
  final List<DashEvent> _events = [];
  void Function(DashEvent)? onEvent;
  void Function(DashPhase)? onPhase;

  // Player physics
  double y = 0; // height above ground (px)
  double vy = 0;
  bool sliding = false;
  double slideT = 0;
  double crashT = 0; // death-animation clock

  // Run progress
  double dist = 0; // meters
  double speed = 0;
  int coins = 0;
  int nearMisses = 0;
  int milestoneBonus = 0;
  int milestones = 0;
  double time = 0;
  double scoreAttackT = 90; // seconds remaining in score attack
  int _nextMilestone = 500;

  final List<Obstacle> obstacles = [];
  final List<Coin> coinsList = [];
  double _spawnT = 1.0;

  double countdownT = 0;
  DateTime _lastStep = DateTime.now();
  Timer? _watchdog;

  // View metrics, set by the UI before stepping.
  double viewW = 800;
  double viewH = 600;

  DashEngine({required this.mode, int? seed})
      : _rng = Random(seed ?? DateTime.now().microsecondsSinceEpoch) {
    _watchdog = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _audit();
    });
  }

  double get groundY => viewH * 0.78;
  double get playerX => viewW * 0.28;

  int get score =>
      dist.toInt() + coins * 10 + nearMisses * 5 + milestoneBonus;

  void _setPhase(DashPhase p) {
    if (phase == p) return;
    phase = p;
    _lastStep = DateTime.now();
    onPhase?.call(p);
  }

  void _emit(DashEventKind kind, String narration, int points) {
    final e = DashEvent(kind, narration, points);
    _events.add(e);
    onEvent?.call(e);
  }

  /// Watchdog: recover any phase found without liveness.
  void _audit() {
    final now = DateTime.now();
    final silent = now.difference(_lastStep);
    switch (phase) {
      case DashPhase.ready:
      case DashPhase.paused:
      case DashPhase.over:
        return; // stable states, nothing to recover
      case DashPhase.countdown:
        if (silent.inMilliseconds > 1500) {
          // Ticker died mid-countdown: finish it now.
          countdownT = 0;
          _setPhase(DashPhase.running);
        }
      case DashPhase.running:
        if (silent.inMilliseconds > 900) {
          // step() stopped arriving (frozen ticker): resync the clock so the
          // world continues instead of freezing or teleporting.
          _lastStep = now;
        }
      case DashPhase.crashed:
        if (silent.inMilliseconds > 2000) {
          // Death animation never completed: force the run over.
          _finish();
        }
    }
  }

  // ------------------------------------------------------------ inputs
  void start() {
    if (phase != DashPhase.ready) return;
    countdownT = 3.0;
    _setPhase(DashPhase.countdown);
    _emit(DashEventKind.finished, 'Ready…', 0);
  }

  void jump() {
    if (phase != DashPhase.running) return;
    if (y > 0.5) return; // already airborne: no double jump
    sliding = false;
    slideT = 0;
    vy = 1000;
    y = 0.1;
    _emit(DashEventKind.jump, 'Jump!', 0);
  }

  void slide() {
    if (phase != DashPhase.running) return;
    if (y > 4) return; // can't slide mid-air
    if (sliding) return;
    sliding = true;
    slideT = 0.65;
    _emit(DashEventKind.slide, 'Slide!', 0);
  }

  void pause() {
    if (phase != DashPhase.running) return;
    _setPhase(DashPhase.paused);
  }

  void resume() {
    if (phase != DashPhase.paused) return;
    _setPhase(DashPhase.running);
  }

  /// Restart from [over] or [crashed]: full reset back to ready.
  void restart() {
    if (phase != DashPhase.over && phase != DashPhase.crashed) return;
    _reset();
    _setPhase(DashPhase.ready);
  }

  void _reset() {
    y = 0;
    vy = 0;
    sliding = false;
    slideT = 0;
    crashT = 0;
    dist = 0;
    speed = mode.baseSpeed;
    coins = 0;
    nearMisses = 0;
    milestoneBonus = 0;
    milestones = 0;
    time = 0;
    scoreAttackT = 90;
    _nextMilestone = 500;
    obstacles.clear();
    coinsList.clear();
    _spawnT = 1.0;
    countdownT = 0;
  }

  // ------------------------------------------------------------- stepping
  void step(double dt) {
    _lastStep = DateTime.now();
    dt = dt.clamp(0.0, 0.05);
    switch (phase) {
      case DashPhase.ready:
      case DashPhase.paused:
      case DashPhase.over:
        return;
      case DashPhase.countdown:
        countdownT -= dt;
        if (countdownT <= 0) {
          _setPhase(DashPhase.running);
          _emit(DashEventKind.finished, 'GO!', 0);
        }
        return;
      case DashPhase.crashed:
        crashT += dt;
        // world keeps drifting during the death tumble
        for (final o in obstacles) {
          o.x -= speed * dt * 0.25;
        }
        if (crashT >= 1.1) _finish();
        return;
      case DashPhase.running:
        _stepRunning(dt);
    }
  }

  void _stepRunning(double dt) {
    time += dt;
    speed = (mode.baseSpeed + min(dist / 40, mode.maxSpeed - mode.baseSpeed))
        .clamp(mode.baseSpeed, mode.maxSpeed);
    dist += speed * dt;

    if (mode == DashMode.scoreAttack) {
      scoreAttackT -= dt;
      if (scoreAttackT <= 0) {
        scoreAttackT = 0;
        _finish(); // time up — clean finish, no crash
        return;
      }
    }

    // milestones: visible progress, every 500 m
    if (dist >= _nextMilestone) {
      milestoneBonus += 25;
      milestones++;
      _emit(DashEventKind.milestone, '$_nextMilestone m!  +25', 25);
      _nextMilestone += 500;
    }

    // player physics
    final wasAirborne = y > 0.5;
    if (y > 0 || vy != 0) {
      vy -= 2700 * dt;
      y += vy * dt;
      if (y <= 0) {
        y = 0;
        vy = 0;
        if (wasAirborne) _emit(DashEventKind.land, 'Landed', 0);
      }
    }
    if (sliding) {
      slideT -= dt;
      if (slideT <= 0) sliding = false;
    }

    // spawn obstacles
    _spawnT -= dt;
    if (_spawnT <= 0) {
      _spawnT = max(mode.spawnMin, mode.spawnBase - dist / 6000) *
          (0.8 + _rng.nextDouble() * 0.5);
      obstacles.add(Obstacle(viewW + 60, _pickKind()));
      if (_rng.nextDouble() < 0.6) {
        final baseY = _rng.nextDouble() < 0.5 ? 135.0 : 45.0;
        for (int i = 0; i < 5; i++) {
          coinsList.add(
              Coin(viewW + 80 + i * 44, baseY - sin(i / 4 * pi) * 50));
        }
      }
    }

    final px = playerX;
    const pW = 44.0;
    final pH = sliding ? 34.0 : 62.0;
    final pTop = groundY - y - pH;

    for (final o in obstacles) {
      o.x -= speed * dt;
      if (o.kind == ObstacleKind.flyer) o.bob += dt * 6;
      // near-miss: passed the player with a tight margin, once each
      if (!o.counted && o.x + 60 < px) {
        o.counted = true;
        if (_tight(o, pTop, pH, px, pW)) {
          nearMisses++;
          _emit(DashEventKind.nearMiss, 'Close one! +5', 5);
        }
      }
    }
    obstacles.removeWhere((o) => o.x < -90);

    for (final o in obstacles) {
      final d = _dims(o);
      final overlap = o.x < px + pW - 10 &&
          o.x + d.$1 > px + 10 &&
          pTop < d.$3 + d.$2 &&
          pTop + pH > d.$3 + 8;
      if (overlap) {
        _crash();
        return;
      }
    }

    for (final c in coinsList) {
      c.x -= speed * dt;
      if (!c.taken &&
          c.x > px - 12 &&
          c.x < px + pW + 12 &&
          (groundY - c.y) > y - 45 &&
          (groundY - c.y) < y + pH + 45) {
        c.taken = true;
        coins++;
        _emit(DashEventKind.coin, '+10', 10);
      }
    }
    coinsList.removeWhere((c) => c.x < -40 || c.taken);
  }

  /// True when the obstacle passed with < 26px clearance — a genuine near miss.
  bool _tight(Obstacle o, double pTop, double pH, double px, double pW) {
    final d = _dims(o);
    final verticalGap =
        min((pTop + pH - d.$3).abs(), (pTop - (d.$3 + d.$2)).abs());
    return verticalGap < 30;
  }

  ObstacleKind _pickKind() {
    final r = _rng.nextDouble();
    if (r < 0.36) return ObstacleKind.crate;
    if (r < 0.58) return ObstacleKind.tallCrate;
    if (r < 0.72) return ObstacleKind.boulder;
    if (r < 0.84) return ObstacleKind.cactus;
    if (dist > 250 || mode == DashMode.extreme) return ObstacleKind.flyer;
    return ObstacleKind.crate;
  }

  /// (width, height, top offset above ground) for the painter & collision.
  (double, double, double) dimsOf(Obstacle o) => _dims(o);

  (double, double, double) _dims(Obstacle o) {
    final g = groundY;
    switch (o.kind) {
      case ObstacleKind.crate:
        return (46, 46, g - 46);
      case ObstacleKind.tallCrate:
        return (46, 88, g - 88);
      case ObstacleKind.boulder:
        return (56, 52, g - 52);
      case ObstacleKind.cactus:
        return (40, 76, g - 76);
      case ObstacleKind.flyer:
        return (52, 36, g - 120 + sin(o.bob) * 12);
    }
  }

  void _crash() {
    if (phase != DashPhase.running) return;
    crashT = 0;
    _setPhase(DashPhase.crashed);
    _emit(DashEventKind.crash, 'Crash!', 0);
  }

  void _finish() {
    if (phase == DashPhase.over) return;
    _setPhase(DashPhase.over);
    _emit(DashEventKind.finished, 'Run over — $score pts', 0);
  }

  void dispose() {
    _watchdog?.cancel();
    _watchdog = null;
  }
}
