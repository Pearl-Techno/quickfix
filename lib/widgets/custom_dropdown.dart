import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class CustomDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final String label;
  final String? hint;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  final bool isExpanded;
  final bool isRequired;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool isSearchable;
  final bool isClearable;
  final VoidCallback? onClear;
  final String? searchHint;
  final double? borderRadius;
  final Color? dropdownColor;
  final Color? focusColor;
  final bool showLabel;
  final TextStyle? labelStyle;
  final TextStyle? hintStyle;
  final EdgeInsets? contentPadding;
  final bool enabled;
  final bool autofocus;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.label,
    this.hint,
    this.onChanged,
    this.validator,
    this.isExpanded = true,
    this.isRequired = false,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.isSearchable = false,
    this.isClearable = false,
    this.onClear,
    this.searchHint,
    this.borderRadius,
    this.dropdownColor,
    this.focusColor,
    this.showLabel = true,
    this.labelStyle,
    this.hintStyle,
    this.contentPadding,
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
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
            ],
          ),
          const SizedBox(height: 6),
        ],
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          validator: validator,
          isExpanded: isExpanded,
          autofocus: autofocus,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                hintStyle ??
                const TextStyle(color: AppColors.textLight, fontSize: 14),
            helperText: helperText,
            helperStyle: const TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
            ),
            errorText: errorText,
            errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconTheme(
                      data: const IconThemeData(
                        color: AppColors.textLight,
                        size: 20,
                      ),
                      child: prefixIcon!,
                    ),
                  )
                : null,
            suffixIcon: _buildSuffixIcon(),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade50,
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
            contentPadding:
                contentPadding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          dropdownColor: dropdownColor ?? Colors.white,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: enabled ? AppColors.textLight : AppColors.border,
          ),
          style: TextStyle(
            fontSize: 14,
            color: enabled ? AppColors.text : AppColors.textLight,
          ),
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(radius),
          isDense: true,
          selectedItemBuilder: (context) {
            return items.map((item) {
              return Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  _getDropdownText(item.child),
                  style: TextStyle(
                    fontSize: 14,
                    color: enabled ? AppColors.text : AppColors.textLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList();
          },
        ),
        // Helper text with required indicator
        if (isRequired && (value == null || value == '')) ...[
          const SizedBox(height: 4),
          Text(
            'Please select a $label',
            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
        ],
      ],
    );
  }

  String _getDropdownText(Widget widget) {
    if (widget is Text) {
      return widget.data ?? '';
    }
    if (widget is MultiChildRenderObjectWidget) {
      for (final child in widget.children) {
        final text = _getDropdownText(child);
        if (text.isNotEmpty) return text;
      }
    }
    if (widget is SingleChildRenderObjectWidget) {
      if (widget.child != null) {
        return _getDropdownText(widget.child!);
      }
    }
    if (widget is Container) {
      if (widget.child != null) {
        return _getDropdownText(widget.child!);
      }
    }
    return '';
  }

  Widget? _buildSuffixIcon() {
    if (suffixIcon != null) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: IconTheme(
          data: const IconThemeData(color: AppColors.textLight, size: 20),
          child: suffixIcon!,
        ),
      );
    }

    if (isClearable && value != null && onClear != null) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onClear,
          child: Icon(Icons.clear, color: AppColors.textLight, size: 20),
        ),
      );
    }

    return null;
  }
}

// ============================================
// SEARCHABLE DROPDOWN (Extended Version)
// ============================================

