import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Dash Runner — all sounds synthesized in code as WAV
/// bytes. No asset files. Earthy, outdoorsy, physical sounds: whooshing
/// jumps, soft trail thuds, bright coin dings.
///
/// Reliability design (same as the Ludo exemplar):
/// - Music clips are synthesized ONCE and cached.
/// - A [_musicGen] generation counter serializes track changes so overlapping
///   requests (menu in/out, pause/resume, toggles) can never desync music.
/// - Lifecycle uses pause()/resume() so interruptions resume in place.
/// - Every public method catches player errors; audio can never crash the app.
class DashAudio {
  /// Per-game pitch character (dashrunner): 1.00x. Makes SFX unique.
  static const double _pitchMul = 1.000;

  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  final Map<String, Uint8List> _cache = {};

  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  DashAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.5 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    freq *= _pitchMul;
    freqEnd *= _pitchMul;
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  /// Filtered-noise whoosh (jump up / slide swoosh / near-miss rush).
  List<double> _whoosh(double secs, {bool up = true}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    double last = 0;
    for (int i = 0; i < n; i++) {
      final t = i / n;
      final target = 0.15 + 0.75 * (up ? t : 1 - t);
      last += (target - last) * 0.06;
      out[i] = _env(i, n, attack: 0.08) *
          ((_rand.nextDouble() * 2 - 1) * last +
              0.2 * sin(2 * pi * (300 + 500 * t) * (i / _rate)));
    }
    return out;
  }

  /// Soft trail thud: low sine burst + dust noise.
  List<double> _thud(double freq) {
    final n = (_rate * 0.16).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (0.85 * sin(2 * pi * freq * t) * exp(-t * 28) +
              0.2 * (_rand.nextDouble() * 2 - 1) * exp(-t * 90));
    }
    return out;
  }

  /// Crash: heavy wooden smash.
  List<double> _crashSfx() {
    final n = (_rate * 0.5).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.003) *
          (0.9 * sin(2 * pi * 95 * t) * exp(-t * 14) +
              0.5 * sin(2 * pi * 240 * t) * exp(-t * 30) +
              0.4 * (_rand.nextDouble() * 2 - 1) * exp(-t * 22));
    }
    return out;
  }

  /// Bright coin ding with a harmonic tail.
  List<double> _ding() {
    final n = (_rate * 0.4).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.003) *
          (0.6 * sin(2 * pi * 1568 * t) * exp(-t * 9) +
              0.35 * sin(2 * pi * 2093 * t) * exp(-t * 13));
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: 0.2));
      out.addAll(List<double>.filled((_rate * gapSecs).round(), 0));
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0));
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // G# arpeggiated 0 – 4 – 5 – 3, 16s loop. Unique to dashrunner.
        final notes = [207.65, 261.62, 311.12, 261.62, 311.12, 391.99, 466.16, 391.99, 349.22, 415.30, 523.25, 415.30, 277.18, 349.22, 415.30, 349.22];
        final out = <double>[];
        final noteLen = 16.0 / notes.length;
        for (final n in notes) {
          out.addAll(_tone(n, noteLen * 0.9, harmonics: 0.3));
          final gap = List<double>.filled((_rate * noteLen * 0.1).round(), 0);
          out.addAll(gap);
        }
        // Soft pad underneath
        final pad = _padChord([207.65, 261.62, 311.12], 16.0);
        for (int i = 0; i < out.length && i < pad.length; i++) {
          out[i] += pad[i] * 0.3;
        }
        return out;
      });


  Uint8List _gameBytes() => _clip('music_game', () {
        // G# bass + melody 0 – 4 – 5 – 3, 16s loop. Unique to dashrunner.
        final bassNotes = [103.83, 155.56, 174.61, 138.59];
        final melNotes = [622.24, 932.32, 1046.50, 830.60];
        final out = List<double>.filled((_rate * 16).round(), 0);
        final segLen = (_rate * 4).round();
        for (int s = 0; s < 4; s++) {
          final bass = _tone(bassNotes[s], 3.5, harmonics: 0.4);
          final mel = _tone(melNotes[s], 1.2, harmonics: 0.25);
          for (int i = 0; i < bass.length && s * segLen + i < out.length; i++) {
            out[s * segLen + i] += bass[i] * 0.5;
          }
          final melStart = s * segLen + segLen ~/ 4;
          for (int i = 0; i < mel.length && melStart + i < out.length; i++) {
            out[melStart + i] += mel[i] * 0.35;
          }
        }
        return out;
      });


  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', () => _tone(1150, 0.06)));
  Future<void> jump() =>
      _play(_clip('jump', () => _whoosh(0.28, up: true)));
  Future<void> slide() =>
      _play(_clip('slide', () => _whoosh(0.24, up: false)));
  Future<void> land() => _play(_clip('land', () => _thud(140)));
  Future<void> coin() => _play(_clip('coin', _ding));
  Future<void> nearMiss() => _play(_clip('near',
      () => _whoosh(0.22, up: true)..addAll(_tone(1760, 0.18))));
  Future<void> crash() => _play(_clip('crash', _crashSfx));
  Future<void> milestone() =>
      _play(_clip('mile', () => _arp([659.25, 783.99, 987.77], 0.14, 0.02)));
  Future<void> gameStart() =>
      _play(_clip('start', () => _tone(330, 0.36, freqEnd: 660)));
  Future<void> countdown() =>
      _play(_clip('count', () => _tone(660, 0.12)));
  Future<void> newBest() => _play(_clip('best',
      () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.15, 0.03)));
  Future<void> lose() => _play(
      _clip('lose', () => _arp([392.0, 329.63, 261.63, 196.0], 0.2, 0.04)));

  // ----------------------------------------------------------------- music
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: only when the user turns music OFF.
  Future<void> stopMusic() async {
    ++_musicGen;
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
