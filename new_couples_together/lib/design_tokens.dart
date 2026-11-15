import 'package:flutter/material.dart';

// ============================================================
//  COUPLES APP — PASTEL DESIGN TOKENS
//  Generated from pastel UI spec (pink / white / blue / cream)
//  Use these constants throughout the app for consistency.
// ============================================================

// ────────────────────────────────────────────────────────────
//  COLORS
// ────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // ── Backgrounds ──────────────────────────────────────────
  /// Warm cream — main Scaffold background
  static const Color background        = Color(0xFFFDF8F5);
  /// Pure white — Card, BottomSheet, Dialog backgrounds
  static const Color surface           = Color(0xFFFFFFFF);
  /// Blush tinted — NavBar bg, secondary panels, input fills
  static const Color surfaceBlush      = Color(0xFFFEF4F7);
  /// Icy blue — "her" side panels, received-bubble area bg
  static const Color surfaceBlue       = Color(0xFFF0F7FF);
  /// Warm cream — timeline cards, file-bubble bg
  static const Color surfaceCream      = Color(0xFFFDF6EE);

  // ── Borders ──────────────────────────────────────────────
  /// Default soft rose border for cards and inputs
  static const Color border            = Color(0xFFF0D6E4);
  /// Light blue border — "her" chat bubbles, blue cards
  static const Color borderBlue        = Color(0xFFCDE4F8);
  /// Warm cream border — cream-tinted cards
  static const Color borderCream       = Color(0xFFECDFD4);
  /// Stronger rose — dashed outlines, active elements
  static const Color borderStrong      = Color(0xFFE8B4CC);

  // ── Pink ramp (your / primary) ───────────────────────────
  /// Primary CTA, send button, active nav label
  static const Color pinkDeep          = Color(0xFFC45C8A);
  /// Your mood-circle ring, timeline dot
  static const Color pinkMid           = Color(0xFFE07AAA);
  /// Icons, decorative accents, dashed borders
  static const Color pinkLight         = Color(0xFFF4AECB);
  /// Sent-bubble background, active nav tile bg
  static const Color pinkPale          = Color(0xFFFCE8F2);
  /// Sent chat-bubble background
  static const Color pinkSent          = Color(0xFFF9D6E9);

  // ── Blue ramp (her / secondary) ──────────────────────────
  /// Her accent — mood ring, file-download link
  static const Color blueDeep          = Color(0xFF4A90C8);
  /// Her mood-circle ring, timeline dot
  static const Color blueMid           = Color(0xFF79B4E0);
  /// Her mood-circle ring lighter
  static const Color blueLight         = Color(0xFFB8D9F5);
  /// Received-bubble background
  static const Color bluePale          = Color(0xFFE8F4FD);

  // ── Cream / warm accent ──────────────────────────────────
  /// Timeline dates, caramel accent text
  static const Color creamDeep         = Color(0xFFC49060);
  /// Timeline dot fill
  static const Color creamMid          = Color(0xFFE8C49A);
  /// Cream card tint
  static const Color creamLight        = Color(0xFFF5E4CC);

  // ── Text ─────────────────────────────────────────────────
  /// Primary text — headings, card titles, names
  static const Color textPrimary       = Color(0xFF3A2535);
  /// Secondary text — subtitles, drawer labels
  static const Color textSecondary     = Color(0xFF6B4560);
  /// Muted text — descriptions, placeholders
  static const Color textMuted         = Color(0xFF9E7090);
  /// Faint text — timestamps, section labels, date chips
  static const Color textFaint         = Color(0xFFC4A0B8);
  /// Blue-tinted text — used inside "her" (blue) bubbles
  static const Color textBlue          = Color(0xFF3A6FA0);

  // ── Status ───────────────────────────────────────────────
  /// Online indicator dot (Steam, Instagram, Spotify)
  static const Color statusOnline      = Color(0xFF5ABF8A);
  /// Playing indicator dot (Steam gaming)
  static const Color statusPlaying     = Color(0xFFC49060); // reuse creamDeep
  /// Offline indicator dot
  static const Color statusOffline     = Color(0xFFF0D6E4); // reuse border

  // ── Gradient helpers ─────────────────────────────────────
  /// Day-counter / home-widget card gradient
  static const LinearGradient gradientCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFEF0F5), Color(0xFFF0F7FF)],
  );

  /// Chat messages area gradient (top → bottom)
  static const LinearGradient gradientChat = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFDF8F5), Color(0xFFF8F3FC)],
  );

  /// Timeline connector: pink → blue
  static const LinearGradient gradientTimelinePinkBlue = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [pinkMid, blueMid],
  );

  /// Timeline connector: blue → cream
  static const LinearGradient gradientTimelineBlueC = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [blueMid, creamMid],
  );
}

