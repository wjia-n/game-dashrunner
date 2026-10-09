import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/runner_themes.dart';

/// Persisted settings + profile + stats for Dash Runner. Survives restarts.
///
/// The whole player profile is ONE JSON string ([_kProfile]) — order-safe and
/// atomic. Never use setStringList for ordered data: Android stores it as an
/// unordered StringSet and scrambles order on restart.
///
/// Legacy keys from the old build (dashrunner_best) are migrated once and
/// then removed.
class DashSettings extends ChangeNotifier {
  // The WHOLE player profile is ONE order-preserving JSON string stored via
  // setString. NEVER use setStringList for ordered data: Android backs it with
  // an unordered StringSet and scrambles order on restart.
  static const _kProfile = 'dashrunner_player_names_json';
  static const _kLegacyProfile = 'dashrunner_profile_json';
  static const _kLegacyBest = 'dashrunner_best';

  static const String defaultName = 'Runner';

  /// Custom theme colors (ARGB ints). Defaults mirror Meadow Dawn.
  static const Map<String, int> defaultCustomColors = {
    'skyDay': 0xFF8FD3F4,
    'skyDusk': 0xFFFFB37E,
    'skyNight': 0xFF16233F,
    'hillFar': 0xFF7FB069,
    'hillNear': 0xFF5B8E4A,
    'ground': 0xFF4A7C44,
    'groundLine': 0xFFE8B54D,
    'accent': 0xFFE8B54D,
    'coin': 0xFFFFD93D,
  };

  String playerName = defaultName;
  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String themeId = 'meadow';
  String runnerStyleId = 'ember';
  String obstacleStyleId = 'crates';
  String modeId = 'trail';
  bool isPro = false;

  Map<String, int> customColors = Map.of(defaultCustomColors);

  /// Best score per mode id.
  Map<String, int> bestScore = {'chill': 0, 'trail': 0, 'extreme': 0, 'score': 0};

  /// Best distance (m) per mode id.
  Map<String, int> bestDist = {'chill': 0, 'trail': 0, 'extreme': 0, 'score': 0};

  int totalCoins = 0;
  int gamesPlayed = 0;

  SharedPreferences? _prefs;

  RunnerThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return RunnerThemeDef(
      id: 'custom',
      name: 'My Trail',
      skyDay: c('skyDay'),
      skyDusk: c('skyDusk'),
      skyNight: c('skyNight'),
      hillFar: c('hillFar'),
      hillNear: c('hillNear'),
      ground: c('ground'),
      groundLine: c('groundLine'),
      stripe: const Color(0xFFFFFFFF),
      accent: c('accent'),
      coinOuter: c('coin'),
      flyer: const Color(0xFF6D4C41),
    );
  }

  RunnerThemeDef get theme =>
      RunnerThemes.byId(themeId, custom: customTheme);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;

    final raw = p.getString(_kProfile);
    if (raw != null) {
      _fromJson(raw);
    } else if (p.containsKey(_kLegacyProfile)) {
      // One-time migration from the interrupted earlier build's key.
      _fromJson(p.getString(_kLegacyProfile) ?? '');
      await p.remove(_kLegacyProfile);
      await _save();
    }

    // One-time legacy migration: the old build stored the best distance in
    // a bare int key. Fold it into the new per-mode table, then drop it.
    if (p.containsKey(_kLegacyBest)) {
      final legacy = p.getInt(_kLegacyBest) ?? 0;
      if (legacy > (bestDist['trail'] ?? 0)) {
        bestDist['trail'] = legacy;
        bestScore['trail'] = max(bestScore['trail'] ?? 0, legacy);
      }
      await p.remove(_kLegacyBest);
    }

    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Map<String, dynamic> _toJsonMap() => {
        'name': playerName,
        'musicOn': musicOn,
        'sfxOn': sfxOn,
        'volume': volume,
        'themeId': themeId,
        'runnerStyleId': runnerStyleId,
        'obstacleStyleId': obstacleStyleId,
        'modeId': modeId,
        'isPro': isPro,
        'customColors': customColors.map((k, v) => MapEntry(k, v)),
        'bestScore': bestScore,
        'bestDist': bestDist,
        'totalCoins': totalCoins,
        'gamesPlayed': gamesPlayed,
      };

  void _fromJson(String raw) {
    try {
      final d = jsonDecode(raw);
      if (d is! Map) return;
      String s(String k, String fb) =>
          d[k] is String && (d[k] as String).isNotEmpty ? d[k] : fb;
      playerName = s('name', defaultName);
      musicOn = d['musicOn'] is bool ? d['musicOn'] : true;
      sfxOn = d['sfxOn'] is bool ? d['sfxOn'] : true;
      volume = d['volume'] is num ? (d['volume'] as num).toDouble().clamp(0, 1) : 0.8;
      themeId = s('themeId', 'meadow');
      runnerStyleId = s('runnerStyleId', 'ember');
      obstacleStyleId = s('obstacleStyleId', 'crates');
      modeId = s('modeId', 'trail');
      isPro = d['isPro'] == true;
      if (d['customColors'] is Map) {
        for (final k in defaultCustomColors.keys) {
          final v = (d['customColors'] as Map)[k];
          customColors[k] = v is int ? v : defaultCustomColors[k]!;
        }
      }
      for (final k in ['chill', 'trail', 'extreme', 'score']) {
        if (d['bestScore'] is Map && (d['bestScore'] as Map)[k] is int) {
          bestScore[k] = (d['bestScore'] as Map)[k] as int;
        }
        if (d['bestDist'] is Map && (d['bestDist'] as Map)[k] is int) {
          bestDist[k] = (d['bestDist'] as Map)[k] as int;
        }
      }
      totalCoins = d['totalCoins'] is int ? d['totalCoins'] : 0;
      gamesPlayed = d['gamesPlayed'] is int ? d['gamesPlayed'] : 0;
    } catch (_) {
      // Corrupt profile: fall back to defaults rather than crash.
    }
  }

  // Serialized save queue: keystroke-fast saves never interleave or clobber.
  Future<void> _pending = Future.value();
  Future<void> _save() {
    _pending = _pending.then((_) async {
      final p = _prefs;
      if (p == null) return;
      await p.setString(_kProfile, jsonEncode(_toJsonMap()));
    });
    return _pending;
  }

  /// Free-tier limits: clamp pro-only choices when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || RunnerThemes.isProTheme(themeId)) {
      themeId = 'meadow';
      changed = true;
    }
    if (RunnerStyles.isPro(runnerStyleId)) {
      runnerStyleId = 'ember';
      changed = true;
    }
    if (ObstacleStyles.isPro(obstacleStyleId)) {
      obstacleStyleId = 'crates';
      changed = true;
    }
    if (modeId == 'extreme') {
      modeId = 'trail';
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(String v) async {
    final clean = v.trim();
    playerName = clean.isEmpty ? defaultName : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || RunnerThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setRunnerStyle(String id) async {
    if (!isPro && RunnerStyles.isPro(id)) return;
    runnerStyleId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setObstacleStyle(String id) async {
    if (!isPro && ObstacleStyles.isPro(id)) return;
    obstacleStyleId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setMode(String id) async {
    if (!isPro && id == 'extreme') return; // Extreme is a Pro mode
    modeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is Pro
    if (!defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(defaultCustomColors);
    notifyListeners();
    await _save();
  }

  /// Record a finished run. Returns true if a new best score was set.
  Future<bool> recordRun({
    required String modeId,
    required int score,
    required int distance,
    required int coins,
  }) async {
    gamesPlayed++;
    totalCoins += coins;
    var isBest = false;
    if (score > (bestScore[modeId] ?? 0)) {
      bestScore[modeId] = score;
      isBest = true;
    }
    if (distance > (bestDist[modeId] ?? 0)) {
      bestDist[modeId] = distance;
      isBest = true;
    }
    notifyListeners();
    await _save();
    return isBest;
  }

  int max(int a, int b) => a > b ? a : b;
}
