import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/product_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/sidebar_menu.dart';
import '../../utils/helpers.dart';
import '../../utils/validators.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _productCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minStockController = TextEditingController();
  final _skuController = TextEditingController();
  final _unitController = TextEditingController();
  final _brandController = TextEditingController();
  final _supplierController = TextEditingController();
  final _categoryController = TextEditingController();

  String _selectedCategory = 'Pipes';
  String? _selectedUnit;
  bool _isSubmitting = false;
  bool _showSummary = false;
  bool _isCustomCategory = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _categories = [
    'Pipes',
    'Fittings',
    'Valves',
    'Meters',
    'Tools',
    'Accessories',
    'Other',
  ];

  final List<String> _units = [
    'pcs',
    'kg',
    'm',
    'ft',
    'liters',
    'gal',
    'box',
    'set',
  ];

  @override
  void initState() {
    super.initState();
    _generateProductCode();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  void _generateProductCode() {
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomPart = (1000 + DateTime.now().millisecondsSinceEpoch % 9000)
        .toString();
    final code = 'PRD-$datePart-$randomPart';
    _productCodeController.text = code;
  }

  void _toggleSummary() {
    setState(() {
      _showSummary = !_showSummary;
    });
  }

  @override
  void dispose() {
    _productCodeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _minStockController.dispose();
    _skuController.dispose();
    _unitController.dispose();
    _brandController.dispose();
    _supplierController.dispose();
    _categoryController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _getCategoryValue() {
    if (_isCustomCategory && _categoryController.text.isNotEmpty) {
      return _categoryController.text.trim();
    }
    return _selectedCategory;
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      _showValidationError();
      return;
    }

    setState(() => _isSubmitting = true);

    final category = _getCategoryValue();

    final provider = context.read<ProductProvider>();
    final success = await provider.addProduct(
      name: _nameController.text.trim(),
      category: category,
      unitPrice: double.parse(_priceController.text.trim()),
      quantity: int.parse(_quantityController.text.trim()),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      minStock: int.parse(_minStockController.text.trim()),
      sku: _skuController.text.trim().isEmpty
          ? null
          : _skuController.text.trim(),
      unit: _selectedUnit,
      brand: _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
      supplier: _supplierController.text.trim().isEmpty
          ? null
          : _supplierController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (success) {
      Helpers.showSuccess(context, 'Product added successfully!');
      Navigator.pop(context);
    } else {
      Helpers.showError(
        context,
        provider.errorMessage ?? 'Failed to add product',
      );
    }
  }

  void _showValidationError() {
    Helpers.showSnackBar(
      context,
      'Please fill in all required fields',
      backgroundColor: AppColors.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    if (isWide)
                      _buildWideLayout()
                    else
                      _buildNarrowLayout(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================
  // LAYOUTS
  // ============================================

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (flex: 2)
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductInfoCard(isWide: true),
              const SizedBox(height: 16),
              _buildPricingStockCard(isWide: true),
            ],
          ),
        ),
        const SizedBox(width: 20),
        // Right Column (flex: 1)
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdditionalInfoCard(isWide: true),
              const SizedBox(height: 16),
              if (_showSummary) ...[
                _buildSummaryCard(),
                const SizedBox(height: 16),
              ],
              _buildActionCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductInfoCard(isWide: false),
        const SizedBox(height: 16),
        _buildPricingStockCard(isWide: false),
        const SizedBox(height: 16),
        _buildAdditionalInfoCard(isWide: false),
        const SizedBox(height: 16),
        if (_showSummary) ...[
          _buildSummaryCard(),
          const SizedBox(height: 16),
        ],
        _buildActionButtons(),
      ],
    );
  }

  // ============================================
  // DRAWER
  // ============================================

  Widget _buildDrawer() {
    return const SidebarMenu(
      selectedIndex: 3,
    );
  }

  // ============================================
  // APP BAR
  // ============================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Add Product',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(
            _showSummary ? Icons.visibility_off : Icons.visibility,
            color: Colors.white,
          ),
          onPressed: _toggleSummary,
          tooltip: _showSummary ? 'Hide Summary' : 'Show Summary',
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 36,
          child: TextButton(
            onPressed: _isSubmitting ? null : _saveProduct,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(60, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
          ),
        ),
      ],
    );
  }

  // ============================================
  // HEADER
  // ============================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Product to Inventory',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Fill in the details below to add a new product',
                  style: TextStyle(fontSize: 13, color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // PRODUCT INFO CARD
  // ============================================

  Widget _buildProductInfoCard({required bool isWide}) {
    return _buildCard(
      title: 'Product Information',
      icon: Icons.info_outline,
      iconColor: AppColors.primary,
      tag: 'Required',
      tagColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextField(
            controller: _productCodeController,
            label: 'Product Code',
            hint: 'Auto-generated',
            prefixIcon: const Icon(Icons.qr_code, size: 20),
            suffixIcon: IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: () {
                _generateProductCode();
                Helpers.showSnackBar(
                  context,
                  'Product code regenerated',
                  backgroundColor: AppColors.info,
                );
              },
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Product code is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _nameController,
                    label: 'Product Name *',
                    hint: 'Enter product name',
                    prefixIcon: const Icon(Icons.inventory_2, size: 20),
                    validator: Validators.name,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildCategoryField()),
              ],
            )
          else ...[
            CustomTextField(
              controller: _nameController,
              label: 'Product Name *',
              hint: 'Enter product name',
              prefixIcon: const Icon(Icons.inventory_2, size: 20),
              validator: Validators.name,
            ),
            const SizedBox(height: 16),
            _buildCategoryField(),
          ],
          const SizedBox(height: 16),
          CustomTextField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Enter product description (optional)',
            maxLines: 3,
            prefixIcon: const Icon(Icons.description, size: 20),
          ),
        ],
      ),
    );
  }

  // ============================================
  // CATEGORY FIELD WITH CUSTOM INPUT
  // ============================================

  Widget _buildCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isCustomCategory
                    ? CustomTextField(
                        key: const ValueKey('customCategory'),
                        controller: _categoryController,
                        label: 'Category *',
                        hint: 'Enter custom category',
                        prefixIcon: const Icon(Icons.category, size: 20),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Category is required';
                          }
                          return null;
                        },
                      )
                    : CustomDropdown<String>(
                        key: const ValueKey('dropdownCategory'),
                        value: _selectedCategory,
                        items: _categories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        label: 'Category *',
                        hint: 'Select category',
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategory = value;
                              if (value == 'Other') {
                                _isCustomCategory = true;
                                _categoryController.text = '';
                              }
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Category is required';
                          }
                          return null;
                        },
                        prefixIcon: const Icon(Icons.category, size: 20),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: _isCustomCategory
                  ? 'Switch to dropdown selection'
                  : 'Enter custom category',
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    _isCustomCategory ? Icons.list : Icons.edit,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _isCustomCategory = !_isCustomCategory;
                      if (!_isCustomCategory) {
                        _categoryController.clear();
                      } else {
                        _categoryController.text = _selectedCategory;
                      }
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isCustomCategory)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '💡 Tip: Switch to dropdown to select predefined categories',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '💡 Tip: Click the edit icon to enter a custom category',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================
  // PRICING & STOCK CARD
  // ============================================

  Widget _buildPricingStockCard({required bool isWide}) {
    final priceField = CustomTextField(
      controller: _priceController,
      label: 'Unit Price (KSh) *',
      hint: '0.00',
      keyboardType: TextInputType.number,
      prefixIcon: const Icon(Icons.attach_money, size: 20),
      validator: (value) {
        final requiredError = Validators.required(
          value,
          fieldName: 'Price',
        );
        if (requiredError != null) return requiredError;
        return Validators.positiveNumber(value, fieldName: 'Price');
      },
    );

    final qtyField = CustomTextField(
      controller: _quantityController,
      label: 'Quantity *',
      hint: '0',
      keyboardType: TextInputType.number,
      prefixIcon: const Icon(Icons.numbers, size: 20),
      validator: (value) {
        final requiredError = Validators.required(
          value,
          fieldName: 'Quantity',
        );
        if (requiredError != null) return requiredError;
        return Validators.positiveInteger(
          value,
          fieldName: 'Quantity',
        );
      },
    );

    final minStockField = CustomTextField(
      controller: _minStockController,
      label: 'Minimum Stock Alert *',
      hint: '5',
      keyboardType: TextInputType.number,
      prefixIcon: const Icon(Icons.warning_amber, size: 20),
      validator: (value) {
        final requiredError = Validators.required(
          value,
          fieldName: 'Minimum stock',
        );
        if (requiredError != null) return requiredError;
        return Validators.positiveInteger(
          value,
          fieldName: 'Minimum stock',
        );
      },
    );

    final unitDropdown = CustomDropdown<String>(
      value: _selectedUnit,
      items: _units.map((unit) {
        return DropdownMenuItem<String>(
          value: unit,
          child: Text(unit),
        );
      }).toList(),
      label: 'Unit',
      hint: 'Select unit (optional)',
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedUnit = value;
          });
        }
      },
      prefixIcon: const Icon(Icons.scale, size: 20),
    );

    return _buildCard(
      title: 'Pricing & Stock',
      icon: Icons.attach_money,
      iconColor: AppColors.secondary,
      tag: 'Required',
      tagColor: AppColors.secondary,
      child: Column(
        children: [
          if (isWide) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: priceField),
                const SizedBox(width: 16),
                Expanded(child: qtyField),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: minStockField),
                const SizedBox(width: 16),
                Expanded(child: unitDropdown),
              ],
            ),
          ] else ...[
            priceField,
            const SizedBox(height: 16),
            qtyField,
            const SizedBox(height: 16),
            minStockField,
            const SizedBox(height: 16),
            unitDropdown,
          ],
        ],
      ),
    );
  }

  // ============================================
  // ADDITIONAL INFO CARD
  // ============================================

  Widget _buildAdditionalInfoCard({required bool isWide}) {
    final skuField = CustomTextField(
      controller: _skuController,
      label: 'SKU',
      hint: 'Enter SKU (optional)',
      prefixIcon: const Icon(Icons.qr_code, size: 20),
    );

    final brandField = CustomTextField(
      controller: _brandController,
      label: 'Brand',
      hint: 'Enter brand (optional)',
      prefixIcon: const Icon(Icons.branding_watermark, size: 20),
    );

    final supplierField = CustomTextField(
      controller: _supplierController,
      label: 'Supplier',
      hint: 'Enter supplier name (optional)',
      prefixIcon: const Icon(Icons.business, size: 20),
    );

    return _buildCard(
      title: 'Additional Information',
      icon: Icons.more_horiz,
      iconColor: AppColors.info,
      tag: 'Optional',
      tagColor: AppColors.info,
      child: Column(
        children: [
          if (isWide) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: skuField),
                const SizedBox(width: 16),
                Expanded(child: brandField),
              ],
            ),
            const SizedBox(height: 16),
            supplierField,
          ] else ...[
            skuField,
            const SizedBox(height: 16),
            brandField,
            const SizedBox(height: 16),
            supplierField,
          ],
        ],
      ),
    );
  }

  // ============================================
  // CARD WIDGET
  // ============================================

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String tag,
    required Color tagColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: tagColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  // ============================================
  // SUMMARY CARD
  // ============================================

  Widget _buildSummaryCard() {
    final category = _getCategoryValue();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              const Text(
                'Product Summary',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Preview',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Code',
            _productCodeController.text.isEmpty
                ? 'Auto-generated'
                : _productCodeController.text,
          ),
          _buildSummaryRow(
            'Name',
            _nameController.text.isEmpty ? 'Not set' : _nameController.text,
          ),
          _buildSummaryRow('Category', category),
          _buildSummaryRow(
            'Price',
            _priceController.text.isEmpty
                ? 'Not set'
                : 'KSh ${_priceController.text}',
          ),
          _buildSummaryRow(
            'Quantity',
            _quantityController.text.isEmpty
                ? 'Not set'
                : _quantityController.text,
          ),
          _buildSummaryRow(
            'Min Stock',
            _minStockController.text.isEmpty
                ? 'Not set'
                : _minStockController.text,
          ),
          if (_selectedUnit != null) _buildSummaryRow('Unit', _selectedUnit!),
          if (_skuController.text.isNotEmpty)
            _buildSummaryRow('SKU', _skuController.text),
          if (_brandController.text.isNotEmpty)
            _buildSummaryRow('Brand', _brandController.text),
          if (_supplierController.text.isNotEmpty)
            _buildSummaryRow('Supplier', _supplierController.text),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    final isEmpty = value == 'Not set' || value.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isEmpty ? AppColors.textLight : AppColors.text,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ACTION BUTTONS
  // ============================================

  Widget _buildActionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.settings, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Text(
                'Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          CustomButton(
            text: _isSubmitting ? 'Adding...' : 'Add Product',
            onPressed: _isSubmitting ? null : _saveProduct,
            icon: _isSubmitting ? null : Icons.save,
            isLoading: _isSubmitting,
            variant: ButtonVariant.primary,
            size: ButtonSize.large,
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: 'Cancel',
            onPressed: () => Navigator.pop(context),
            isOutlined: true,
            variant: ButtonVariant.outlined,
            size: ButtonSize.large,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: CustomButton(
            text: _isSubmitting ? 'Adding...' : 'Add Product',
            onPressed: _isSubmitting ? null : _saveProduct,
            icon: _isSubmitting ? null : Icons.save,
            isLoading: _isSubmitting,
            variant: ButtonVariant.primary,
            size: ButtonSize.large,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: CustomButton(
            text: 'Cancel',
            onPressed: () => Navigator.pop(context),
            isOutlined: true,
            variant: ButtonVariant.outlined,
            size: ButtonSize.large,
          ),
        ),
      ],
    );
  }

  // ============================================
  // CARD DECORATION
  // ============================================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
