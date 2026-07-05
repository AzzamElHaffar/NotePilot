import 'package:flutter/material.dart';

/// A macOS/iOS "Notes app" inspired theme.
///
/// Design cues taken from Apple Notes:
/// - Warm, slightly off-white backgrounds (not stark white, not grey-blue)
/// - A muted sidebar panel, separated by hairline dividers instead of shadows
/// - The signature warm yellow used sparingly for folder icons, links and
///   the caret/focus color — never as a loud background fill
/// - Neutral graphite text colors (Apple's "label" / "secondaryLabel" grays)
/// - Generous corner radii, no heavy elevation/shadows, hairline borders
class AppTheme {
  AppTheme._();

  // The Apple Notes "folder" yellow — used for the primary accent so
  // buttons, focus rings, and folder icons all pick it up automatically.
  static const Color accent = Color(0xFFE8A93B);

  // Neutral palette, modeled on Apple's system gray scale in light mode.
  static const Color _background = Color(0xFFF6F6F4); // window background
  static const Color _sidebar = Color(0xFFEFEFED); // sidebar panel
  static const Color _surface = Color(0xFFFFFFFF); // cards / editor page
  static const Color _label = Color(0xFF1C1C1E); // primary text
  static const Color _secondaryLabel = Color(0xFF6E6E73); // secondary text
  static const Color _hairline = Color(0xFFE0E0DD); // dividers / borders

  static ColorScheme get _colorScheme => const ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFFCEBCB),
        onPrimaryContainer: Color(0xFF7A5100),
        secondary: _secondaryLabel,
        onSecondary: Colors.white,
        surface: _surface,
        onSurface: _label,
        surfaceContainerLow: _sidebar,
        surfaceContainerHighest: Color(0xFFEDEDEA),
        onSurfaceVariant: _secondaryLabel,
        outline: Color(0xFFC7C7C5),
        outlineVariant: _hairline,
        inverseSurface: Color(0xFF2C2C2E),
        onInverseSurface: Colors.white,
        error: Color(0xFFFF3B30),
        onError: Colors.white,
      );

  static ThemeData get light {
    final colorScheme = _colorScheme;

    // Apple's system font isn't bundled with Flutter, so we fall back to
    // the closest cross-platform matches for that SF Pro feel.
    const fontFamilyFallback = [
      '.SF Pro Text',
      'SF Pro Display',
      'Helvetica Neue',
      'Segoe UI',
      'Roboto',
    ];

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,
      splashFactory: InkRipple.splashFactory,
      fontFamilyFallback: fontFamilyFallback,
      appBarTheme: AppBarTheme(
        backgroundColor: _background,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _label,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: _secondaryLabel),
      ),
      iconTheme: const IconThemeData(color: _secondaryLabel, size: 21),
      textTheme: const TextTheme().apply(
        bodyColor: _label,
        displayColor: _label,
        fontFamilyFallback: fontFamilyFallback,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selectedTileColor: const Color(0xFFE4E4E1),
        selectedColor: _label,
        iconColor: _secondaryLabel,
        textColor: _label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        horizontalTitleGap: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFEDEDEA),
        hintStyle: const TextStyle(color: _secondaryLabel),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: accent.withOpacity(0.4),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: _secondaryLabel,
          highlightColor: accent.withOpacity(0.12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: _label,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 13,
          color: _secondaryLabel,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _hairline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2C2C2E),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),
      dividerTheme: const DividerThemeData(
        color: _hairline,
        space: 1,
        thickness: 1,
      ),
    );
  }

  // App-specific surface colors, kept in one place so both screens agree
  // on the "panel" look (sidebar / list column backgrounds).
  static Color sidebarBackground(BuildContext context) => _sidebar;

  static Color panelBackground(BuildContext context) => _background;

  static Color resizeHandleColor(BuildContext context) => _hairline;

  // The warm yellow used for folder glyphs throughout the app, matching
  // the look of folder icons in Apple Notes.
  static const Color folderIconColor = accent;
}
