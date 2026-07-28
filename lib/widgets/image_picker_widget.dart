import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import '../config/app_colors.dart';
import '../utils/helpers.dart';

class ImagePickerWidget extends StatefulWidget {
  final Function(List<XFile>) onImagesSelected;
  final int maxImages;
  final List<String>? existingImageUrls;
  final Function(String)? onImageRemoved;
  final String? label;
  final bool showLabel;
  final bool showPreview;
  final double imageSize;
  final int crossAxisCount;
  final bool showAddButton;
  final String addButtonText;
  final bool allowMultiple;
  final bool compressImages;
  final int imageQuality;

  const ImagePickerWidget({
    super.key,
    required this.onImagesSelected,
    this.maxImages = 5,
    this.existingImageUrls,
    this.onImageRemoved,
    this.label,
    this.showLabel = true,
    this.showPreview = true,
    this.imageSize = 100,
    this.crossAxisCount = 3,
    this.showAddButton = true,
    this.addButtonText = 'Add Photos',
    this.allowMultiple = true,
    this.compressImages = true,
    this.imageQuality = 80,
  });

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _isLoading = false;
  late AnimationController _animationController;
  final List<String> _deletedExistingImages = [];

  @override
  void initState() {
    super.initState();
    _selectedImages = [];
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ImagePickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.existingImageUrls != widget.existingImageUrls) {
      _deletedExistingImages.clear();
    }
  }

  // ============================================
  // IMAGE PICKING METHODS
  // ============================================

  Future<void> _pickImage(ImageSource source) async {
    if (_selectedImages.length >= widget.maxImages) {
      _showMaxImagesWarning();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: widget.compressImages ? widget.imageQuality : null,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (mounted && image != null) {
        _addImage(image);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showError(context, 'Failed to pick image: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickMultipleImages() async {
    if (_selectedImages.length >= widget.maxImages) {
      _showMaxImagesWarning();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final images = await _picker.pickMultiImage(
        imageQuality: widget.compressImages ? widget.imageQuality : null,
      );

      if (mounted && images.isNotEmpty) {
        final remaining = widget.maxImages - _selectedImages.length;
        final newImages = images.take(remaining).toList();
        _addImages(newImages);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showError(context, 'Failed to pick images: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickFromCamera() async {
    await _pickImage(ImageSource.camera);
  }

  Future<void> _pickFromGallery() async {
    if (widget.allowMultiple) {
      await _pickMultipleImages();
    } else {
      await _pickImage(ImageSource.gallery);
    }
  }

  // ============================================
  // IMAGE MANAGEMENT
  // ============================================

  void _addImage(XFile image) {
    setState(() {
      _selectedImages.add(image);
      _animationController.forward(from: 0);
    });
    widget.onImagesSelected(_selectedImages);
  }

  void _addImages(List<XFile> images) {
    setState(() {
      _selectedImages.addAll(images);
      _animationController.forward(from: 0);
    });
    widget.onImagesSelected(_selectedImages);
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    widget.onImagesSelected(_selectedImages);
  }

  void _removeExistingImage(int index) {
    final imageUrl = widget.existingImageUrls![index];
    setState(() {
      _deletedExistingImages.add(imageUrl);
    });
    if (widget.onImageRemoved != null) {
      widget.onImageRemoved!(imageUrl);
    }
  }

  void _showMaxImagesWarning() {
    if (mounted) {
      Helpers.showSnackBar(
        context,
        'Maximum ${widget.maxImages} images allowed',
        backgroundColor: AppColors.warning,
      );
    }
  }

  // ============================================
  // PREVIEW METHODS
  // ============================================

  void _showImagePreview(String imagePath, {bool isNetwork = false}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: isNetwork
                  ? PhotoView(
                      imageProvider: NetworkImage(imagePath),
                      backgroundDecoration: const BoxDecoration(
                        color: Colors.black,
                      ),
                      maxScale: PhotoViewComputedScale.covered * 3,
                      minScale: PhotoViewComputedScale.contained,
                      initialScale: PhotoViewComputedScale.contained,
                    )
                  : PhotoView(
                      imageProvider: FileImage(File(imagePath)),
                      backgroundDecoration: const BoxDecoration(
                        color: Colors.black,
                      ),
                      maxScale: PhotoViewComputedScale.covered * 3,
                      minScale: PhotoViewComputedScale.contained,
                      initialScale: PhotoViewComputedScale.contained,
                    ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // DIALOG BUILDERS
  // ============================================

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add ${widget.label ?? 'Photos'}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose from camera or gallery',
                style: TextStyle(fontSize: 14, color: AppColors.textLight),
              ),
              const SizedBox(height: 16),
              _buildSourceTile(
                icon: Icons.photo_camera,
                title: 'Take Photo',
                subtitle: 'Capture a new photo with your camera',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(context);
                  _pickFromCamera();
                },
              ),
              _buildSourceTile(
                icon: Icons.photo_library,
                title: 'Choose from Gallery',
                subtitle: widget.allowMultiple
                    ? 'Select multiple photos from your gallery'
                    : 'Select a photo from your gallery',
                color: AppColors.secondary,
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: AppColors.textLight),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
      onTap: onTap,
    );
  }

  // ============================================
  // MAIN BUILD METHOD
  // ============================================

  @override
  Widget build(BuildContext context) {
    final totalImages =
        _selectedImages.length +
        (widget.existingImageUrls?.length ?? 0) -
        _deletedExistingImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (widget.showLabel && widget.label != null) ...[
          Row(
            children: [
              Text(
                widget.label!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalImages/${widget.maxImages}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // Image grid - using GridView.builder with reorder functionality
        if (totalImages > 0 && widget.showPreview) _buildImageGrid(totalImages),

        if (totalImages > 0 && widget.showPreview) const SizedBox(height: 12),

        // Add image button
        if (widget.showAddButton && _selectedImages.length < widget.maxImages)
          _buildAddButton(),
      ],
    );
  }

  // ============================================
  // IMAGE GRID
  // ============================================

  Widget _buildImageGrid(int totalImages) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: totalImages,
      itemBuilder: (context, index) {
        final isExisting =
            index < (widget.existingImageUrls?.length ?? 0) &&
            !_deletedExistingImages.contains(widget.existingImageUrls![index]);
        final imageIndex = isExisting
            ? index
            : index -
                  (widget.existingImageUrls?.length ?? 0) +
                  _deletedExistingImages.length;

        return _buildImageItem(
          index: index,
          isExisting: isExisting,
          imageIndex: imageIndex,
          totalImages: totalImages,
        );
      },
    );
  }

  // ============================================
  // WIDGET BUILDERS
  // ============================================

  Widget _buildImageItem({
    required int index,
    required bool isExisting,
    required int imageIndex,
    required int totalImages,
  }) {
    return Container(
      key: ValueKey('image_$index'),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.9 + (0.1 * _animationController.value),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: isExisting
                      ? _buildNetworkImage(
                          widget.existingImageUrls![imageIndex],
                        )
                      : _buildLocalImage(_selectedImages[imageIndex].path),
                ),
                // Image number badge
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Preview button
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: GestureDetector(
                    onTap: () {
                      if (isExisting) {
                        _showImagePreview(
                          widget.existingImageUrls![imageIndex],
                          isNetwork: true,
                        );
                      } else {
                        _showImagePreview(
                          _selectedImages[imageIndex].path,
                          isNetwork: false,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.zoom_in,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Remove button
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      if (isExisting) {
                        _removeExistingImage(imageIndex);
                      } else {
                        _removeImage(imageIndex);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNetworkImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppColors.background,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.border,
          child: const Icon(
            Icons.broken_image,
            color: AppColors.textLight,
            size: 30,
          ),
        );
      },
    );
  }

  Widget _buildLocalImage(String path) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.border,
          child: const Icon(
            Icons.broken_image,
            color: AppColors.textLight,
            size: 30,
          ),
        );
      },
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _showImageSourceDialog,
      child: Container(
        height: widget.imageSize,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.border,
            style: BorderStyle.solid,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.background,
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate,
                    color: AppColors.textLight,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.addButtonText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textLight,
                    ),
                  ),
                  Text(
                    '${_selectedImages.length}/${widget.maxImages} used',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
