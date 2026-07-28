// lib/config/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // Border Radius Constants
  static const BorderRadius _radiusSmall = BorderRadius.all(Radius.circular(4));
  static const BorderRadius _radiusMedium = BorderRadius.all(
    Radius.circular(8),
  );
  static const BorderRadius _radiusLarge = BorderRadius.all(
    Radius.circular(12),
  );
  static const BorderRadius _radiusXLarge = BorderRadius.all(
    Radius.circular(16),
  );

  // Spacing Constants
  static const double _spacingSM = 8.0;
  static const double _spacingMD = 12.0;
  static const double _spacingLG = 16.0;

  // Elevation Constants
  static const double _elevationLow = 1;
  static const double _elevationMedium = 2;
  static const double _elevationHigh = 4;

  // Button Height
  static const double _buttonHeight = 50.0;

  // ============= LIGHT THEME =============
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryBackground,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryBackground,
      onSecondaryContainer: AppColors.secondaryDark,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceTint: AppColors.primary,
      outline: AppColors.border,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorBackground,
      onErrorContainer: AppColors.error,
      tertiary: AppColors.info,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.infoBackground,
      onTertiaryContainer: AppColors.info,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: _elevationLow,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      toolbarHeight: 60,
      iconTheme: IconThemeData(color: AppColors.text),
      actionsIconTheme: IconThemeData(color: AppColors.text),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, _buttonHeight),
        shape: RoundedRectangleBorder(borderRadius: _radiusLarge),
        elevation: _elevationMedium,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        minimumSize: const Size(double.infinity, _buttonHeight),
        shape: RoundedRectangleBorder(borderRadius: _radiusLarge),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(double.infinity, _buttonHeight),
        shape: RoundedRectangleBorder(borderRadius: _radiusLarge),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: _spacingLG,
        vertical: _spacingMD,
      ),
      border: OutlineInputBorder(
        borderRadius: _radiusLarge,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _radiusLarge,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _radiusLarge,
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: _radiusLarge,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: _radiusLarge,
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      labelStyle: const TextStyle(
        color: AppColors.textLight,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
      prefixIconColor: AppColors.textLight,
      suffixIconColor: AppColors.textLight,
    ),
    cardTheme: CardThemeData(
      elevation: _elevationMedium,
      shape: RoundedRectangleBorder(borderRadius: _radiusLarge),
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(_spacingSM),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primaryBackground,
      selectedColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(
        horizontal: _spacingMD,
        vertical: _spacingSM,
      ),
      labelStyle: const TextStyle(
        color: AppColors.text,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: _radiusMedium),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      elevation: _elevationHigh,
      shape: RoundedRectangleBorder(borderRadius: _radiusXLarge),
      titleTextStyle: const TextStyle(
        color: AppColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.text,
      contentTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: _radiusLarge),
      elevation: _elevationHigh,
      actionTextColor: AppColors.primaryLight,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      elevation: _elevationHigh,
      modalBackgroundColor: AppColors.surface,
      modalElevation: _elevationHigh,
      showDragHandle: true,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textLight,
      indicatorColor: AppColors.primary,
      dividerColor: AppColors.border,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      indicatorSize: TabBarIndicatorSize.label,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.25,
        color: AppColors.text,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: AppColors.text,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: AppColors.text,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.text,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.text,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.text,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: AppColors.text,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        color: AppColors.text,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: AppColors.text,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: AppColors.text,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: AppColors.text,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: AppColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: AppColors.text,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.textLight,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: _spacingLG,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: const BoxDecoration(
        color: AppColors.text,
        borderRadius: _radiusSmall,
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: _spacingLG,
        vertical: _spacingSM,
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.surface,
      elevation: _elevationHigh,
      shape: RoundedRectangleBorder(borderRadius: _radiusLarge),
      textStyle: TextStyle(color: AppColors.text, fontSize: 14),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: _spacingLG,
        vertical: _spacingSM,
      ),
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
      iconColor: AppColors.primary,
      textColor: AppColors.text,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return AppColors.primary;
      }),
      shape: RoundedRectangleBorder(borderRadius: _radiusSmall),
      side: const BorderSide(color: AppColors.border, width: 1.5),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return AppColors.surface;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.border;
      }),
    ),
    badgeTheme: const BadgeThemeData(
      backgroundColor: AppColors.error,
      textStyle: TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _spacingSM,
        vertical: _spacingSM,
      ),
      smallSize: 16,
      largeSize: 24,
    ),
  );

  // ============= DARK THEME =============
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryLight,
      onPrimary: AppColors.textDark,
      primaryContainer: AppColors.primaryBackground,
      onPrimaryContainer: AppColors.primaryLight,
      secondary: AppColors.secondaryLight,
      onSecondary: AppColors.textDark,
      secondaryContainer: AppColors.secondaryBackground,
      onSecondaryContainer: AppColors.secondaryLight,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textDark,
      surfaceTint: AppColors.primaryLight,
      outline: AppColors.borderDark,
      error: AppColors.error,
      onError: AppColors.textDark,
      errorContainer: AppColors.errorBackground,
      onErrorContainer: AppColors.error,
      tertiary: AppColors.info,
      onTertiary: AppColors.textDark,
      tertiaryContainer: AppColors.infoBackground,
      onTertiaryContainer: AppColors.info,
    ),
    scaffoldBackgroundColor: AppColors.backgroundDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceDark,
      foregroundColor: AppColors.textDark,
      elevation: _elevationLow,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: AppColors.textDark,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      toolbarHeight: 60,
      iconTheme: IconThemeData(color: AppColors.textDark),
      actionsIconTheme: IconThemeData(color: AppColors.textDark),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.textDark,
        minimumSize: const Size(double.infinity, _buttonHeight),
        shape: RoundedRectangleBorder(borderRadius: _radiusLarge),
        elevation: _elevationMedium,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        minimumSize: const Size(double.infinity, _buttonHeight),
        shape: RoundedRectangleBorder(borderRadius: _radiusLarge),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        minimumSize: const Size(double.infinity, _buttonHeight),
        shape: RoundedRectangleBorder(borderRadius: _radiusLarge),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceDark,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: _spacingLG,
        vertical: _spacingMD,
      ),
      border: OutlineInputBorder(
        borderRadius: _radiusLarge,
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _radiusLarge,
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _radiusLarge,
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: _radiusLarge,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: _radiusLarge,
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      labelStyle: const TextStyle(
        color: AppColors.textLightDark,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primaryLight,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: AppColors.textLightDark, fontSize: 14),
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
      prefixIconColor: AppColors.textLightDark,
      suffixIconColor: AppColors.textLightDark,
    ),
    cardTheme: CardThemeData(
      elevation: _elevationMedium,
      shape: RoundedRectangleBorder(borderRadius: _radiusLarge),
      color: AppColors.surfaceDark,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(_spacingSM),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primaryBackground,
      selectedColor: AppColors.primaryLight,
      padding: const EdgeInsets.symmetric(
        horizontal: _spacingMD,
        vertical: _spacingSM,
      ),
      labelStyle: const TextStyle(
        color: AppColors.textDark,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      side: const BorderSide(color: AppColors.borderDark),
      shape: RoundedRectangleBorder(borderRadius: _radiusMedium),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceDark,
      elevation: _elevationHigh,
      shape: RoundedRectangleBorder(borderRadius: _radiusXLarge),
      titleTextStyle: const TextStyle(
        color: AppColors.textDark,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.textSecondaryDark,
        fontSize: 14,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textDark,
      contentTextStyle: TextStyle(
        color: AppColors.backgroundDark,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: _radiusLarge),
      elevation: _elevationHigh,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceDark,
      elevation: _elevationHigh,
      modalBackgroundColor: AppColors.surfaceDark,
      modalElevation: _elevationHigh,
      showDragHandle: true,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.primaryLight,
      unselectedLabelColor: AppColors.textLightDark,
      indicatorColor: AppColors.primaryLight,
      dividerColor: AppColors.borderDark,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      indicatorSize: TabBarIndicatorSize.label,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.25,
        color: AppColors.textDark,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: AppColors.textDark,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.textDark,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.textDark,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: AppColors.textDark,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: AppColors.textDark,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        color: AppColors.textDark,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: AppColors.textDark,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: AppColors.textDark,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: AppColors.textDark,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: AppColors.textSecondaryDark,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: AppColors.textDark,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.textSecondaryDark,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.textLightDark,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderDark,
      thickness: 1,
      space: _spacingLG,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: const BoxDecoration(
        color: AppColors.textDark,
        borderRadius: _radiusSmall,
      ),
      textStyle: const TextStyle(
        color: AppColors.backgroundDark,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: _spacingLG,
        vertical: _spacingSM,
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.surfaceDark,
      elevation: _elevationHigh,
      shape: RoundedRectangleBorder(borderRadius: _radiusLarge),
      textStyle: TextStyle(color: AppColors.textDark, fontSize: 14),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: _spacingLG,
        vertical: _spacingSM,
      ),
      titleTextStyle: TextStyle(
        color: AppColors.textDark,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: TextStyle(
        color: AppColors.textSecondaryDark,
        fontSize: 14,
      ),
      iconColor: AppColors.primaryLight,
      textColor: AppColors.textDark,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryLight;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.textDark;
        }
        return AppColors.primaryLight;
      }),
      shape: RoundedRectangleBorder(borderRadius: _radiusSmall),
      side: const BorderSide(color: AppColors.borderDark, width: 1.5),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.textDark;
        }
        return AppColors.surfaceDark;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryLight;
        }
        return AppColors.borderDark;
      }),
    ),
    badgeTheme: const BadgeThemeData(
      backgroundColor: AppColors.error,
      textStyle: TextStyle(
        color: AppColors.textDark,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _spacingSM,
        vertical: _spacingSM,
      ),
      smallSize: 16,
      largeSize: 24,
    ),
  );
}

// ============= THEME EXTENSIONS =============
extension AppThemeExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  // Spacing getters
  EdgeInsets get paddingSM => const EdgeInsets.all(AppTheme._spacingSM);
  EdgeInsets get paddingMD => const EdgeInsets.all(AppTheme._spacingMD);
  EdgeInsets get paddingLG => const EdgeInsets.all(AppTheme._spacingLG);

  // Border radius
  BorderRadius get radiusSmall => AppTheme._radiusSmall;
  BorderRadius get radiusMedium => AppTheme._radiusMedium;
  BorderRadius get radiusLarge => AppTheme._radiusLarge;
  BorderRadius get radiusXLarge => AppTheme._radiusXLarge;

  // Status colors
  Color get successColor => AppColors.success;
  Color get warningColor => AppColors.warning;
  Color get errorColor => AppColors.error;
  Color get infoColor => AppColors.info;
}
