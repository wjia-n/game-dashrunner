import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/dash_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/runner_themes.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.dashrunner';

/// Main menu: logo, player profile, mode picker, theme/runner/obstacle
/// pickers, stats, share/rate/settings/pro.
class MenuScreen extends StatefulWidget {
  final DashAudio audio;
  final DashSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final StoreService _store = StoreService();
  final _nameCtrl = TextEditingController();
  final _nameFocus = FocusNode();

  DashSettings get _s => widget.settings;
  RunnerThemeDef get _t => _s.theme;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = _s.playerName;
    _nameCtrl.addListener(_onNameTyped);
    _nameFocus.addListener(_onNameFocus);
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
  }

  /// Save on EVERY keystroke — never wait for keyboard-done.
  void _onNameTyped() {
    if (_nameCtrl.text == _s.playerName) return;
    _s.setPlayerName(_nameCtrl.text);
  }

  /// Commit on focus loss: trimming + default enforcement applied.
  void _onNameFocus() {
    if (!_nameFocus.hasFocus) {
      _s.setPlayerName(_nameCtrl.text);
      // Reflect the committed (trimmed) name back into the field.
      _nameCtrl.removeListener(_onNameTyped);
      _nameCtrl.text = _s.playerName;
      _nameCtrl.addListener(_onNameTyped);
    }
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.newBest();
    showTrailSnack(context, msg, _t);
    _store.lastThanks.value = null;
  }

  
  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.dispose();
    _nameCtrl.removeListener(_onNameTyped);
    _nameFocus.removeListener(_onNameFocus);
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: null);
      }
    } catch (_) {}
  }

  void _play(DashMode mode) {
    widget.audio.gameStart();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: widget.settings,
          mode: mode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: const Color(0xFF241A10),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A2A16), Color(0xFF1A120A)],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                children: [
                  _header(t),
                  const SizedBox(height: 12),
                  _nameEditor(t),
                  SectionTitle('Choose your run', theme: t),
                  _modeGrid(t),
                  SectionTitle('Trail theme', theme: t),
                  _themeGrid(t),
                  SectionTitle('Runner gear', theme: t),
                  _runnerRow(t),
                  SectionTitle('Obstacles', theme: t),
                  _obstacleRow(t),
                  SectionTitle('Your trail record', theme: t),
                  _stats(t),
                  const SizedBox(height: 14),
                  _iconRow(t),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(RunnerThemeDef t) => Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.accent, width: 2.5),
            ),
            clipBehavior: Clip.antiAlias,
            child:
                Image.asset('assets/dashrunner_logo.png', fit: BoxFit.cover),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DASH RUNNER', style: display(30, t)),
              Text('Jump · Slide · Dash',
                  style: body(13, t,
                      color: Colors.white70, weight: FontWeight.w700)),
            ],
          ),
          const Spacer(),
          if (_s.isPro)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFD4A017),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('PRO',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2B1B0E))),
            ),
        ],
      );

  Widget _nameEditor(RunnerThemeDef t) => WoodCard(
        theme: t,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.person, color: Colors.white70),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                style: body(17, t, weight: FontWeight.w800),
                decoration: InputDecoration(
                  hintText: 'Your runner name',
                  hintStyle: body(15, t, color: Colors.white38),
                  border: InputBorder.none,
                  isDense: true,
                ),
                maxLength: 16,
                onSubmitted: (v) {
                  widget.audio.click();
                  _s.setPlayerName(v);
                  _nameCtrl.text = _s.playerName;
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.white),
              onPressed: () {
                widget.audio.click();
                _s.setPlayerName(_nameCtrl.text);
                _nameCtrl.text = _s.playerName;
                FocusScope.of(context).unfocus();
              },
            ),
          ],
        ),
      );

  Widget _modeGrid(RunnerThemeDef t) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.5,
        children: [
          for (final m in DashMode.values) _modeCard(m, t),
        ],
      );

  Widget _modeCard(DashMode m, RunnerThemeDef t) {
    final locked = !_s.isPro && m == DashMode.extreme;
    final selected = _s.modeId == m.id;
    final best = _s.bestScore[m.id] ?? 0;
    return GestureDetector(
      onTap: () {
        if (locked) {
          showTrailSnack(
              context, 'Extreme Dash is a PRO mode — see the PRO screen!', t);
          return;
        }
        widget.audio.click();
        _s.setMode(m.id);
        _play(m);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? t.accent.withValues(alpha: 0.28)
              : Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? t.accent : Colors.white24, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(m.name,
                        style: body(15, t, weight: FontWeight.w800))),
                if (locked) const ProBadge(),
              ],
            ),
            const SizedBox(height: 3),
            Text(m.blurb,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: body(11, t, color: Colors.white60)),
            if (best > 0)
              Text('Best: $best',
                  style: body(11, t,
                      color: t.accent, weight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _themeGrid(RunnerThemeDef t) => GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
        children: [
          for (final th in RunnerThemes.all) _themeCell(th, t),
          _customCell(t),
        ],
      );

  Widget _themeCell(RunnerThemeDef th, RunnerThemeDef t) {
    final locked = !_s.isPro && th.isPro;
    final selected = _s.themeId == th.id;
    return GestureDetector(
      onTap: () {
        if (locked) {
          showTrailSnack(
              context, '${th.name} is a PRO theme — unlock them all!', t);
          return;
        }
        widget.audio.click();
        _s.setTheme(th.id);
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: selected ? t.accent : Colors.white24,
                    width: selected ? 3 : 1.5),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [th.skyDay, th.ground],
                ),
              ),
              child: Stack(
                children: [
                  if (locked)
                    const Center(
                        child: Icon(Icons.lock,
                            color: Colors.white, size: 22)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(th.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body(10, t,
                  color: selected ? t.accent : Colors.white70,
                  weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _customCell(RunnerThemeDef t) {
    final selected = _s.themeId == 'custom';
    return GestureDetector(
      onTap: () {
        if (!_s.isPro) {
          showTrailSnack(
              context, 'The theme creator is a PRO feature!', t);
          return;
        }
        widget.audio.click();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomThemeScreen(
                audio: widget.audio, settings: widget.settings),
          ),
        );
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: selected ? t.accent : Colors.white24,
                    width: selected ? 3 : 1.5),
                color: Colors.black.withValues(alpha: 0.4),
              ),
              child: Center(
                child: _s.isPro
                    ? const Icon(Icons.palette,
                        color: Colors.white, size: 24)
                    : const Icon(Icons.lock,
                        color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text('My Trail',
              style: body(10, t,
                  color: selected ? t.accent : Colors.white70,
                  weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _runnerRow(RunnerThemeDef t) => SizedBox(
        height: 86,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: RunnerStyles.all.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final s = RunnerStyles.all[i];
            final locked = !_s.isPro && s.isPro;
            final selected = _s.runnerStyleId == s.id;
            return GestureDetector(
              onTap: () {
                if (locked) {
                  showTrailSnack(context,
                      '${s.name} gear is PRO-only — see the PRO screen!', t);
                  return;
                }
                widget.audio.click();
                _s.setRunnerStyle(s.id);
              },
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s.body,
                      border: Border.all(
                          color: selected ? t.accent : Colors.white24,
                          width: selected ? 3 : 1.5),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black45,
                            offset: Offset(0, 3),
                            blurRadius: 6)
                      ],
                    ),
                    child: Center(
                      child: locked
                          ? const Icon(Icons.lock,
                              color: Colors.white, size: 20)
                          : Container(
                              width: 30,
                              height: 20,
                              decoration: BoxDecoration(
                                color: s.trim,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(s.name,
                      style: body(10, t,
                          color: selected ? t.accent : Colors.white70,
                          weight: FontWeight.w700)),
                ],
              ),
            );
          },
        ),
      );

  Widget _obstacleRow(RunnerThemeDef t) => SizedBox(
        height: 86,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: ObstacleStyles.all.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final s = ObstacleStyles.all[i];
            final locked = !_s.isPro && s.isPro;
            final selected = _s.obstacleStyleId == s.id;
            return GestureDetector(
              onTap: () {
                if (locked) {
                  showTrailSnack(context,
                      '${s.name} is PRO-only — see the PRO screen!', t);
                  return;
                }
                widget.audio.click();
                _s.setObstacleStyle(s.id);
              },
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: s.main,
                      border: Border.all(
                          color: selected ? t.accent : Colors.white24,
                          width: selected ? 3 : 1.5),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black45,
                            offset: Offset(0, 3),
                            blurRadius: 6)
                      ],
                    ),
                    child: Center(
                      child: locked
                          ? const Icon(Icons.lock,
                              color: Colors.white, size: 20)
                          : Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: s.dark, width: 3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(10, t,
                          color: selected ? t.accent : Colors.white70,
                          weight: FontWeight.w700)),
                ],
              ),
            );
          },
        ),
      );

  Widget _stats(RunnerThemeDef t) {
    final totalBest =
        _s.bestScore.values.fold<int>(0, (a, b) => a + b);
    return WoodCard(
      theme: t,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('🏃', '${_s.gamesPlayed}', 'runs', t),
          _stat('⭐', '$totalBest', 'best total', t),
          _stat('🪙', '${_s.totalCoins}', 'coins', t),
        ],
      ),
    );
  }

  Widget _stat(String emoji, String value, String label, RunnerThemeDef t) =>
      Column(
        children: [
          Text('$emoji $value', style: body(17, t, weight: FontWeight.w800)),
          Text(label, style: body(12, t, color: Colors.white60)),
        ],
      );

  Widget _iconRow(RunnerThemeDef t) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _icon(Icons.share, 'Share', t, () async {
            widget.audio.click();
            await SharePlus.instance
                .share(ShareParams(text: 'Play Dash Runner with me! $_storeUrl'));
          }),
          const SizedBox(width: 26),
          _icon(Icons.star_rate, 'Rate', t, _requestReview),
          const SizedBox(width: 26),
          _icon(Icons.workspace_premium, 'PRO', t, () {
            widget.audio.click();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProScreen(
                    audio: widget.audio,
                    settings: widget.settings,
                    store: _store),
              ),
            );
          }),
          const SizedBox(width: 26),
          _icon(Icons.settings, 'Settings', t, () {
            widget.audio.click();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                    audio: widget.audio, settings: widget.settings),
              ),
            );
          }),
        ],
      );

  Widget _icon(IconData icon, String label, RunnerThemeDef t, VoidCallback fn) =>
      GestureDetector(
        onTap: fn,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.4),
                border: Border.all(color: t.accent, width: 2),
              ),
              child: Icon(icon, color: t.accent, size: 24),
            ),
            const SizedBox(height: 4),
            Text(label, style: body(12, t, weight: FontWeight.w700)),
          ],
        ),
      );
}
