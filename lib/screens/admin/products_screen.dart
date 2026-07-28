import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/app_colors.dart';
import '../../config/routes.dart';
import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/sidebar_menu.dart';
import '../../utils/formatters.dart';
import '../../utils/helpers.dart';
import '../../widgets/sync_refresh_button.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final provider = context.read<ProductProvider>();
    provider.clearAllFilters();
    await provider.loadProducts();
    _filterProducts();
    setState(() => _isLoading = false);
  }

  void _filterProducts() {
    final provider = context.read<ProductProvider>();
    final query = _searchController.text;
    provider.searchProducts(query);
    var filtered = provider.products;

    if (_selectedCategory != 'All') {
      filtered = filtered
          .where((p) => p.category == _selectedCategory)
          .toList();
    }

    setState(() {
      _filteredProducts = filtered;
    });
  }

  void _editProduct(Product product) {
    showDialog(
      context: context,
      builder: (context) => EditProductDialog(product: product),
    ).then((_) => _loadProducts());
  }

  void _confirmDelete(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(product.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(String productId) async {
    final provider = context.read<ProductProvider>();
    final success = await provider.deleteProduct(productId);

    if (!mounted) return;

    if (success) {
      Helpers.showSuccess(context, 'Product deleted successfully');
      await _loadProducts();
    } else {
      Helpers.showError(
        context,
        provider.errorMessage ?? 'Failed to delete product',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final categories = ['All', ...provider.getCategories()];

    // Calculate stats
    final totalProducts = provider.products.length;
    final lowStock = provider.products.where((p) => p.isLowStock).length;
    final outOfStock = provider.products.where((p) => p.isOutOfStock).length;
    final totalValue = provider.products.fold(
      0.0,
      (sum, p) => sum + p.totalValue,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Inventory',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => _showBulkUploadDialog(context),
            tooltip: 'Bulk Upload Products',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.addProduct);
            },
            tooltip: 'Add Product',
          ),
          const SyncRefreshButton(color: Colors.white),
        ],
      ),
      drawer: const SidebarMenu(
        selectedIndex: 3,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildSearchAndFilterBar(categories),
            _buildStatsBar(
              totalProducts: totalProducts,
              filteredCount: _filteredProducts.length,
              lowStock: lowStock,
              outOfStock: outOfStock,
              totalValue: totalValue,
            ),
            Expanded(
              child: _isLoading || provider.isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading products...',
                            style: TextStyle(color: AppColors.textLight),
                          ),
                        ],
                      ),
                    )
                  : _filteredProducts.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadProducts,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: 1300,
                            child: _buildProductTable(),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // SEARCH AND FILTER BAR
  // ============================================

  Widget _buildSearchAndFilterBar(List<String> categories) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => _filterProducts(),
                  decoration: InputDecoration(
                    hintText: 'Search by name, code or category...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textLight,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: AppColors.textLight,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _filterProducts();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _filterProducts(),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = category == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                    _filterProducts();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.text,
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // STATS BAR
  // ============================================

  Widget _buildStatsBar({
    required int totalProducts,
    required int filteredCount,
    required int lowStock,
    required int outOfStock,
    required double totalValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$filteredCount / $totalProducts',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (lowStock > 0)
                _buildStatChip('$lowStock low stock', AppColors.warning),
              if (outOfStock > 0)
                _buildStatChip('$outOfStock out of stock', AppColors.error),
            ],
          ),
          Row(
            children: [
              Text(
                'Total: ',
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              Text(
                Formatters.currency(totalValue),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (_searchController.text.isNotEmpty ||
                  _selectedCategory != 'All')
                const SizedBox(width: 12),
              if (_searchController.text.isNotEmpty ||
                  _selectedCategory != 'All')
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = 'All';
                      _searchController.clear();
                    });
                    _filterProducts();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.clear,
                          size: 14,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================
  // PRODUCT TABLE (FULL WIDTH)
  // ============================================

  Widget _buildProductTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(flex: 1, child: _buildHeaderCell('#', center: true)),
              Expanded(flex: 2, child: _buildHeaderCell('Product Code')),
              Expanded(flex: 3, child: _buildHeaderCell('Product Name')),
              Expanded(flex: 2, child: _buildHeaderCell('Category')),
              Expanded(flex: 1, child: _buildHeaderCell('Qty', center: true)),
              Expanded(
                flex: 2,
                child: _buildHeaderCell('Unit Price', center: true),
              ),
              Expanded(
                flex: 2,
                child: _buildHeaderCell('Total Value', center: true),
              ),
              Expanded(
                flex: 2,
                child: _buildHeaderCell('Status', center: true),
              ),
              Expanded(
                flex: 2,
                child: _buildHeaderCell('Actions', center: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Table Body
        ..._filteredProducts.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final product = entry.value;
          final isLowStock = product.isLowStock;
          final isOutOfStock = product.isOutOfStock;

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isOutOfStock
                  ? AppColors.error.withValues(alpha: 0.05)
                  : isLowStock
                  ? AppColors.warning.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: isLowStock || isOutOfStock
                  ? Border.all(
                      color: isOutOfStock ? AppColors.error : AppColors.warning,
                      width: 1,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                // Index
                Expanded(
                  flex: 1,
                  child: _buildCell(
                    index.toString(),
                    center: true,
                    color: AppColors.textLight,
                  ),
                ),
                // Product Code
                Expanded(
                  flex: 2,
                  child: _buildCell(
                    product.id.substring(0, 8).toUpperCase(),
                    color: AppColors.textLight,
                  ),
                ),
                // Product Name
                Expanded(
                  flex: 3,
                  child: _buildCell(product.name, isBold: true),
                ),
                // Category
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      product.category,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.info,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Quantity
                Expanded(
                  flex: 1,
                  child: _buildCell(
                    product.quantity.toString(),
                    center: true,
                    isBold: isOutOfStock,
                    color: isOutOfStock ? AppColors.error : AppColors.text,
                  ),
                ),
                // Unit Price
                Expanded(
                  flex: 2,
                  child: _buildCell(
                    Formatters.currency(product.unitPrice),
                    center: true,
                    isBold: true,
                    color: AppColors.primary,
                  ),
                ),
                // Total Value
                Expanded(
                  flex: 2,
                  child: _buildCell(
                    Formatters.currency(product.totalValue),
                    center: true,
                    isBold: true,
                    color: AppColors.primary,
                  ),
                ),
                // Status
                Expanded(flex: 2, child: _buildStatusCell(product)),
                // Actions
                Expanded(flex: 2, child: _buildActionCell(product)),
              ],
            ),
          );
        }),
      ],
    );
  }


  Widget _buildHeaderCell(String text, {bool center = false}) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      textAlign: center ? TextAlign.center : TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCell(
    String text, {
    bool isBold = false,
    Color? color,
    bool center = false,
  }) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
        color: color ?? AppColors.text,
      ),
      textAlign: center ? TextAlign.center : TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildStatusCell(Product product) {
    final isLowStock = product.isLowStock;
    final isOutOfStock = product.isOutOfStock;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isOutOfStock) {
      statusColor = AppColors.error;
      statusText = 'Out of Stock';
      statusIcon = Icons.cancel;
    } else if (isLowStock) {
      statusColor = AppColors.warning;
      statusText = 'Low Stock';
      statusIcon = Icons.warning;
    } else {
      statusColor = AppColors.success;
      statusText = 'In Stock';
      statusIcon = Icons.check_circle;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 12, color: statusColor),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCell(Product product) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
          onPressed: () => _editProduct(product),
          tooltip: 'Edit',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(
            Icons.delete_outline,
            size: 18,
            color: AppColors.error,
          ),
          onPressed: () => _confirmDelete(product),
          tooltip: 'Delete',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  // ============================================
  // EMPTY STATE
  // ============================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No products found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty || _selectedCategory != 'All'
                ? 'Try adjusting your search or filters'
                : 'Add products to your inventory',
            style: TextStyle(fontSize: 14, color: AppColors.textLight),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Add Product',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.addProduct);
            },
            icon: Icons.add,
            variant: ButtonVariant.primary,
            size: ButtonSize.medium,
          ),
        ],
      ),
    );
  }

  void _showBulkUploadDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: !_isLoading,
      builder: (context) {
        return const BulkUploadDialog();
      },
    ).then((_) => _loadProducts());
  }
}