// ────────────────────────────────────────────────────────────
//  TYPOGRAPHY
// ────────────────────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  // Use 'DM Sans' — add to pubspec.yaml:
  //   google_fonts: ^6.x
  // Then: GoogleFonts.dmSans(...)
  // OR declare in pubspec fonts section if bundling locally.
  //
  // Mono variant: 'DM Mono' for hex values, dates, file sizes.

  static const String fontFamily     = 'JetBrains Mono';
  static const String fontFamilyMono = 'JetBrains Mono';

  // ── Display ──────────────────────────────────────────────
  /// Day counter big number (847)
  static const TextStyle dayCounter = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w500,
    color: AppColors.pinkDeep,
    letterSpacing: -0.5,
    height: 1.0,
  );

  /// Home widget days number
  static const TextStyle widgetDays = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: AppColors.pinkDeep,
    letterSpacing: -0.4,
    height: 1.0,
  );

  // ── Headings ─────────────────────────────────────────────
  /// Page title (e.g. "Our Timeline ✦")
  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Card title / event title
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Chat username / contact name
  static const TextStyle chatName = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // ── Body ─────────────────────────────────────────────────
  /// Chat bubble text — Array font per design spec
  static const TextStyle bubbleText = TextStyle(
    fontFamily: 'Array',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// Card description / event description
  static const TextStyle cardDesc = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.5,
  );

  /// Service name in status drawer
  static const TextStyle serviceName = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Notification field / input hint
  static const TextStyle inputHint = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  // ── Labels / Captions ────────────────────────────────────
  /// Section header label (ALL CAPS, spaced)
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textFaint,
    letterSpacing: 1.1,
  );

  /// Nav bar label
  static const TextStyle navLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textFaint,
  );

  /// Mood label under circle
  static const TextStyle moodLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textFaint,
  );

  /// Bubble timestamp
  static const TextStyle timestamp = TextStyle(
    fontFamily: fontFamily,
    fontSize: 9,
    fontWeight: FontWeight.w400,
    color: AppColors.textFaint,
  );

  /// Day counter subtitle ("days together")
  static const TextStyle counterSub = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  // ── Mono ─────────────────────────────────────────────────
  /// Timeline date (e.g. "14 Mar 2024")
  static const TextStyle timelineDate = TextStyle(
    fontFamily: fontFamilyMono,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.creamDeep,
  );

  /// Since-date under widget days
  static const TextStyle widgetSince = TextStyle(
    fontFamily: fontFamilyMono,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textFaint,
  );

  /// File size in file bubble
  static const TextStyle fileMeta = TextStyle(
    fontFamily: fontFamilyMono,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textFaint,
  );
}

// ────────────────────────────────────────────────────────────
//  SPACING
// ────────────────────────────────────────────────────────────

class AppSpacing {
  AppSpacing._();

  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 12.0;
  static const double lg  = 16.0;
  static const double xl  = 20.0;
  static const double xxl = 24.0;
  static const double xxxl= 32.0;

