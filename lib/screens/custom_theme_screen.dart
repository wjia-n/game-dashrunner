import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/runner_themes.dart';
import 'widgets.dart';

/// "My Trail" custom theme creator (PRO): paint your own trail colors.
class CustomThemeScreen extends StatefulWidget {
  final DashAudio audio;
  final DashSettings settings;

  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  RunnerThemeDef get _t => widget.settings.customTheme;

  static const _labels = {
    'skyDay': 'Day sky',
    'skyDusk': 'Dusk sky',
    'skyNight': 'Night sky',
    'hillFar': 'Far hills',
    'hillNear': 'Near hills',
    'ground': 'Ground',
    'groundLine': 'Trail line',
    'accent': 'Accent',
    'coin': 'Coins',
  };

  static const _swatches = [
    0xFF8FD3F4, 0xFFFFB37E, 0xFF16233F, 0xFF7FB069, 0xFF5B8E4A, 0xFF4A7C44,
    0xFFE8B54D, 0xFFFFD93D, 0xFFC0392B, 0xFF2471A3, 0xFFD4883A, 0xFF5D6D7E,
    0xFFDDE6ED, 0xFF2B2B2E, 0xFFB5651D, 0xFF8E8E93, 0xFF3E7A44, 0xFFE07A2E,
    0xFFA8D8E8, 0xFFF4F1DE, 0xFF6B3A2E, 0xFFD4A017, 0xFF9A4E26, 0xFF3E2412,
  ];

  @override
  Widget build(BuildContext context) {
    final t = widget.settings.theme;
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
        title: Text('My Trail', style: display(22, t)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () async {
              widget.audio.click();
              await widget.settings.resetCustomColors();
              setState(() {});
            },
            child: Text('Reset',
                style: body(14, t,
                    color: t.accent, weight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.settings,
        builder: (_, _) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: Column(
            children: [
              // live preview strip
              Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.accent, width: 2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _t.skyDay,
                      _t.ground,
                    ],
                  ),
                ),
                child: Center(
                  child: Text('LIVE PREVIEW',
                      style: display(18, t, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
              TrailButton(
                label: 'USE THIS TRAIL',
                icon: Icons.check,
                theme: t,
                onPressed: () async {
                  widget.audio.click();
                  await widget.settings.setTheme('custom');
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 8),
              for (final key in _labels.keys) _colorRow(key, t),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorRow(String key, RunnerThemeDef t) {
    final current = widget.settings.customColors[key]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Color(current),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white54),
                ),
              ),
              const SizedBox(width: 10),
              Text(_labels[key]!, style: body(15, t, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _swatches)
                GestureDetector(
                  onTap: () {
                    widget.audio.click();
                    widget.settings.setCustomColor(key, c);
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(c),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: current == c ? t.accent : Colors.white24,
                        width: current == c ? 3 : 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
