import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLines;
  final int? minLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode? autovalidateMode;
  final TextStyle? labelStyle;
  final bool isRequired;
  final String? helperText;
  final String? errorText;
  final int? maxLength;
  final bool showCounter;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool enabled;
  final bool isDense;
  final EdgeInsets? contentPadding;
  final Color? fillColor;
  final Color? textColor;
  final double? fontSize;
  final double? borderRadius;
  final Widget? prefix;
  final Widget? suffix;
  final String? initialValue;
  final void Function(String)? onFieldSubmitted;
  final void Function()? onEditingComplete;

  const CustomTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.autovalidateMode,
    this.labelStyle,
    this.isRequired = false,
    this.helperText,
    this.errorText,
    this.maxLength,
    this.showCounter = false,
    this.textInputAction,
    this.focusNode,
    this.enabled = true,
    this.isDense = false,
    this.contentPadding,
    this.fillColor,
    this.textColor,
    this.fontSize,
    this.borderRadius,
    this.prefix,
    this.suffix,
    this.initialValue,
    this.onFieldSubmitted,
    this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveFillColor =
        fillColor ?? (readOnly ? AppColors.background : Colors.white);
    final effectiveTextColor =
        textColor ?? (readOnly ? AppColors.textLight : AppColors.text);
    final radius = borderRadius ?? 12.0;
    final effectiveContentPadding =
        contentPadding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        if (label.isNotEmpty) ...[
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style:
                      labelStyle ??
                      const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isRequired) ...[
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
              if (maxLength != null && showCounter) ...[
                const Spacer(),
                Text(
                  '${controller?.text.length ?? 0}/$maxLength',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
        ],
        // Text Field
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          minLines: minLines,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          onEditingComplete: onEditingComplete,
          autovalidateMode: autovalidateMode,
          textInputAction: textInputAction,
          focusNode: focusNode,
          maxLength: maxLength,
          enabled: enabled,
          style: TextStyle(fontSize: fontSize ?? 14, color: effectiveTextColor),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textLight,
              fontSize: 14,
            ),
            labelText: label.isNotEmpty && !showLabel ? null : null,
            prefix: prefix,
            suffix: suffix,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            helperText: helperText,
            helperStyle: const TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
            ),
            errorText: errorText,
            errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
            filled: true,
            fillColor: effectiveFillColor,
            counterText: showCounter ? null : '',
            isDense: isDense,
            contentPadding: effectiveContentPadding,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }

  bool get showLabel => label.isNotEmpty;
}

// ============================================
// CUSTOM TEXT FIELD EXTENSIONS
// ============================================

extension CustomTextFieldExtensions on CustomTextField {
  CustomTextField withController(TextEditingController controller) {
    return CustomTextField(
      controller: controller,
      label: label,
      hint: hint,
      obscureText: obscureText,
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      minLines: minLines,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      autovalidateMode: autovalidateMode,
      labelStyle: labelStyle,
      isRequired: isRequired,
      helperText: helperText,
      errorText: errorText,
      maxLength: maxLength,
      showCounter: showCounter,
      textInputAction: textInputAction,
      focusNode: focusNode,
      enabled: enabled,
      isDense: isDense,
      contentPadding: contentPadding,
      fillColor: fillColor,
      textColor: textColor,
      fontSize: fontSize,
      borderRadius: borderRadius,
      prefix: prefix,
      suffix: suffix,
      initialValue: initialValue,
      onFieldSubmitted: onFieldSubmitted,
      onEditingComplete: onEditingComplete,
    );
  }

  CustomTextField withValidator(String? Function(String?)? validator) {
    return CustomTextField(
      controller: controller,
      label: label,
      hint: hint,
      obscureText: obscureText,
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      minLines: minLines,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      autovalidateMode: autovalidateMode,
      labelStyle: labelStyle,
      isRequired: isRequired,
      helperText: helperText,
      errorText: errorText,
      maxLength: maxLength,
      showCounter: showCounter,
      textInputAction: textInputAction,
      focusNode: focusNode,
      enabled: enabled,
      isDense: isDense,
      contentPadding: contentPadding,
      fillColor: fillColor,
      textColor: textColor,
      fontSize: fontSize,
      borderRadius: borderRadius,
      prefix: prefix,
      suffix: suffix,
      initialValue: initialValue,
      onFieldSubmitted: onFieldSubmitted,
      onEditingComplete: onEditingComplete,
    );
  }
}

