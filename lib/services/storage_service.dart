import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:quickfix/config/constants.dart';
import 'package:quickfix/services/supabase_service.dart';
import 'package:path/path.dart' as path;

// Simple logging function that can be disabled in production
void _log(String message) {
  if (kDebugMode) {
    print(message);
  }
}

class StorageService {
  final SupabaseService _supabase = SupabaseService();

  // ============================================
  // PHOTO UPLOAD METHODS
  // ============================================

  Future<String?> uploadPhoto({
    required XFile image,
    required String quoteId,
    String? description,
    bool compress = true,
  }) async {
    try {
      final file = File(image.path);

      // Compress image if needed
      File uploadFile = file;
      if (compress) {
        final compressedFile = await _compressImage(file);
        if (compressedFile != null) {
          uploadFile = compressedFile;
        }
      }

      // Generate unique filename
      final fileName = _generateFileName(image.name);
      final filePath = 'quotes/$quoteId/$fileName';

      // Upload to Supabase Storage
      await _supabase.client.storage
          .from(Constants.photosBucket)
          .upload(filePath, uploadFile);

      // Get public URL
      final url = _supabase.client.storage
          .from(Constants.photosBucket)
          .getPublicUrl(filePath);

      // Save photo record in database
      await _supabase.client.from(SupabaseService.photosTable).insert({
        'quote_id': quoteId,
        'url': url,
        'description': description ?? '',
        'file_name': fileName,
        'file_size': await uploadFile.length(),
        'mime_type': _getMimeType(image.name),
        'created_at': DateTime.now().toIso8601String(),
      });

      return url;
    } catch (e) {
      _log('Upload photo error: $e');
      return null;
    }
  }

  Future<List<String?>> uploadMultiplePhotos({
    required List<XFile> images,
    required String quoteId,
    String? description,
    bool compress = true,
  }) async {
    final List<String?> urls = [];

    for (final image in images) {
      final url = await uploadPhoto(
        image: image,
        quoteId: quoteId,
        description: description,
        compress: compress,
      );
      urls.add(url);
    }

    return urls;
  }

  Future<String?> uploadSitePhoto({
    required XFile image,
    required String siteId,
    bool compress = true,
  }) async {
    try {
      final file = File(image.path);

      File uploadFile = file;
      if (compress) {
        final compressedFile = await _compressImage(file);
        if (compressedFile != null) {
          uploadFile = compressedFile;
        }
      }

      final fileName = _generateFileName(image.name);
      final filePath = 'sites/$siteId/$fileName';

      await _supabase.client.storage
          .from(Constants.photosBucket)
          .upload(filePath, uploadFile);

      final url = _supabase.client.storage
          .from(Constants.photosBucket)
          .getPublicUrl(filePath);

      // Save site photo record - using photosTable with site_id
      await _supabase.client.from(SupabaseService.photosTable).insert({
        'site_id': siteId,
        'url': url,
        'file_name': fileName,
        'file_size': await uploadFile.length(),
        'mime_type': _getMimeType(image.name),
        'created_at': DateTime.now().toIso8601String(),
      });

      return url;
    } catch (e) {
      _log('Upload site photo error: $e');
      return null;
    }
  }

  // ============================================
  // PROFILE IMAGE UPLOAD
  // ============================================

  Future<String?> uploadProfileImage({
    required XFile image,
    required String userId,
    bool compress = true,
  }) async {
    try {
      final file = File(image.path);

      File uploadFile = file;
      if (compress) {
        final compressedFile = await _compressImage(file);
        if (compressedFile != null) {
          uploadFile = compressedFile;
        }
      }

      final fileName = _generateFileName(image.name);
      final filePath = 'profiles/$userId/$fileName';

      await _supabase.client.storage
          .from(Constants.photosBucket)
          .upload(filePath, uploadFile);

      final url = _supabase.client.storage
          .from(Constants.photosBucket)
          .getPublicUrl(filePath);

      // Update user profile with avatar URL
      await _supabase.client
          .from(SupabaseService.usersTable)
          .update({
            'avatar_url': url,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      return url;
    } catch (e) {
      _log('Upload profile image error: $e');
      return null;
    }
  }

  // ============================================
  // RETRIEVAL METHODS
  // ============================================

  Future<List<Map<String, dynamic>>> getPhotosForQuote(String quoteId) async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.photosTable)
          .select()
          .eq('quote_id', quoteId)
          .order('created_at', ascending: false);

      return response;
    } catch (e) {
      _log('Get photos error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSitePhotos(String siteId) async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.photosTable)
          .select()
          .eq('site_id', siteId)
          .order('created_at', ascending: false);

      return response;
    } catch (e) {
      _log('Get site photos error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getPhoto(String photoId) async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.photosTable)
          .select()
          .eq('id', photoId)
          .maybeSingle();

      return response;
    } catch (e) {
      _log('Get photo error: $e');
      return null;
    }
  }

  // ============================================
  // DELETION METHODS
  // ============================================

  Future<bool> deletePhoto(String photoId) async {
    try {
      // Get photo record first
      final response = await _supabase.client
          .from(SupabaseService.photosTable)
          .select()
          .eq('id', photoId)
          .maybeSingle();

      if (response != null) {
        // Extract file path from URL
        final url = response['url'] as String;
        final filePath = _extractFilePathFromUrl(url);

        if (filePath != null) {
          // Delete from storage
          await _supabase.client.storage.from(Constants.photosBucket).remove([
            filePath,
          ]);
        }
      }

      // Delete from database
      await _supabase.client
          .from(SupabaseService.photosTable)
          .delete()
          .eq('id', photoId);

      return true;
    } catch (e) {
      _log('Delete photo error: $e');
      return false;
    }
  }

  Future<bool> deleteSitePhoto(String photoId) async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.photosTable)
          .select()
          .eq('id', photoId)
          .maybeSingle();

