import 'package:flutter/material.dart';

/// Dash Runner art direction: sunlit natural trails — wooden crates, stone
/// boulders, cactus and thorn scrub, dusty ground, big painted skies.
/// No neon, no cyberpunk: everything is physical material and daylight.

/// A full visual theme: sky key-frames for the day->dusk->night->day cycle,
/// hills, ground, accents, coin tint. [id] 'custom' is the player-made theme.
class RunnerThemeDef {
  final String id;
  final String name;
  final bool isPro;
  final Color skyDay;
  final Color skyDusk;
  final Color skyNight;
  final Color hillFar;
  final Color hillNear;
  final Color ground;
  final Color groundLine;
  final Color stripe;
  final Color accent;
  final Color coinOuter;
  final Color flyer;

  const RunnerThemeDef({
    required this.id,
    required this.name,
    this.isPro = false,
    required this.skyDay,
    required this.skyDusk,
    required this.skyNight,
    required this.hillFar,
    required this.hillNear,
    required this.ground,
    required this.groundLine,
    required this.stripe,
    required this.accent,
    required this.coinOuter,
    required this.flyer,
  });

  /// Sky color for a cycle phase 0..1 (day -> dusk -> night -> day).
  Color sky(double phase) {
    final keys = [skyDay, skyDusk, skyNight, skyDay];
    final p = (phase % 1) * 3;
    final i = p.floor().clamp(0, 2);
    return Color.lerp(keys[i], keys[i + 1], p - i)!;
  }

  bool isDark(double phase) => sky(phase).computeLuminance() < 0.4;
}

