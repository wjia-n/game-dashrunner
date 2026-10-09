import 'package:flutter/material.dart';
import '../theme/runner_themes.dart';

/// Shared earthy UI: wooden-sign styling, physical depth, warm daylight.
/// Used by every screen in Dash Runner.

TextStyle display(double size, RunnerThemeDef t,
        {Color? color, FontWeight? weight}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight ?? FontWeight.w900,
      color: color ?? t.accent,
      letterSpacing: 1.2,
      shadows: const [
        Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4),
      ],
    );

TextStyle body(double size, RunnerThemeDef t,
        {Color? color, FontWeight? weight}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight ?? FontWeight.w600,
      color: color ?? Colors.white,
    );

/// A wooden-sign card with bevel + shadow: the physical panel look.
class WoodCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final RunnerThemeDef theme;
  const WoodCard(
      {super.key,
      required this.child,
      required this.theme,
      this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF4A3220).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.accent, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54, offset: Offset(0, 6), blurRadius: 14),
          BoxShadow(
              color: Colors.white10,
              offset: Offset(0, 2),
              blurRadius: 2,
              spreadRadius: -1),
        ],
      ),
      child: child,
    );
  }
}

/// Big chunky trail-sign button.
class TrailButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final RunnerThemeDef theme;
  final bool primary;
  final bool small;

  const TrailButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.theme,
    this.icon,
    this.primary = true,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary ? theme.accent : const Color(0xFF6B4E30);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: small ? 14 : 22, vertical: small ? 9 : 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.black.withValues(alpha: 0.35), width: 2),
          boxShadow: const [
            BoxShadow(
                color: Colors.black45, offset: Offset(0, 4), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: const Color(0xFF2B1B0E), size: small ? 17 : 22),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: small ? 14 : 18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF2B1B0E),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section heading on menus.
class SectionTitle extends StatelessWidget {
  final String text;
  final RunnerThemeDef theme;
  const SectionTitle(this.text, {super.key, required this.theme});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(
          children: [
            Container(width: 26, height: 3, color: theme.accent),
            const SizedBox(width: 10),
            Text(text.toUpperCase(),
                style: display(15, theme, weight: FontWeight.w800)),
          ],
        ),
      );
}

/// Small "PRO" lock badge.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFD4A017),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black45),
        ),
        child: const Text('PRO',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2B1B0E))),
      );
}

/// Snack helper with the game's voice.
void showTrailSnack(BuildContext context, String msg, RunnerThemeDef t) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: body(15, t)),
      backgroundColor: const Color(0xFF3B2A18),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.accent, width: 1.5),
      ),
    ),
  );
}
