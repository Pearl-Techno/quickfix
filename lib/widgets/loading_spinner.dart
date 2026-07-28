import 'package:flutter/material.dart';
import '../config/app_colors.dart';

// ============================================
// LOADING SPINNER
// ============================================

class LoadingSpinner extends StatelessWidget {
  final double? size;
  final Color? color;
  final String? message;
  final double? strokeWidth;
  final bool showBackground;
  final bool showProgress;
  final double? progress;

  const LoadingSpinner({
    super.key,
    this.size,
    this.color,
    this.message,
    this.strokeWidth,
    this.showBackground = false,
    this.showProgress = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: size ?? 40,
            height: size ?? 40,
            decoration: showBackground
                ? BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  )
                : null,
            child: Center(
              child: showProgress && progress != null
                  ? SizedBox(
                      width: size ?? 40,
                      height: size ?? 40,
                      child: CircularProgressIndicator(
                        strokeWidth: strokeWidth ?? 3.5,
                        color: color ?? AppColors.primary,
                        strokeCap: StrokeCap.round,
                        value: progress!.clamp(0.0, 1.0),
                      ),
                    )
                  : SizedBox(
                      width: size ?? 40,
                      height: size ?? 40,
                      child: CircularProgressIndicator(
                        strokeWidth: strokeWidth ?? 3.5,
                        color: color ?? AppColors.primary,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (showProgress && progress != null) ...[
            const SizedBox(height: 8),
            Text(
              '${(progress! * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================
// LOADING OVERLAY
// ============================================

class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;
  final Color? overlayColor;
  final bool dismissible;
  final VoidCallback? onDismiss;
  final double? progress;
  final bool showProgress;

  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
    this.overlayColor,
    this.dismissible = false,
    this.onDismiss,
    this.progress,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            color: overlayColor ?? Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  constraints: const BoxConstraints(
                    minWidth: 160,
                    maxWidth: 280,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated spinner with progress
                      if (showProgress && progress != null)
                        SizedBox(
                          height: 48,
                          width: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.5,
                            color: AppColors.primary,
                            strokeCap: StrokeCap.round,
                            value: progress!.clamp(0.0, 1.0),
                          ),
                        )
                      else
                        const SizedBox(
                          height: 48,
                          width: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.5,
                            color: AppColors.primary,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                      if (message != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          message!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          showProgress && progress != null
                              ? '${(progress! * 100).toInt()}% complete...'
                              : 'Please wait...',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                      if (dismissible && onDismiss != null) ...[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: onDismiss,
                          child: const Text('Cancel'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================
// SKELETON LOADER
// ============================================

class SkeletonLoader extends StatelessWidget {
  final double? width;
  final double? height;
  final bool isCircle;
  final Color? baseColor;
  final double? borderRadius;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.isCircle = false,
    this.baseColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final color = baseColor ?? Colors.grey.shade200;
    final radius = borderRadius ?? 8.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: isCircle ? null : BorderRadius.circular(radius),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }
}

// ============================================
// SKELETON LIST TILE
// ============================================

class SkeletonListTile extends StatelessWidget {
  final bool hasAvatar;
  final bool hasTrailing;
  final double? width;

  const SkeletonListTile({
    super.key,
    this.hasAvatar = true,
    this.hasTrailing = true,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          if (hasAvatar) ...[
            const SkeletonLoader(width: 40, height: 40, isCircle: true),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: width ?? double.infinity, height: 16),
                const SizedBox(height: 6),
                SkeletonLoader(width: (width ?? 200) * 0.6, height: 12),
              ],
            ),
          ),
          if (hasTrailing) ...[
            const SizedBox(width: 12),
            const SkeletonLoader(width: 24, height: 24, isCircle: true),
          ],
        ],
      ),
    );
  }
}

// ============================================
// SKELETON GRID ITEM
// ============================================

class SkeletonGridItem extends StatelessWidget {
  final bool hasTitle;
  final bool hasSubtitle;

  const SkeletonGridItem({
    super.key,
    this.hasTitle = true,
    this.hasSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(width: double.infinity, height: 100),
          const SizedBox(height: 8),
          if (hasTitle) SkeletonLoader(width: double.infinity, height: 14),
          if (hasTitle) const SizedBox(height: 4),
          if (hasSubtitle) SkeletonLoader(width: 80, height: 12),
        ],
      ),
    );
  }
}

// ============================================
// SHIMMER LOADER (with shimmer effect)
// ============================================

class ShimmerLoader extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? baseColor;
  final Color? highlightColor;
  final bool enabled;

  const ShimmerLoader({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.baseColor,
    this.highlightColor,
    this.enabled = true,
  });

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return ShaderMask(
      shaderCallback: (bounds) {
        final baseColor = widget.baseColor ?? Colors.grey.shade200;
        final highlightColor = widget.highlightColor ?? Colors.grey.shade100;

        return LinearGradient(
          colors: [baseColor, highlightColor, baseColor],
          stops: const [0.0, 0.5, 1.0],
          transform: const GradientRotation(0.5),
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcATop,
      child: widget.child,
    );
  }
}

// ============================================
// SHIMMER CONTAINER
// ============================================

class ShimmerContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final double? borderRadius;
  final Duration duration;

  const ShimmerContainer({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      duration: duration,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(borderRadius ?? 8),
        ),
      ),
    );
  }
}

// ============================================
// LOADING BUTTON
// ============================================

class LoadingButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final bool fullWidth;

  const LoadingButton({
    super.key,
    required this.text,
    this.isLoading = false,
    this.onPressed,
    this.icon,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isOutlined
        ? Colors.transparent
        : backgroundColor ?? AppColors.primary;
    final fgColor = isOutlined
        ? textColor ?? AppColors.primary
        : textColor ?? Colors.white;

    return SizedBox(
      width: fullWidth ? double.infinity : width,
      height: height ?? 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isOutlined
                ? BorderSide(color: backgroundColor ?? AppColors.primary)
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: isOutlined ? AppColors.primary : Colors.white,
                  strokeCap: StrokeCap.round,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ============================================
// LOADING WIDGET WRAPPER
// ============================================

class LoadingWidget extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final Widget? loadingWidget;
  final String? loadingMessage;
  final double? loadingSize;

  const LoadingWidget({
    super.key,
    required this.isLoading,
    required this.child,
    this.loadingWidget,
    this.loadingMessage,
    this.loadingSize,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;

    return loadingWidget ??
        Center(
          child: LoadingSpinner(
            size: loadingSize,
            message: loadingMessage,
            showBackground: true,
          ),
        );
  }
}

// ============================================
// EXTENSIONS
// ============================================

extension LoadingContextExtension on BuildContext {
  void showLoadingOverlay({
    required Widget child,
    String? message,
    bool dismissible = false,
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: this,
      barrierDismissible: dismissible,
      builder: (context) => LoadingOverlay(
        isLoading: true,
        message: message,
        dismissible: dismissible,
        onDismiss: onDismiss,
        child: const SizedBox.shrink(),
      ),
    );
  }

  void hideLoadingOverlay() {
    // Use try-catch to handle cases where there's no dialog to pop
    try {
      Navigator.pop(this);
    } catch (e) {
      // Dialog already dismissed or not found
    }
  }
}