class RunnerThemes {
  static const List<RunnerThemeDef> all = [
    RunnerThemeDef(
      id: 'meadow',
      name: 'Meadow Dawn',
      skyDay: Color(0xFF8FD3F4),
      skyDusk: Color(0xFFFFB37E),
      skyNight: Color(0xFF16233F),
      hillFar: Color(0xFF7FB069),
      hillNear: Color(0xFF5B8E4A),
      ground: Color(0xFF4A7C44),
      groundLine: Color(0xFFE8B54D),
      stripe: Color(0xFFFFFFFF),
      accent: Color(0xFFE8B54D),
      coinOuter: Color(0xFFFFD93D),
      flyer: Color(0xFF8D6E63),
    ),
    RunnerThemeDef(
      id: 'canyon',
      name: 'Canyon Dusk',
      skyDay: Color(0xFFF2C185),
      skyDusk: Color(0xFFE07A5F),
      skyNight: Color(0xFF2B1B3D),
      hillFar: Color(0xFFB5651D),
      hillNear: Color(0xFF8A4B12),
      ground: Color(0xFF9C5A24),
      groundLine: Color(0xFFFFE0A3),
      stripe: Color(0xFFFFFFFF),
      accent: Color(0xFFFFE0A3),
      coinOuter: Color(0xFFFFD93D),
      flyer: Color(0xFF5D4037),
    ),
    RunnerThemeDef(
      id: 'pine',
      name: 'Pine Forest',
      skyDay: Color(0xFFA8D8B9),
      skyDusk: Color(0xFFF4A988),
      skyNight: Color(0xFF0E1F1A),
      hillFar: Color(0xFF2E6B4F),
      hillNear: Color(0xFF1E4A35),
      ground: Color(0xFF3B5A3A),
      groundLine: Color(0xFFD9C68A),
      stripe: Color(0xFFFFFFFF),
      accent: Color(0xFFD9C68A),
      coinOuter: Color(0xFFFFD93D),
      flyer: Color(0xFF4E342E),
    ),
    RunnerThemeDef(
      id: 'desert',
      name: 'Desert Trail',
      skyDay: Color(0xFFFCEabb),
      skyDusk: Color(0xFFF49C6C),
      skyNight: Color(0xFF1F2440),
      hillFar: Color(0xFFD9A441),
      hillNear: Color(0xFFB57F2B),
      ground: Color(0xFFC98F3D),
      groundLine: Color(0xFF5B3A1E),
      stripe: Color(0xFFFFFFFF),
      accent: Color(0xFF7A4A1F),
      coinOuter: Color(0xFFFFE082),
      flyer: Color(0xFF6D4C41),
    ),
    RunnerThemeDef(
      id: 'cliffs',
      name: 'Ocean Cliffs',
      isPro: true,
      skyDay: Color(0xFF9FD8E8),
      skyDusk: Color(0xFFF7A8B8),
      skyNight: Color(0xFF101E38),
      hillFar: Color(0xFF4A7C8E),
      hillNear: Color(0xFF33586A),
      ground: Color(0xFF6B7F5E),
      groundLine: Color(0xFFF2E6C9),
      stripe: Color(0xFFFFFFFF),
      accent: Color(0xFFF2E6C9),
      coinOuter: Color(0xFFFFD93D),
      flyer: Color(0xFF546E7A),
    ),
    RunnerThemeDef(
      id: 'snow',
      name: 'Snow Peaks',
      isPro: true,
      skyDay: Color(0xFFCDE7F5),
      skyDusk: Color(0xFFE8B4C8),
      skyNight: Color(0xFF1A2338),
      hillFar: Color(0xFF9FB4C8),
      hillNear: Color(0xFF7A8FA8),
      ground: Color(0xFFDCE8F2),
      groundLine: Color(0xFF5A7A9C),
      stripe: Color(0xFF5A7A9C),
      accent: Color(0xFF5A7A9C),
      coinOuter: Color(0xFFFFD93D),
      flyer: Color(0xFF37474F),
    ),
    RunnerThemeDef(
      id: 'jungle',
      name: 'Jungle Ruins',
      isPro: true,
      skyDay: Color(0xFFB8E0A8),
      skyDusk: Color(0xFFF0B47E),
      skyNight: Color(0xFF12261B),
      hillFar: Color(0xFF3E7A44),
      hillNear: Color(0xFF2A5530),
      ground: Color(0xFF5A6B3A),
      groundLine: Color(0xFFE8D9A0),
      stripe: Color(0xFFFFFFFF),
      accent: Color(0xFFE8D9A0),
      coinOuter: Color(0xFFFFD93D),
      flyer: Color(0xFF4E5B2E),
    ),
    RunnerThemeDef(
      id: 'autumn',
      name: 'Autumn Valley',
      isPro: true,
      skyDay: Color(0xFFF5D6A8),
      skyDusk: Color(0xFFE88A5F),
      skyNight: Color(0xFF241A33),
      hillFar: Color(0xFFC46A3B),
      hillNear: Color(0xFF9A4E26),
      ground: Color(0xFF8A5A33),
      groundLine: Color(0xFFF5E6B8),
      stripe: Color(0xFFFFFFFF),
      accent: Color(0xFFF5E6B8),
      coinOuter: Color(0xFFFFD93D),
      flyer: Color(0xFF5D4037),
    ),
    RunnerThemeDef(
      id: 'moonlit',
      name: 'Moonlit Trail',
      isPro: true,
      skyDay: Color(0xFFB9C8E8),
      skyDusk: Color(0xFF9A8AC8),
      skyNight: Color(0xFF0B1026),
      hillFar: Color(0xFF3A4A6B),
      hillNear: Color(0xFF2A3550),
      ground: Color(0xFF3E4A5E),
      groundLine: Color(0xFFD9D9F0),
      stripe: Color(0xFFFFFFFF),
      accent: Color(0xFFD9D9F0),
      coinOuter: Color(0xFFF5F0FF),
      flyer: Color(0xFF90A4AE),
    ),
    RunnerThemeDef(
      id: 'volcano',
      name: 'Volcano Rim',
      isPro: true,
      skyDay: Color(0xFFE8B08A),
      skyDusk: Color(0xFFD95F43),
      skyNight: Color(0xFF1E0F14),
      hillFar: Color(0xFF6B3A2E),
      hillNear: Color(0xFF4A2620),
      ground: Color(0xFF5A3A30),
      groundLine: Color(0xFFFFB37E),
      stripe: Color(0xFFFFFFFF),
      accent: Color(0xFFFFB37E),
      coinOuter: Color(0xFFFFD93D),
      flyer: Color(0xFF3E2723),
    ),
    RunnerThemeDef(
      id: 'savannah',
      name: 'Savannah Sun',
      isPro: true,
      skyDay: Color(0xFFF8E3A8),
      skyDusk: Color(0xFFF0A05F),
      skyNight: Color(0xFF20263E),
      hillFar: Color(0xFFC8A04A),
      hillNear: Color(0xFFA07F30),
      ground: Color(0xFFB08A3E),
      groundLine: Color(0xFF4A3A1E),
      stripe: Color(0xFFFFFFFF),
      accent: Color(0xFF4A3A1E),
      coinOuter: Color(0xFFFFD93D),
      flyer: Color(0xFF6D4C41),
    ),
    RunnerThemeDef(
      id: 'storm',
      name: 'Storm Coast',
      isPro: true,
      skyDay: Color(0xFFA8B8C8),
      skyDusk: Color(0xFFC89898),
      skyNight: Color(0xFF141A24),
      hillFar: Color(0xFF5A6A7A),
      hillNear: Color(0xFF42505E),
      ground: Color(0xFF4E5A64),
      groundLine: Color(0xFFE8D9A0),
      stripe: Color(0xFFFFFFFF),
      accent: Color(0xFFE8D9A0),
      coinOuter: Color(0xFFFFD93D),
      flyer: Color(0xFF37474F),
    ),
  ];