// ============================================
// EDIT PRODUCT DIALOG
// ============================================

class EditProductDialog extends StatefulWidget {
  final Product product;

  const EditProductDialog({super.key, required this.product});

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _minStockController;
  late String _selectedCategory;

  final List<String> _categories = [
    'Pipes',
    'Fittings',
    'Valves',
    'Meters',
    'Tools',
    'Accessories',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _descriptionController = TextEditingController(
      text: widget.product.description ?? '',
    );
    _priceController = TextEditingController(
      text: widget.product.unitPrice.toString(),
    );
    _quantityController = TextEditingController(
      text: widget.product.quantity.toString(),
    );
    _minStockController = TextEditingController(
      text: widget.product.minStock.toString(),
    );
    _selectedCategory = widget.product.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = context.read<ProductProvider>();
    final success = await provider.updateProduct(
      id: widget.product.id,
      name: _nameController.text.trim(),
      category: _selectedCategory,
      unitPrice: double.parse(_priceController.text.trim()),
      quantity: int.parse(_quantityController.text.trim()),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      minStock: int.parse(_minStockController.text.trim()),
    );

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (success) {
      Helpers.showSuccess(context, 'Product updated successfully');
      Navigator.pop(context, true);
    } else {
      Helpers.showError(
        context,
        provider.errorMessage ?? 'Failed to update product',
      );
    }
  }

  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Edit Product'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _nameController,
                        label: 'Product Name',
                        hint: 'Enter product name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        value: _selectedCategory,
                        items: _categories,
                        label: 'Category',
                        hint: 'Select category',
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Enter product description',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _priceController,
                        label: 'Unit Price (KSh)',
                        hint: 'Enter unit price',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Price is required';
                          }
                          final price = double.tryParse(value);
                          if (price == null) {
                            return 'Invalid price';
                          }
                          if (price <= 0) {
                            return 'Price must be > 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _quantityController,
                        label: 'Quantity',
                        hint: 'Enter quantity',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Quantity is required';
                          }
                          final qty = int.tryParse(value);
                          if (qty == null) {
                            return 'Invalid quantity';
                          }
                          if (qty < 0) {
                            return 'Quantity cannot be negative';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _minStockController,
                  label: 'Minimum Stock Alert',
                  hint: 'Enter minimum stock level',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Min stock is required';
                    }
                    final minStock = int.tryParse(value);
                    if (minStock == null) {
                      return 'Invalid number';
                    }
                    if (minStock < 0) {
                      return 'Min stock cannot be negative';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveProduct,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: AppColors.textLight),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required String label,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: value,
          hint: Text(hint),
          items: items.map((item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
          ),
        ),
      ],
    );
  }
}

