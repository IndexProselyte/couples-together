import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// true = "hers" (pink primary), false = "his" (blue primary).
final themeIsHers = ValueNotifier<bool>(true);

/// true = dark mode.
final themeDarkMode = ValueNotifier<bool>(false);

// ── Dark-mode colour overrides ────────────────────────────────────────────────

const _dkBackground    = Color(0xFF1A1220);
const _dkSurface       = Color(0xFF251B22);
const _dkSurfaceBlush  = Color(0xFF2E1F2A);
const _dkSurfaceBlue   = Color(0xFF1C2535);
const _dkSurfaceCream  = Color(0xFF26201A);
const _dkBorder        = Color(0xFF4A2E40);
const _dkBorderBlue    = Color(0xFF1E3555);
const _dkBorderCream   = Color(0xFF3A2C1E);
const _dkBorderStrong  = Color(0xFF6B3A55);
const _dkTextPrimary   = Color(0xFFEEDDE8);
const _dkTextSecondary = Color(0xFFCAADBE);
const _dkTextMuted     = Color(0xFF9B7A8E);
const _dkTextFaint     = Color(0xFF6B4D60);
const _dkTextBlue      = Color(0xFF8EC4E8);
const _dkPinkPale      = Color(0xFF3D1F30);
const _dkBluePale      = Color(0xFF1A2D40);
const _dkPinkSent      = Color(0xFF3D2035);

// ── Color + label helpers ─────────────────────────────────────────────────────

class AppThemeData {
  const AppThemeData({required this.isHers, this.isDark = false});
  final bool isHers;
  final bool isDark;

  // ── Light/dark surface & text ─────────────────────────────────────────────
  Color get background    => isDark ? _dkBackground    : AppColors.background;
  Color get surface       => isDark ? _dkSurface       : AppColors.surface;
  Color get surfaceBlush  => isDark ? _dkSurfaceBlush  : AppColors.surfaceBlush;
  Color get surfaceBlue   => isDark ? _dkSurfaceBlue   : AppColors.surfaceBlue;
  Color get surfaceCream  => isDark ? _dkSurfaceCream  : AppColors.surfaceCream;
  Color get border        => isDark ? _dkBorder        : AppColors.border;
  Color get borderBlue    => isDark ? _dkBorderBlue    : AppColors.borderBlue;
  Color get borderCream   => isDark ? _dkBorderCream   : AppColors.borderCream;
  Color get borderStrong  => isDark ? _dkBorderStrong  : AppColors.borderStrong;
  Color get textPrimary   => isDark ? _dkTextPrimary   : AppColors.textPrimary;
  Color get textSecondary => isDark ? _dkTextSecondary : AppColors.textSecondary;
  Color get textMuted     => isDark ? _dkTextMuted     : AppColors.textMuted;
  Color get textFaint     => isDark ? _dkTextFaint     : AppColors.textFaint;
  Color get textBlue      => isDark ? _dkTextBlue      : AppColors.textBlue;
  Color get pinkPale      => isDark ? _dkPinkPale      : AppColors.pinkPale;
  Color get bluePale      => isDark ? _dkBluePale      : AppColors.bluePale;
  Color get pinkSent      => isDark ? _dkPinkSent      : AppColors.pinkSent;

  LinearGradient get gradientCard => isDark
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1A24), Color(0xFF1A2030)],
        )
      : AppColors.gradientCard;

  LinearGradient get gradientChat => isDark
      ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1220), Color(0xFF1C1825)],
        )
      : AppColors.gradientChat;

  // ── Accent ramp — primary = your colour ──────────────────────────────────
  Color get primary       => isHers ? AppColors.pinkDeep   : AppColors.blueDeep;
  Color get primaryMid    => isHers ? AppColors.pinkMid    : AppColors.blueMid;
  Color get primaryLight  => isHers ? AppColors.pinkLight  : AppColors.blueLight;
  Color get primaryPale   => isHers ? pinkPale : bluePale;
  Color get surfaceMain   => isHers ? surfaceBlush : surfaceBlue;

  // ── Chat bubbles ─────────────────────────────────────────────────────────
  Color get sentBubble    => isHers ? pinkSent : bluePale;
  Color get recvBubble    => isHers ? bluePale : pinkSent;
  Color get sentBorder    => isHers ? border   : borderBlue;
  Color get recvBorder    => isHers ? borderBlue : border;

  // ── Mood circles ─────────────────────────────────────────────────────────
  Color get youCircleBg       => isHers ? pinkPale : bluePale;
  Color get youCircleRing     => isHers ? AppColors.pinkMid  : AppColors.blueMid;
  Color get partnerCircleBg   => isHers ? bluePale : pinkPale;
  Color get partnerCircleRing => isHers ? AppColors.blueMid  : AppColors.pinkMid;

  // ── Labels ───────────────────────────────────────────────────────────────
  String get partnerLabel => isHers ? 'Him' : 'Her';
  String get partnerHeart => isHers ? '♡' : '♦';
}

// ── InheritedWidget scope ─────────────────────────────────────────────────────

class AppThemeScope extends InheritedWidget {
  const AppThemeScope({
    required this.data,
    required super.child,
    super.key,
  });

  final AppThemeData data;

  static AppThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppThemeScope>()!.data;

  @override
  bool updateShouldNotify(AppThemeScope oldWidget) =>
      oldWidget.data.isHers != data.isHers ||
      oldWidget.data.isDark  != data.isDark;
}
