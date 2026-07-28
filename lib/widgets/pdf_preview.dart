import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_colors.dart';
import '../utils/helpers.dart';
import 'custom_button.dart';
import 'loading_spinner.dart';

class PdfPreviewWidget extends StatefulWidget {
  final File pdfFile;
  final String title;
  final VoidCallback? onShare;
  final VoidCallback? onPrint;
  final VoidCallback? onDownload;
  final String? subtitle;
  final String? fileName;
  final bool showActions;
  final Color? backgroundColor;
  final bool showFileInfo;
  final Widget? customActions;

  const PdfPreviewWidget({
    super.key,
    required this.pdfFile,
    required this.title,
    this.onShare,
    this.onPrint,
    this.onDownload,
    this.subtitle,
    this.fileName,
    this.showActions = true,
    this.backgroundColor,
    this.showFileInfo = true,
    this.customActions,
  });

  @override
  State<PdfPreviewWidget> createState() => _PdfPreviewWidgetState();
}

class _PdfPreviewWidgetState extends State<PdfPreviewWidget> {
  bool _isLoading = false;
  bool _isPrinting = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor ?? AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (widget.showFileInfo) _buildFileInfoBar(),
          if (_errorMessage != null) _buildErrorWidget(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: LoadingSpinner(
                      message: 'Loading PDF...',
                      showBackground: true,
                    ),
                  )
                  : PdfPreview(
                      build: (context) => widget.pdfFile.readAsBytesSync(),
                      allowPrinting: false,
                      allowSharing: false,
                      maxPageWidth: 700,
                      scrollViewDecoration: BoxDecoration(
                        color: widget.backgroundColor ?? AppColors.background,
                      ),
                      onError: (context, error) {
                        setState(() {
                          _errorMessage = error.toString();
                        });
                        return const SizedBox.shrink();
                      },
                      loadingWidget: const Center(
                        child: LoadingSpinner(
                          message: 'Loading PDF...',
                          showBackground: true,
                        ),
                      ),
                    ),
          ),
          if (widget.showActions) _buildActionButtons(),
        ],
      ),
    );
  }

  // ============================================
  // APP BAR
  // ============================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.subtitle != null)
            Text(
              widget.subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
      actions: [
        if (widget.customActions != null) widget.customActions!,
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: _isLoading ? null : _handleShare,
          tooltip: 'Share',
        ),
        IconButton(
          icon: const Icon(Icons.print_outlined),
          onPressed: _isLoading || _isPrinting ? null : _handlePrint,
          tooltip: 'Print',
        ),
        IconButton(
          icon: const Icon(Icons.download_outlined),
          onPressed: _isLoading ? null : _handleDownload,
          tooltip: 'Download',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ============================================
  // FILE INFO BAR
  // ============================================

  Widget _buildFileInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.picture_as_pdf,
              color: AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fileName ?? 'Document.pdf',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatFileSize(widget.pdfFile.lengthSync()),
                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Ready',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ERROR WIDGET
  // ============================================

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ACTION BUTTONS
  // ============================================

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Close',
                  onPressed: () => Navigator.pop(context),
                  isOutlined: true,
                  variant: ButtonVariant.outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CustomButton(
                  text: 'Share PDF',
                  onPressed: _isLoading ? null : _handleShare,
                  icon: Icons.share,
                  variant: ButtonVariant.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: _isPrinting ? 'Printing...' : 'Print',
                  onPressed: _isLoading || _isPrinting ? null : _handlePrint,
                  icon: Icons.print,
                  isOutlined: true,
                  isLoading: _isPrinting,
                  variant: ButtonVariant.outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CustomButton(
                  text: 'Download',
                  onPressed: _isLoading ? null : _handleDownload,
                  icon: Icons.download,
                  variant: ButtonVariant.primary,
                ),
              ),
            ],
          ),
          if (_isLoading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================
  // HANDLER METHODS
  // ============================================

  Future<void> _handleShare() async {
    if (widget.onShare != null) {
      widget.onShare!();
      return;
    }

    try {
      setState(() => _isLoading = true);

      final bytes = await widget.pdfFile.readAsBytes();

      // Create a temporary file for sharing
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/${widget.fileName ?? 'document.pdf'}',
      );
      await tempFile.writeAsBytes(bytes);

      // Use SharePlus with ShareParams
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          text: 'Check out this PDF: ${widget.title}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePrint() async {
    if (widget.onPrint != null) {
      widget.onPrint!();
      return;
    }

    try {
      setState(() => _isPrinting = true);

      await Printing.layoutPdf(
        onLayout: (format) => widget.pdfFile.readAsBytesSync(),
        name: widget.fileName ?? 'Document.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _handleDownload() async {
    if (widget.onDownload != null) {
      widget.onDownload!();
      return;
    }

    try {
      setState(() => _isLoading = true);

      final fileName = widget.fileName ?? 'document.pdf';
      final file = await Helpers.downloadPdfToLocalDisk(widget.pdfFile, fileName);
      if (file == null) throw Exception('Failed to write file to local disk');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: ${file.path}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}

// ============================================
// SIMPLE PDF VIEWER
// ============================================

class SimplePdfViewer extends StatelessWidget {
  final File pdfFile;
  final String title;

  const SimplePdfViewer({
    super.key,
    required this.pdfFile,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _handleShare(context),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _handlePrint(context),
          ),
        ],
      ),
      body: PdfPreview(
        build: (context) => pdfFile.readAsBytesSync(),
        allowPrinting: false,
        allowSharing: false,
        maxPageWidth: 700,
      ),
    );
  }

  Future<void> _handleShare(BuildContext context) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp.pdf');
      await tempFile.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          text: 'Check out this PDF: $title',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handlePrint(BuildContext context) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) => pdfFile.readAsBytesSync(),
        name: '$title.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