class BulkUploadDialog extends StatefulWidget {
  const BulkUploadDialog({super.key});

  @override
  State<BulkUploadDialog> createState() => _BulkUploadDialogState();
}

class _BulkUploadDialogState extends State<BulkUploadDialog> {
  bool _isProcessing = false;
  String? _statusMessage;
  List<Map<String, dynamic>> _validProducts = [];
  List<String> _errors = [];
  String? _pickedFileName;

  Future<void> _downloadTemplate() async {
    try {
      final csvContent = 'product_code,name,category,unit_price,quantity,description,subcategory,barcode,cost_price,min_stock,max_stock,unit,brand,supplier,location\n'
          'WM-05,Water Meter 1/2",Plumbing,1500.00,20,Brass water meter,Fittings,789123,1000.00,5,50,pcs,Aquadom,AquaDistributors,Aisle A\n'
          'TT-01,Teflon Tape,Plumbing,120.00,100,Thread seal tape,Fittings,789124,80.00,10,200,roll,PlumbSafe,AquaDistributors,Aisle B';

      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}${Platform.pathSeparator}products_template.csv';
      final file = File(filePath);
      await file.writeAsString(csvContent);
      if (mounted) {
        Helpers.showSuccess(context, 'Template saved to Downloads folder: $filePath');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showError(context, 'Failed to save template: $e');
      }
    }
  }

  List<List<String>> _parseCSV(String csvText) {
    final List<List<String>> rows = [];
    final List<String> lines = csvText.split('\n');
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      final List<String> fields = [];
      StringBuffer currentField = StringBuffer();
      bool inQuotes = false;
      
      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == '"') {
          inQuotes = !inQuotes;
        } else if (char == ',' && !inQuotes) {
          fields.add(currentField.toString().trim());
          currentField.clear();
        } else {
          currentField.write(char);
        }
      }
      fields.add(currentField.toString().trim());
      rows.add(fields);
    }
    return rows;
  }

  String _getVal(List<String> row, int index) {
    if (index == -1 || index >= row.length) return '';
    final field = row[index].trim();
    if (field.startsWith('"') && field.endsWith('"')) {
      return field.substring(1, field.length - 1).replaceAll('""', '"').trim();
    }
    return field;
  }

  Future<void> _pickAndParseFile() async {
    final provider = context.read<ProductProvider>();
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Reading CSV file...';
      _validProducts = [];
      _errors = [];
      _pickedFileName = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() => _isProcessing = false);
        return;
      }

      if (!mounted) return;

      final path = result.files.single.path!;
      final file = File(path);
      final csvString = await file.readAsString();
      final csvRows = _parseCSV(csvString);

      if (csvRows.isEmpty) {
        throw Exception('The CSV file is empty.');
      }

      final headers = csvRows.first.map((h) => h.toLowerCase().trim()).toList();
      final requiredFields = ['name', 'category', 'unit_price', 'quantity'];
      
      for (final rf in requiredFields) {
        if (!headers.contains(rf)) {
          throw Exception('Required column "$rf" is missing in headers.');
        }
      }

      final nameIdx = headers.indexOf('name');
      final categoryIdx = headers.indexOf('category');
      final priceIdx = headers.indexOf('unit_price');
      final quantityIdx = headers.indexOf('quantity');
      
      final descIdx = headers.indexOf('description');
      final subcatIdx = headers.indexOf('subcategory');
      
      int skuIdx = headers.indexOf('product_code');
      if (skuIdx == -1) skuIdx = headers.indexOf('sku');
      if (skuIdx == -1) skuIdx = headers.indexOf('product_sku');
      if (skuIdx == -1) skuIdx = headers.indexOf('code');
      final barcodeIdx = headers.indexOf('barcode');
      final costIdx = headers.indexOf('cost_price');
      final minStockIdx = headers.indexOf('min_stock');
      final maxStockIdx = headers.indexOf('max_stock');
      final unitIdx = headers.indexOf('unit');
      final brandIdx = headers.indexOf('brand');
      final supplierIdx = headers.indexOf('supplier');
      final locationIdx = headers.indexOf('location');

      final List<Map<String, dynamic>> validRows = [];
      final List<String> errorMessages = [];
      final existingSkus = provider.products.map((p) => p.sku?.toLowerCase()).whereType<String>().toSet();
      final Set<String> csvSkus = {};

      for (int i = 1; i < csvRows.length; i++) {
        final row = csvRows[i];
        if (row.isEmpty || (row.length == 1 && row[0].isEmpty)) continue;

        final rowNum = i + 1;
        final name = _getVal(row, nameIdx);
        final category = _getVal(row, categoryIdx);
        final priceStr = _getVal(row, priceIdx);
        final qtyStr = _getVal(row, quantityIdx);

        if (name.isEmpty) {
          errorMessages.add('Row $rowNum: Product name is empty.');
          continue;
        }
        if (category.isEmpty) {
          errorMessages.add('Row $rowNum ($name): Category is empty.');
          continue;
        }

        final double? price = double.tryParse(priceStr);
        if (price == null || price <= 0) {
          errorMessages.add('Row $rowNum ($name): Invalid unit_price "$priceStr" (must be greater than 0).');
          continue;
        }

        final int? qty = int.tryParse(qtyStr);
        if (qty == null || qty < 0) {
          errorMessages.add('Row $rowNum ($name): Invalid quantity "$qtyStr" (cannot be negative).');
          continue;
        }

        final sku = _getVal(row, skuIdx);
        if (sku.isNotEmpty) {
          final skuLower = sku.toLowerCase();
          if (existingSkus.contains(skuLower)) {
            errorMessages.add('Row $rowNum ($name): SKU "$sku" already exists in database.');
            continue;
          }
          if (csvSkus.contains(skuLower)) {
            errorMessages.add('Row $rowNum ($name): Duplicate SKU "$sku" inside CSV file.');
            continue;
          }
          csvSkus.add(skuLower);
        }

        final Map<String, dynamic> data = {
          'name': name,
          'category': category,
          'unit_price': price,
          'quantity': qty,
        };

        if (descIdx != -1) data['description'] = _getVal(row, descIdx);
        if (subcatIdx != -1) data['subcategory'] = _getVal(row, subcatIdx);
        if (skuIdx != -1 && sku.isNotEmpty) data['sku'] = sku;
        if (barcodeIdx != -1) data['barcode'] = _getVal(row, barcodeIdx);
        if (costIdx != -1) {
          final cost = double.tryParse(_getVal(row, costIdx));
          if (cost != null) data['cost_price'] = cost;
        }
        if (minStockIdx != -1) {
          final minS = int.tryParse(_getVal(row, minStockIdx));
          if (minS != null) data['min_stock'] = minS;
        }
        if (maxStockIdx != -1) {
          final maxS = int.tryParse(_getVal(row, maxStockIdx));
          if (maxS != null) data['max_stock'] = maxS;
        }
        if (unitIdx != -1) data['unit'] = _getVal(row, unitIdx);
        if (brandIdx != -1) data['brand'] = _getVal(row, brandIdx);
        if (supplierIdx != -1) data['supplier'] = _getVal(row, supplierIdx);
        if (locationIdx != -1) data['location'] = _getVal(row, locationIdx);

        validRows.add(data);
      }

      setState(() {
        _validProducts = validRows;
        _errors = errorMessages;
        _pickedFileName = result.files.single.name;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errors = ['Failed to parse CSV: ${e.toString()}'];
      });
    }
  }

  Future<void> _importProducts() async {
    if (_validProducts.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Importing ${_validProducts.length} products...';
    });

    final provider = context.read<ProductProvider>();
    final count = await provider.bulkAddProducts(_validProducts);

    if (mounted) {
      setState(() => _isProcessing = false);
      Helpers.showSuccess(context, 'Successfully imported $count products!');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: _isProcessing
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    _statusMessage ?? 'Processing...',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.upload_file, color: AppColors.primary, size: 28),
                            const SizedBox(width: 8),
                            const Text(
                              'Bulk Upload Products',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Instructions:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Download the CSV template file below.\n'
                      '2. Open it in Excel, Sheets, or a text editor and fill in your product details.\n'
                      '3. Save the file in CSV format.\n'
                      '4. Click "Select CSV File" to upload and import your inventory.',
                      style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.text),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Download Template'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _downloadTemplate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.file_upload, size: 18),
                            label: const Text('Select CSV File'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _pickAndParseFile,
                          ),
                        ),
                      ],
                    ),
                    if (_pickedFileName != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Selected file: $_pickedFileName',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_validProducts.isNotEmpty || _errors.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Validation Summary:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_validProducts.isNotEmpty)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${_validProducts.length}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                      ),
                                    ),
                                    const Text(
                                      'Valid Rows',
                                      style: TextStyle(fontSize: 12, color: AppColors.success),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_validProducts.isNotEmpty && _errors.isNotEmpty)
                            const SizedBox(width: 12),
                          if (_errors.isNotEmpty)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${_errors.length}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.error,
                                      ),
                                    ),
                                    const Text(
                                      'Errors/Warnings',
                                      style: TextStyle(fontSize: 12, color: AppColors.error),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (_errors.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Errors List:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.1)),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _errors.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.error_outline, color: AppColors.error, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _errors[index],
                                        style: const TextStyle(fontSize: 12, color: AppColors.text),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    if (_validProducts.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _importProducts,
                        child: Text('Import ${_validProducts.length} Products'),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