  static RunnerThemeDef byId(String id, {RunnerThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static bool isProTheme(String id) => byId(id).isPro;
}

/// Runner outfit styles (the dashing character's gear colors).
class RunnerStyle {
  final String id;
  final String name;
  final bool isPro;
  final Color body; // jacket/vest
  final Color trim; // cap + shoes accent
  final Color skin;

  const RunnerStyle({
    required this.id,
    required this.name,
    this.isPro = false,
    required this.body,
    required this.trim,
    required this.skin,
  });
}

class RunnerStyles {
  static const List<RunnerStyle> all = [
    RunnerStyle(
        id: 'ember',
        name: 'Ember',
        body: Color(0xFFC0392B),
        trim: Color(0xFF7B241C),
        skin: Color(0xFFF1C27D)),
    RunnerStyle(
        id: 'forest',
        name: 'Forest Scout',
        body: Color(0xFF2E7D5B),
        trim: Color(0xFF1B4D3E),
        skin: Color(0xFFE0AC69)),
    RunnerStyle(
        id: 'ocean',
        name: 'Ocean',
        body: Color(0xFF2471A3),
        trim: Color(0xFF1A5276),
        skin: Color(0xFFFFDBAC)),
    RunnerStyle(
        id: 'desertfox',
        name: 'Desert Fox',
        body: Color(0xFFD4883A),
        trim: Color(0xFF935F1F),
        skin: Color(0xFFF1C27D)),
    RunnerStyle(
        id: 'stormrider',
        name: 'Storm Rider',
        isPro: true,
        body: Color(0xFF5D6D7E),
        trim: Color(0xFF2E4053),
        skin: Color(0xFFE0AC69)),
    RunnerStyle(
        id: 'snowfox',
        name: 'Snow Fox',
        isPro: true,
        body: Color(0xFFDDE6ED),
        trim: Color(0xFF8FA3B8),
        skin: Color(0xFFFFDBAC)),
    RunnerStyle(
        id: 'golden',
        name: 'Golden',
        isPro: true,
        body: Color(0xFFD4A017),
        trim: Color(0xFF7D5A0A),
        skin: Color(0xFFF1C27D)),
    RunnerStyle(
        id: 'obsidian',
        name: 'Obsidian',
        isPro: true,
        body: Color(0xFF2B2B2E),
        trim: Color(0xFF0F0F10),
        skin: Color(0xFFE0AC69)),
  ];

  static RunnerStyle byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return all.first;
  }

  static bool isPro(String id) => byId(id).isPro;
}

/// Obstacle visual styles — physical materials only.
class ObstacleStyle {
  final String id;
  final String name;
  final bool isPro;
  final Color main;
  final Color dark;
  final Color light;

  const ObstacleStyle({
    required this.id,
    required this.name,
    this.isPro = false,
    required this.main,
    required this.dark,
    required this.light,
  });
}

class ObstacleStyles {
  static const List<ObstacleStyle> all = [
    ObstacleStyle(
        id: 'crates',
        name: 'Wooden Crates',
        main: Color(0xFFB5651D),
        dark: Color(0xFF6E3B0E),
        light: Color(0xFFE0A55F)),
    ObstacleStyle(
        id: 'barrels',
        name: 'Oak Barrels',
        main: Color(0xFF8A5A2B),
        dark: Color(0xFF4A2E12),
        light: Color(0xFFC89A5E)),
    ObstacleStyle(
        id: 'boulders',
        name: 'Stone Boulders',
        main: Color(0xFF8E8E93),
        dark: Color(0xFF4A4A4E),
        light: Color(0xFFC7C7CC)),
    ObstacleStyle(
        id: 'cacti',
        name: 'Desert Cacti',
        main: Color(0xFF3E7A44),
        dark: Color(0xFF1E4A24),
        light: Color(0xFF7FB069)),
    ObstacleStyle(
        id: 'brambles',
        name: 'Thorn Brambles',
        isPro: true,
        main: Color(0xFF4A5A2E),
        dark: Color(0xFF243014),
        light: Color(0xFF8AA04E)),
    ObstacleStyle(
        id: 'totems',
        name: 'Carved Totems',
        isPro: true,
        main: Color(0xFF7A4E2D),
        dark: Color(0xFF3E2412),
        light: Color(0xFFB07A4A)),
    ObstacleStyle(
        id: 'ice',
        name: 'Ice Blocks',
        isPro: true,
        main: Color(0xFFA8D8E8),
        dark: Color(0xFF5A8AA8),
        light: Color(0xFFE8F8FF)),
    ObstacleStyle(
        id: 'cones',
        name: 'Trail Cones',
        isPro: true,
        main: Color(0xFFE07A2E),
        dark: Color(0xFF8A4412),
        light: Color(0xFFF5B04A)),
  ];

  static ObstacleStyle byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return all.first;
  }

  static bool isPro(String id) => byId(id).isPro;
}