      if (response != null) {
        final url = response['url'] as String;
        final filePath = _extractFilePathFromUrl(url);

        if (filePath != null) {
          await _supabase.client.storage.from(Constants.photosBucket).remove([
            filePath,
          ]);
        }
      }

      await _supabase.client
          .from(SupabaseService.photosTable)
          .delete()
          .eq('id', photoId);

      return true;
    } catch (e) {
      _log('Delete site photo error: $e');
      return false;
    }
  }

  Future<bool> deleteAllPhotosForQuote(String quoteId) async {
    try {
      // Get all photos for the quote
      final photos = await getPhotosForQuote(quoteId);

      // Delete all from storage
      final filePaths = <String>[];
      for (final photo in photos) {
        final url = photo['url'] as String;
        final filePath = _extractFilePathFromUrl(url);
        if (filePath != null) {
          filePaths.add(filePath);
        }
      }

      if (filePaths.isNotEmpty) {
        await _supabase.client.storage
            .from(Constants.photosBucket)
            .remove(filePaths);
      }

      // Delete all from database
      await _supabase.client
          .from(SupabaseService.photosTable)
          .delete()
          .eq('quote_id', quoteId);

      return true;
    } catch (e) {
      _log('Delete all photos error: $e');
      return false;
    }
  }

  // ============================================
  // FILE MANAGEMENT
  // ============================================

  Future<bool> updatePhotoDescription({
    required String photoId,
    required String description,
  }) async {
    try {
      await _supabase.client
          .from(SupabaseService.photosTable)
          .update({
            'description': description,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', photoId);

      return true;
    } catch (e) {
      _log('Update photo description error: $e');
      return false;
    }
  }

  Future<String?> getPhotoUrl(String photoId) async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.photosTable)
          .select('url')
          .eq('id', photoId)
          .maybeSingle();

      return response?['url'] as String?;
    } catch (e) {
      _log('Get photo URL error: $e');
      return null;
    }
  }

  // ============================================
  // PRIVATE HELPER METHODS
  // ============================================

  String _generateFileName(String originalName) {
    final extension = path.extension(originalName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomId = DateTime.now().microsecondsSinceEpoch % 10000;
    return '${timestamp}_$randomId$extension';
  }

  String _getMimeType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }

  String? _extractFilePathFromUrl(String url) {
    try {
      // URLs are like: https://project.supabase.co/storage/v1/object/public/bucket/path/to/file
      final parts = url.split('/');
      final bucketIndex = parts.indexOf('public');
      if (bucketIndex != -1 && bucketIndex + 1 < parts.length) {
        // Skip bucket name
        return parts.sublist(bucketIndex + 2).join('/');
      }
      return null;
    } catch (e) {
      _log('Extract file path error: $e');
      return null;
    }
  }

  Future<File?> _compressImage(File file) async {
    try {
      // Check file size - if less than 1MB, don't compress
      final size = await file.length();
      if (size < 1024 * 1024) {
        return file;
      }

      // For web, we can't compress with dart:io
      if (kIsWeb) {
        return file;
      }

      // Note: This is a placeholder for actual compression
      // In production, you might want to use:
      // - flutter_image_compress package
      // - Or implement custom compression logic
      return file;
    } catch (e) {
      _log('Compress image error: $e');
      return file;
    }
  }

  // ============================================
  // STATISTICS
  // ============================================

  Future<int> getPhotoCountForQuote(String quoteId) async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.photosTable)
          .select('id')
          .eq('quote_id', quoteId);

      return response.length;
    } catch (e) {
      _log('Get photo count error: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      // Get total photos count
      final totalPhotos = await _supabase.client
          .from(SupabaseService.photosTable)
          .select('id');

      return {
        'total_photos': totalPhotos.length,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _log('Get storage stats error: $e');
      return {'total_photos': 0, 'error': e.toString()};
    }
  }

  // ============================================
  // BATCH OPERATIONS
  // ============================================

  Future<bool> movePhotosToNewQuote({
    required String oldQuoteId,
    required String newQuoteId,
  }) async {
    try {
      final photos = await getPhotosForQuote(oldQuoteId);

      for (final photo in photos) {
        await _supabase.client
            .from(SupabaseService.photosTable)
            .update({
              'quote_id': newQuoteId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', photo['id']);
      }

      return true;
    } catch (e) {
      _log('Move photos error: $e');
      return false;
    }
  }
}
