import 'package:flutter/material.dart';
import '../config/app_colors.dart';

// ============================================
// ENUMS (Moved outside class)
// ============================================

enum ButtonSize { small, medium, large }

enum ButtonVariant {
  primary,
  secondary,
  success,
  danger,
  warning,
  info,
  outlined,
  text,
}

enum ButtonShape { rounded, pill, square }

// ============================================
// CUSTOM BUTTON WIDGET
// ============================================

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool isDanger;
  final bool isSuccess;
  final bool isWarning;
  final bool isInfo;
  final bool isDisabled;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final IconData? icon;
  final Widget? customChild;
  final bool fullWidth;
  final double? fontSize;
  final double? borderRadius;
  final EdgeInsets? padding;
  final double elevation;
  final bool showShadow;
  final ButtonSize size;
  final ButtonVariant variant;
  final ButtonShape shape;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.isDanger = false,
    this.isSuccess = false,
    this.isWarning = false,
    this.isInfo = false,
    this.isDisabled = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.icon,
    this.customChild,
    this.fullWidth = true,
    this.fontSize,
    this.borderRadius,
    this.padding,
    this.elevation = 2,
    this.showShadow = true,
    this.size = ButtonSize.medium,
    this.variant = ButtonVariant.primary,
    this.shape = ButtonShape.rounded,
  });

  // ============================================
  // COLOR LOGIC
  // ============================================

  Color get _baseColor {
    if (isDanger) return AppColors.error;
    if (isSuccess) return AppColors.success;
    if (isWarning) return AppColors.warning;
    if (isInfo) return AppColors.info;
    if (variant == ButtonVariant.secondary) return AppColors.secondary;
    if (variant == ButtonVariant.outlined) return AppColors.primary;
    if (variant == ButtonVariant.text) return AppColors.primary;
    if (variant == ButtonVariant.success) return AppColors.success;
    if (variant == ButtonVariant.danger) return AppColors.error;
    if (variant == ButtonVariant.warning) return AppColors.warning;
    if (variant == ButtonVariant.info) return AppColors.info;
    return backgroundColor ?? AppColors.primary;
  }

  Color get _contentColor {
    if (isOutlined ||
        variant == ButtonVariant.outlined ||
        variant == ButtonVariant.text) {
      if (isDanger) return AppColors.error;
      if (isSuccess) return AppColors.success;
      if (isWarning) return AppColors.warning;
      if (isInfo) return AppColors.info;
      if (variant == ButtonVariant.secondary) return AppColors.secondary;
      return textColor ?? AppColors.primary;
    }
    if (variant == ButtonVariant.text) return textColor ?? AppColors.primary;
    return textColor ?? Colors.white;
  }

  Color get _backgroundColor {
    if (isOutlined || variant == ButtonVariant.outlined) {
      return Colors.transparent;
    }
    if (variant == ButtonVariant.text) {
      return Colors.transparent;
    }
    return _baseColor;
  }

  Color get _disabledColor {
    if (isOutlined ||
        variant == ButtonVariant.outlined ||
        variant == ButtonVariant.text) {
      return Colors.grey.withValues(alpha: 0.3);
    }
    return Colors.grey.withValues(alpha: 0.5);
  }

  // ============================================
  // SIZE LOGIC
  // ============================================

  double get _height {
    if (height != null) return height!;
    switch (size) {
      case ButtonSize.small:
        return 40;
      case ButtonSize.medium:
        return 50;
      case ButtonSize.large:
        return 60;
    }
  }

  double get _fontSize {
    if (fontSize != null) return fontSize!;
    switch (size) {
      case ButtonSize.small:
        return 13;
      case ButtonSize.medium:
        return 15;
      case ButtonSize.large:
        return 17;
    }
  }

  EdgeInsets get _padding {
    if (padding != null) return padding!;
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
      case ButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 28, vertical: 16);
    }
  }

  double get _iconSize {
    switch (size) {
      case ButtonSize.small:
        return 16;
      case ButtonSize.medium:
        return 20;
      case ButtonSize.large:
        return 24;
    }
  }

  double get _borderRadiusValue {
    if (borderRadius != null) return borderRadius!;
    switch (shape) {
      case ButtonShape.rounded:
        return 12;
      case ButtonShape.pill:
        return 50;
      case ButtonShape.square:
        return 4;
    }
  }

  // ============================================
  // UI BUILDERS
  // ============================================

  LinearGradient? get _gradient {
    if (isOutlined ||
        variant == ButtonVariant.outlined ||
        variant == ButtonVariant.text) {
      return null;
    }
    if (isDisabled || isLoading) return null;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _baseColor.withValues(alpha: 1.0),
        _baseColor.withValues(alpha: 0.85),
      ],
    );
  }

  BoxShadow get _shadow {
    if (!showShadow) return const BoxShadow(color: Colors.transparent);
    if (isOutlined ||
        variant == ButtonVariant.outlined ||
        variant == ButtonVariant.text) {
      return const BoxShadow(color: Colors.transparent);
    }
    if (isDisabled || isLoading) {
      return const BoxShadow(color: Colors.transparent);
    }
    return BoxShadow(
      color: _baseColor.withValues(alpha: 0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    );
  }

  Border get _border {
    if (variant == ButtonVariant.outlined || isOutlined) {
      return Border.all(color: _baseColor.withValues(alpha: 0.5), width: 1.5);
    }
    return Border.fromBorderSide(BorderSide.none);
  }

  // ============================================
  // BUILD METHOD
  // ============================================

  @override
  Widget build(BuildContext context) {
    final bool disabled = isDisabled || isLoading || onPressed == null;
    final Color bgColor = disabled ? _disabledColor : _backgroundColor;
    final Color contentColor = disabled ? Colors.grey.shade600 : _contentColor;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: disabled ? 0.6 : 1.0,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(_borderRadiusValue),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          splashColor: contentColor.withValues(alpha: 0.15),
          highlightColor: _baseColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(_borderRadiusValue),
          child: Container(
            width: fullWidth ? double.infinity : (width ?? 140),
            height: _height,
            padding: _padding,
            decoration: BoxDecoration(
              gradient: _gradient,
              color: bgColor,
              borderRadius: BorderRadius.circular(_borderRadiusValue),
              border: _border,
              boxShadow: [_shadow],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutBack,
                child: isLoading
                    ? _buildLoadingIndicator(contentColor)
                    : _buildContent(contentColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // CONTENT BUILDERS
  // ============================================

  Widget _buildContent(Color contentColor) {
    if (customChild != null) return customChild!;

    return Row(
      key: ValueKey('content_$text'),
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: _iconSize, color: contentColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
              color: contentColor,
              letterSpacing: 0.3,
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator(Color contentColor) {
    return SizedBox(
      key: const ValueKey('loading'),
      height: 24,
      width: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(contentColor),
        strokeCap: StrokeCap.round,
      ),
    );
  }
}

// ============================================
// EXTENSIONS
// ============================================

extension CustomButtonExtensions on CustomButton {
  CustomButton withLoading(bool loading) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: loading,
      isOutlined: isOutlined,
      isDanger: isDanger,
      isSuccess: isSuccess,
      isWarning: isWarning,
      isInfo: isInfo,
      isDisabled: isDisabled,
      backgroundColor: backgroundColor,
      textColor: textColor,
      width: width,
      height: height,
      icon: icon,
      customChild: customChild,
      fullWidth: fullWidth,
      fontSize: fontSize,
      borderRadius: borderRadius,
      padding: padding,
      elevation: elevation,
      showShadow: showShadow,
      size: size,
      variant: variant,
      shape: shape,
    );
  }

  CustomButton withDisabled(bool disabled) {
    return CustomButton(
      text: text,
      onPressed: disabled ? null : onPressed,
      isLoading: isLoading,
      isOutlined: isOutlined,
      isDanger: isDanger,
      isSuccess: isSuccess,
      isWarning: isWarning,
      isInfo: isInfo,
      isDisabled: disabled,
      backgroundColor: backgroundColor,
      textColor: textColor,
      width: width,
      height: height,
      icon: icon,
      customChild: customChild,
      fullWidth: fullWidth,
      fontSize: fontSize,
      borderRadius: borderRadius,
      padding: padding,
      elevation: elevation,
      showShadow: showShadow,
      size: size,
      variant: variant,
      shape: shape,
    );
  }
}

// ============================================
// CONVENIENCE FACTORIES
// ============================================

class CustomButtons {
  static CustomButton primary({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool fullWidth = true,
    IconData? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      fullWidth: fullWidth,
      icon: icon,
      variant: ButtonVariant.primary,
    );
  }

  static CustomButton secondary({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool fullWidth = true,
    IconData? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      fullWidth: fullWidth,
      icon: icon,
      variant: ButtonVariant.secondary,
    );
  }

  static CustomButton success({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool fullWidth = true,
    IconData? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      fullWidth: fullWidth,
      icon: icon,
      variant: ButtonVariant.success,
    );
  }

  static CustomButton danger({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool fullWidth = true,
    IconData? icon,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      fullWidth: fullWidth,
      icon: icon,
      variant: ButtonVariant.danger,
    );
  }

  static CustomButton outlined({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool fullWidth = true,
    IconData? icon,
    Color? color,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      fullWidth: fullWidth,
      icon: icon,
      variant: ButtonVariant.outlined,
      textColor: color ?? AppColors.primary,
    );
  }

  static CustomButton text({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool fullWidth = true,
    IconData? icon,
    Color? color,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      fullWidth: fullWidth,
      icon: icon,
      variant: ButtonVariant.text,
      textColor: color ?? AppColors.primary,
    );
  }
}
