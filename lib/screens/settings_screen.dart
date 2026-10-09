import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/runner_themes.dart';
import 'widgets.dart';

/// Settings: music/SFX toggles, volume slider, player name. All persisted.
class SettingsScreen extends StatefulWidget {
  final DashAudio audio;
  final DashSettings settings;

  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  RunnerThemeDef get _t => widget.settings.theme;

  void _applyAudio() {
    widget.audio.configure(
      musicOn: widget.settings.musicOn,
      sfxOn: widget.settings.sfxOn,
      volume: widget.settings.volume,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: const Color(0xFF241A10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            widget.audio.click();
            Navigator.of(context).pop();
          },
        ),
        title: Text('Settings', style: display(22, t)),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: widget.settings,
        builder: (_, _) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: Column(
            children: [
              WoodCard(
                theme: t,
                child: Column(
                  children: [
                    _switchRow(
                      t,
                      icon: Icons.music_note,
                      label: 'Music',
                      value: widget.settings.musicOn,
                      onChanged: (v) async {
                        widget.audio.click();
                        await widget.settings.setMusic(v);
                        _applyAudio();
                        if (v) widget.audio.startMenuMusic();
                      },
                    ),
                    const Divider(color: Colors.white24),
                    _switchRow(
                      t,
                      icon: Icons.volume_up,
                      label: 'Sound effects',
                      value: widget.settings.sfxOn,
                      onChanged: (v) async {
                        await widget.settings.setSfx(v);
                        _applyAudio();
                        if (v) widget.audio.click();
                      },
                    ),
                    const Divider(color: Colors.white24),
                    Row(
                      children: [
                        const Icon(Icons.tune, color: Colors.white70),
                        const SizedBox(width: 12),
                        Text('Volume', style: body(16, t)),
                        Expanded(
                          child: Slider(
                            value: widget.settings.volume,
                            activeColor: t.accent,
                            inactiveColor: Colors.white24,
                            onChanged: (v) {
                              widget.settings.setVolume(v);
                              _applyAudio();
                            },
                            onChangeEnd: (_) => widget.audio.click(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              WoodCard(
                theme: t,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How to play', style: display(18, t)),
                    const SizedBox(height: 8),
                    Text(
                      '👆 Tap anywhere to JUMP over crates, boulders and cacti.\n'
                      '⬇️ Swipe down to SLIDE under birds and low branches.\n'
                      '🪙 Grab coins: each is worth 10 pts.\n'
                      '😱 Near misses earn +5 pts — thread the needle!\n'
                      '🚩 Every 500 m is a milestone worth +25 pts.\n'
                      '⚡ Speed keeps rising. One crash ends the run.',
                      style: body(14, t, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchRow(RunnerThemeDef t,
          {required IconData icon,
          required String label,
          required bool value,
          required ValueChanged<bool> onChanged}) =>
      Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: body(16, t))),
          Switch(
            value: value,
            activeThumbColor: t.accent,
            onChanged: onChanged,
          ),
        ],
      );
}