  /// Standard card internal padding
  static const EdgeInsets cardPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 12);

  /// Shell / outer card padding
  static const EdgeInsets shellPadding = EdgeInsets.all(16);

  /// Chat bubble internal padding
  static const EdgeInsets bubblePadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 9);

  /// Input bar padding
  static const EdgeInsets inputBarPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 10);

  /// Timeline card left offset (spine width + gap)
  static const double timelineSpineWidth = 16.0;
  static const double timelineGap        = 12.0;
}

// ────────────────────────────────────────────────────────────
//  BORDER RADIUS
// ────────────────────────────────────────────────────────────

class AppRadius {
  AppRadius._();

  static const double xs   = 6.0;
  static const double sm   = 8.0;
  static const double md   = 12.0;
  static const double lg   = 14.0;
  static const double xl   = 16.0;
  static const double xxl  = 18.0;
  static const double xxxl = 20.0;
  static const double full = 999.0; // pills and circles

  // ── Named radii ──────────────────────────────────────────
  static const BorderRadius card =
      BorderRadius.all(Radius.circular(md));

  static const BorderRadius shell =
      BorderRadius.all(Radius.circular(lg));

  static const BorderRadius page =
      BorderRadius.all(Radius.circular(xxl));

  static const BorderRadius chip =
      BorderRadius.all(Radius.circular(full));

  static const BorderRadius bubble =
      BorderRadius.all(Radius.circular(xxl));

  // Sent bubble — square bottom-right corner
  static const BorderRadius bubbleSent = BorderRadius.only(
    topLeft:     Radius.circular(xxl),
    topRight:    Radius.circular(xxl),
    bottomLeft:  Radius.circular(xxl),
    bottomRight: Radius.circular(xs),
  );

  // Received bubble — square bottom-left corner
  static const BorderRadius bubbleRecv = BorderRadius.only(
    topLeft:     Radius.circular(xxl),
    topRight:    Radius.circular(xxl),
    bottomLeft:  Radius.circular(xs),
    bottomRight: Radius.circular(xxl),
  );

  static const BorderRadius navBar =
      BorderRadius.all(Radius.circular(lg));

  static const BorderRadius homeWidget =
      BorderRadius.all(Radius.circular(xxxl));

  static const BorderRadius avatar =
      BorderRadius.all(Radius.circular(full));

  static const BorderRadius timelineImage =
      BorderRadius.all(Radius.circular(sm));

  static const BorderRadius serviceIcon =
      BorderRadius.all(Radius.circular(sm));

  static const BorderRadius inputField =
      BorderRadius.all(Radius.circular(xl));

  static const BorderRadius notifPreviewLeft = BorderRadius.only(
    topRight:    Radius.circular(sm),
    bottomRight: Radius.circular(sm),
  );
}

// ────────────────────────────────────────────────────────────
//  ELEVATION / SHADOWS
// ────────────────────────────────────────────────────────────

class AppShadows {
  AppShadows._();

  /// Subtle card lift
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x12B4648C),  // ~7% pink-rose
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  /// Chat shell / timeline page lift
  static const List<BoxShadow> page = [
    BoxShadow(
      color: Color(0x17B4648C),  // ~9%
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];

  /// Home widget
  static const List<BoxShadow> widget = [
    BoxShadow(
      color: Color(0x1AB4648C),  // ~10%
      blurRadius: 16,
      offset: Offset(0, 2),
    ),
  ];
}

// ────────────────────────────────────────────────────────────
//  BORDER SIDES (reusable)
// ────────────────────────────────────────────────────────────

class AppBorders {
  AppBorders._();

  static const Border defaultBorder = Border.fromBorderSide(
    BorderSide(color: AppColors.border, width: 1.0),
  );

  static const Border blueBorder = Border.fromBorderSide(
    BorderSide(color: AppColors.borderBlue, width: 1.0),
  );

  static const Border creamBorder = Border.fromBorderSide(
    BorderSide(color: AppColors.borderCream, width: 1.0),
  );