class SearchableDropdown<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final String label;
  final String Function(T) displayName;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final bool isRequired;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final bool enabled;
  final double? borderRadius;
  final bool showLabel;
  final String? searchHint;
  final List<T> Function(String query)? filterFunction;

  const SearchableDropdown({
    super.key,
    required this.items,
    required this.displayName,
    required this.label,
    this.value,
    this.onChanged,
    this.hint,
    this.isRequired = false,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.enabled = true,
    this.borderRadius,
    this.showLabel = true,
    this.searchHint,
    this.filterFunction,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  List<T> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.items;
    if (widget.filterFunction != null) {
      return widget.filterFunction!(_searchQuery);
    }
    return widget.items.where((item) {
      final name = widget.displayName(item).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  T? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.value;
  }

  @override
  void didUpdateWidget(SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      setState(() {
        _selectedValue = widget.value;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel) ...[
          Row(
            children: [
              Flexible(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.isRequired) ...[
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
            ],
          ),
          const SizedBox(height: 6),
        ],
        GestureDetector(
          onTap: widget.enabled ? _showSearchDialog : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: widget.enabled ? Colors.white : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: widget.errorText != null
                    ? AppColors.error
                    : AppColors.border,
                width: widget.errorText != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                if (widget.prefixIcon != null) ...[
                  widget.prefixIcon!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedValue == null) ...[
                        Text(
                          widget.hint ?? 'Select ${widget.label}',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                        ),
                      ] else ...[
                        Text(
                          widget.displayName(_selectedValue as T),
                          style: TextStyle(
                            color: widget.enabled
                                ? AppColors.text
                                : AppColors.textLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_selectedValue != null && widget.enabled)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    color: AppColors.textLight,
                    onPressed: () {
                      setState(() {
                        _selectedValue = null;
                        widget.onChanged?.call(null);
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: widget.enabled
                      ? AppColors.textLight
                      : AppColors.border,
                ),
              ],
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ],
        if (widget.helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helperText!,
            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
        ],
      ],
    );
  }

  void _showSearchDialog() {
    _searchController.clear();
    _searchQuery = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              height: 400,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: widget.searchHint ?? 'Search...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textLight,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setStateDialog(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (value) {
                        setStateDialog(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Items list
                  Expanded(
                    child: _filteredItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: AppColors.textLight,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No items found',
                                  style: TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = _filteredItems[index];
                              final isSelected = item == _selectedValue;
                              return ListTile(
                                leading: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: AppColors.primary,
                                      )
                                    : null,
                                title: Text(
                                  widget.displayName(item),
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.text,
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedValue = item;
                                    widget.onChanged?.call(item);
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      if (_selectedValue != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedValue = null;
                              widget.onChanged?.call(null);
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      // Focus back to the search field if dialog was dismissed
      _focusNode.requestFocus();
    });
  }
}

// ============================================
// DROPDOWN HELPER
// ============================================

class DropdownHelper {
  static List<DropdownMenuItem<String>> fromList(
    List<String> items, {
    String? Function(String)? labelMapper,
  }) {
    return items.map((item) {
      return DropdownMenuItem<String>(
        value: item,
        child: Text(
          labelMapper?.call(item) ?? item,
          style: const TextStyle(fontSize: 14),
        ),
      );
    }).toList();
  }

  static List<DropdownMenuItem<T>> fromMap<T>(
    List<T> items,
    String Function(T) labelMapper,
  ) {
    return items.map((item) {
      return DropdownMenuItem<T>(
        value: item,
        child: Text(labelMapper(item), style: const TextStyle(fontSize: 14)),
      );
    }).toList();
  }

  static List<DropdownMenuItem<T>> fromMapWithIcon<T>(
    List<T> items,
    String Function(T) labelMapper,
    IconData Function(T) iconMapper,
  ) {
    return items.map((item) {
      return DropdownMenuItem<T>(
        value: item,
        child: Row(
          children: [
            Icon(iconMapper(item), size: 18, color: AppColors.textLight),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                labelMapper(item),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  static List<DropdownMenuItem<String>> fromListWithIcons(
    List<Map<String, dynamic>> items, {
    required String valueKey,
    required String labelKey,
    String? iconKey,
  }) {
    return items.map((item) {
      return DropdownMenuItem<String>(
        value: item[valueKey].toString(),
        child: Row(
          children: [
            if (iconKey != null && item[iconKey] != null) ...[
              Icon(
                item[iconKey] as IconData?,
                size: 18,
                color: AppColors.textLight,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                item[labelKey].toString(),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  static List<DropdownMenuItem<String>> filterItems(
    List<String> items,
    String query, {
    String? Function(String)? labelMapper,
  }) {
    final filtered = items.where((item) {
      final label = labelMapper?.call(item) ?? item;
      return label.toLowerCase().contains(query.toLowerCase());
    }).toList();
    return fromList(filtered, labelMapper: labelMapper);
  }

  static List<DropdownMenuItem<int>> fromIntRange(
    int start,
    int end, {
    String Function(int)? labelMapper,
  }) {
    final items = <DropdownMenuItem<int>>[];
    for (int i = start; i <= end; i++) {
      items.add(
        DropdownMenuItem<int>(
          value: i,
          child: Text(
            labelMapper?.call(i) ?? i.toString(),
            style: const TextStyle(fontSize: 14),
          ),
        ),
      );
    }
    return items;
  }
}
