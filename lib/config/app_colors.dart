// lib/config/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // ============= PRIMARY COLORS =============
  static const Color primary = Color(0xFF1A56DB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color primaryBackground = Color(0xFFEFF6FF);
  static const Color primarySurface = Color(0xFFDBEAFE);

  // ============= SECONDARY COLORS =============
  static const Color secondary = Color(0xFF10B981);
  static const Color secondaryLight = Color(0xFF34D399);
  static const Color secondaryDark = Color(0xFF059669);
  static const Color secondaryBackground = Color(0xFFECFDF5);
  static const Color secondarySurface = Color(0xFFD1FAE5);

  // ============= STATUS COLORS =============
  static const Color success = Color(0xFF10B981);
  static const Color successBackground = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBackground = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorBackground = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoBackground = Color(0xFFDBEAFE);

  // ============= NEUTRAL COLORS - LIGHT THEME =============
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color text = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textLight = Color(0xFF64748B);
  static const Color textLighter = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFE2E8F0);

  // ============= NEUTRAL COLORS - DARK THEME =============
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceVariantDark = Color(0xFF334155);
  static const Color textDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textLightDark = Color(0xFF94A3B8);
  static const Color borderDark = Color(0xFF334155);
  static const Color dividerDark = Color(0xFF334155);

  // ============= QUOTE STATUS COLORS =============
  static const Color draft = Color(0xFF94A3B8);
  static const Color draftBackground = Color(0xFFF1F5F9);
  static const Color sent = Color(0xFF3B82F6);
  static const Color sentBackground = Color(0xFFDBEAFE);
  static const Color approved = Color(0xFF10B981);
  static const Color approvedBackground = Color(0xFFD1FAE5);
  static const Color converted = Color(0xFF8B5CF6);
  static const Color convertedBackground = Color(0xFFEDE9FE);
  static const Color rejected = Color(0xFFEF4444);
  static const Color rejectedBackground = Color(0xFFFEE2E2);

  // ============= SHADOWS =============
  static const Color shadow = Color(0x1A000000);
  static const Color shadowHeavy = Color(0x33000000);
  static const Color shadowLight = Color(0x0D000000);

  // ============= OVERLAY =============
  static const Color overlay = Color(0x80000000);
  static const Color overlayLight = Color(0x4D000000);

  // ============= GRADIENTS =============
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============= UTILITY METHODS =============
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  static bool isDark(Color color) {
    return color.computeLuminance() < 0.5;
  }

  static Color getContrastColor(Color color) {
    return isDark(color) ? Colors.white : Colors.black;
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return draft;
      case 'sent':
        return sent;
      case 'approved':
        return approved;
      case 'converted':
        return converted;
      case 'rejected':
        return rejected;
      default:
        return textLight;
    }
  }

  static Color getStatusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return draftBackground;
      case 'sent':
        return sentBackground;
      case 'approved':
        return approvedBackground;
      case 'converted':
        return convertedBackground;
      case 'rejected':
        return rejectedBackground;
      default:
        return background;
    }
  }
}