  static const Border strongBorder = Border.fromBorderSide(
    BorderSide(color: AppColors.borderStrong, width: 1.5),
  );

  /// For the notification preview accent left bar
  static const Border notifAccentBorder = Border(
    left: BorderSide(color: AppColors.pinkMid, width: 3.0),
  );

  /// Dashed — use DashedBorder package or CustomPainter
  /// Color: AppColors.borderStrong, width: 1.5
  /// Use for: tl-new-btn, new event wireframe card
  static const Color dashedColor = AppColors.borderStrong;
  static const double dashedWidth = 1.5;
}

// ────────────────────────────────────────────────────────────
//  MOOD DEFINITIONS
//  Used by the pixel-art mood picker on the dashboard
// ────────────────────────────────────────────────────────────

enum Mood {
  happy,
  inLove,
  sad,
  tired,
  excited,
  neutral,
}

extension MoodExtension on Mood {
  String get label {
    switch (this) {
      case Mood.happy:    return 'Happy';
      case Mood.inLove:   return 'In love';
      case Mood.sad:      return 'Sad';
      case Mood.tired:    return 'Tired';
      case Mood.excited:  return 'Excited';
      case Mood.neutral:  return 'Okay';
    }
  }

  String get emoji {
    switch (this) {
      case Mood.happy:    return ':)';
      case Mood.inLove:   return '<3';
      case Mood.sad:      return ':(';
      case Mood.tired:    return '-_-';
      case Mood.excited:  return ':D';
      case Mood.neutral:  return ':|';
    }
  }
}

// ────────────────────────────────────────────────────────────
//  THEME — plug into MaterialApp
// ────────────────────────────────────────────────────────────

ThemeData appTheme({bool isHers = true, bool isDark = false}) {
  final Color primary    = isHers ? AppColors.pinkDeep : AppColors.blueDeep;
  final Color primaryMid = isHers ? AppColors.pinkMid  : AppColors.blueMid;
  final Color secondary  = isHers ? AppColors.blueDeep : AppColors.pinkDeep;

  if (isDark) {
    const dkBg      = Color(0xFF1A1220);
    const dkSurface = Color(0xFF251B22);
    const dkBorder  = Color(0xFF4A2E40);
    const dkFill    = Color(0xFF2E1F2A);
    const dkText    = Color(0xFFEEDDE8);
    const dkFaint   = Color(0xFF6B4D60);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: dkBg,
      colorScheme: ColorScheme.dark(
        primary:     primary,
        secondary:   secondary,
        surface:     dkSurface,
        onPrimary:   Colors.white,
        onSecondary: Colors.white,
        onSurface:   dkText,
      ),
      fontFamily: AppTextStyles.fontFamily,
      cardTheme: CardTheme(
        color: dkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: const BorderSide(color: dkBorder, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dkFill,
        hintStyle: AppTextStyles.inputHint.copyWith(color: dkFaint),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputField,
          borderSide: const BorderSide(color: dkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputField,
          borderSide: const BorderSide(color: dkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputField,
          borderSide: BorderSide(color: primaryMid, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
          textStyle: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: dkBorder,
        thickness: 1.0,
        space: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: dkSurface,
        selectedItemColor: primary,
        unselectedItemColor: dkFaint,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.light(
      primary:     primary,
      secondary:   secondary,
      surface:     AppColors.surface,
      onPrimary:   Colors.white,
      onSecondary: Colors.white,
      onSurface:   AppColors.textPrimary,
    ),
    fontFamily: AppTextStyles.fontFamily,
    cardTheme: CardTheme(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: const BorderSide(color: AppColors.border, width: 1.0),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceBlush,
      hintStyle: AppTextStyles.inputHint,
      border: OutlineInputBorder(
        borderRadius: AppRadius.inputField,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputField,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputField,
        borderSide: BorderSide(color: primaryMid, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        textStyle: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1.0,
      space: 0,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: primary,
      unselectedItemColor: AppColors.textFaint,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