// ============================================
// CONVENIENCE FIELD FACTORIES
// ============================================

class CustomTextFields {
  static CustomTextField email({
    required String label,
    TextEditingController? controller,
    bool isRequired = true,
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    return CustomTextField(
      controller: controller,
      label: label,
      hint: hint ?? 'Enter email address',
      keyboardType: TextInputType.emailAddress,
      isRequired: isRequired,
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return isRequired ? 'Email is required' : null;
        }
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!emailRegex.hasMatch(value)) {
          return 'Please enter a valid email address';
        }
        return null;
      },
    );
  }

  static CustomTextField password({
    required String label,
    TextEditingController? controller,
    bool isRequired = true,
    String? hint,
    bool showSuffix = true,
    bool obscureText = true,
    ValueChanged<String>? onChanged,
    VoidCallback? onToggleVisibility,
  }) {
    return CustomTextField(
      controller: controller,
      label: label,
      hint: hint ?? 'Enter password',
      obscureText: obscureText,
      isRequired: isRequired,
      onChanged: onChanged,
      suffixIcon: showSuffix
          ? IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textLight,
              ),
              onPressed: onToggleVisibility,
            )
          : null,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return isRequired ? 'Password is required' : null;
        }
        if (value.length < 8) {
          return 'Password must be at least 8 characters';
        }
        if (!RegExp(
          r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$',
        ).hasMatch(value)) {
          return 'Password must contain letters and numbers';
        }
        return null;
      },
    );
  }

  static CustomTextField phone({
    required String label,
    TextEditingController? controller,
    bool isRequired = true,
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    return CustomTextField(
      controller: controller,
      label: label,
      hint: hint ?? 'Enter phone number',
      keyboardType: TextInputType.phone,
      isRequired: isRequired,
      onChanged: onChanged,
      prefixIcon: const Icon(Icons.phone, color: AppColors.textLight),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return isRequired ? 'Phone number is required' : null;
        }
        final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
        if (!phoneRegex.hasMatch(value)) {
          return 'Please enter a valid phone number';
        }
        return null;
      },
    );
  }

  static CustomTextField number({
    required String label,
    TextEditingController? controller,
    bool isRequired = true,
    String? hint,
    double? min,
    double? max,
    ValueChanged<String>? onChanged,
  }) {
    return CustomTextField(
      controller: controller,
      label: label,
      hint: hint ?? 'Enter number',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      isRequired: isRequired,
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return isRequired ? 'Value is required' : null;
        }
        final numValue = double.tryParse(value);
        if (numValue == null) {
          return 'Please enter a valid number';
        }
        if (min != null && numValue < min) {
          return 'Value must be at least $min';
        }
        if (max != null && numValue > max) {
          return 'Value must be at most $max';
        }
        return null;
      },
    );
  }

  static CustomTextField textArea({
    required String label,
    TextEditingController? controller,
    bool isRequired = true,
    String? hint,
    int maxLines = 4,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) {
    return CustomTextField(
      controller: controller,
      label: label,
      hint: hint ?? 'Enter text...',
      maxLines: maxLines,
      minLines: 3,
      maxLength: maxLength,
      isRequired: isRequired,
      onChanged: onChanged,
      showCounter: true,
    );
  }

  static CustomTextField search({
    required String label,
    TextEditingController? controller,
    String? hint,
    ValueChanged<String>? onChanged,
    VoidCallback? onClear,
  }) {
    return CustomTextField(
      controller: controller,
      label: label,
      hint: hint ?? 'Search...',
      prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
      onChanged: onChanged,
      suffixIcon: controller != null && controller.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear, color: AppColors.textLight),
              onPressed:
                  onClear ??
                  () {
                    controller.clear();
                    onChanged?.call('');
                  },
            )
          : null,
    );
  }
}

// ============================================
// CUSTOM FIELD WITH LABEL AND ERROR
// ============================================

class CustomFieldWrapper extends StatelessWidget {
  final Widget child;
  final String label;
  final bool isRequired;
  final String? errorText;
  final String? helperText;
  final Widget? suffix;
  final double? spacing;

  const CustomFieldWrapper({
    super.key,
    required this.child,
    required this.label,
    this.isRequired = false,
    this.errorText,
    this.helperText,
    this.suffix,
    this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.text,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
            if (suffix != null) ...[const Spacer(), suffix!],
          ],
        ),
        SizedBox(height: spacing ?? 6),
        child,
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
        ],
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ],
      ],
    );
  }
}
