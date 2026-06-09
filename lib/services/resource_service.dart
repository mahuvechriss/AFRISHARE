import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../models/shared_resource_model.dart';
import '../core/database/database_helper.dart';

/// Service managing the Community Library resources
class ResourceService {
  ResourceService._();
  static final ResourceService instance = ResourceService._();

  final Uuid _uuid = const Uuid();
  final DatabaseHelper _db = DatabaseHelper.instance;

  final List<SharedResourceModel> _resources = [];

  List<SharedResourceModel> get resources => List.unmodifiable(_resources);

  /// Load all shared resources
  Future<void> initialize() async {
    final results = await _db.query(
      'shared_resources',
      orderBy: 'created_at DESC',
    );
    for (final row in results) {
      _resources.add(SharedResourceModel.fromJson(row));
    }
  }

  /// Add a resource to the community library
  Future<SharedResourceModel> addResource({
    required String title,
    String? description,
    required String category,
    String? subCategory,
    required String fileName,
    required String filePath,
    required int fileSize,
    required String fileType,
    String? thumbnailPath,
    required String uploaderId,
    String? uploaderName,
    List<String>? tags,
  }) async {
    final resource = SharedResourceModel(
      id: _uuid.v4(),
      title: title,
      description: description,
      category: category,
      subCategory: subCategory,
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
      fileType: fileType,
      thumbnailPath: thumbnailPath,
      uploaderId: uploaderId,
      uploaderName: uploaderName,
      tags: tags?.join(', '),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _resources.insert(0, resource);
    await _db.insert('shared_resources', resource.toJson());

    return resource;
  }

  /// Get resources by category
  List<SharedResourceModel> getResourcesByCategory(String category) {
    return _resources.where((r) => r.category == category).toList();
  }

  /// Get resources by sub-category
  List<SharedResourceModel> getResourcesBySubCategory(String subCategory) {
    return _resources.where((r) => r.subCategory == subCategory).toList();
  }

  /// Search resources
  List<SharedResourceModel> searchResources(String query) {
    final lowerQuery = query.toLowerCase();
    return _resources.where((r) {
      return r.title.toLowerCase().contains(lowerQuery) ||
          (r.description?.toLowerCase().contains(lowerQuery) ?? false) ||
          r.category.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Get featured resources
  List<SharedResourceModel> getFeaturedResources() {
    return _resources.where((r) => r.isFeatured).toList();
  }

  /// Increment download count
  Future<void> incrementDownload(String resourceId) async {
    final index = _resources.indexWhere((r) => r.id == resourceId);
    if (index < 0) return;

    _resources[index].downloadCount++;
    await _db.update(
      'shared_resources',
      {'download_count': _resources[index].downloadCount},
      'id = ?',
      [resourceId],
    );
  }

  /// Update resource rating
  Future<void> updateRating(String resourceId, double rating) async {
    final index = _resources.indexWhere((r) => r.id == resourceId);
    if (index < 0) return;

    _resources[index].rating = rating;
    await _db.update(
      'shared_resources',
      {'rating': rating},
      'id = ?',
      [resourceId],
    );
  }

  /// Save resource file to local storage
  Future<String?> saveResourceFile(String sourcePath, String category) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final resourcesDir = Directory('${dir.path}/resources/$category');
      await resourcesDir.create(recursive: true);

      final source = File(sourcePath);
      final fileName = source.path.split('/').last;
      final destPath = '${resourcesDir.path}/$fileName';
      await source.copy(destPath);
      return destPath;
    } catch (_) {
      return null;
    }
  }

  /// Delete a resource
  Future<void> deleteResource(String resourceId) async {
    final resource = _resources.firstWhere((r) => r.id == resourceId);

    // Clean up file
    try {
      final file = File(resource.filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}

    _resources.removeWhere((r) => r.id == resourceId);
    await _db.delete('shared_resources', 'id = ?', [resourceId]);
  }

  /// Get resources by uploader
  List<SharedResourceModel> getResourcesByUploader(String uploaderId) {
    return _resources.where((r) => r.uploaderId == uploaderId).toList();
  }

  /// Get total count
  int get totalResourceCount => _resources.length;

  /// Get total storage used by resources
  int get totalResourceSize =>
      _resources.fold(0, (sum, r) => sum + r.fileSize);

  /// Get categories with counts
  Map<String, int> getCategoriesWithCounts() {
    final counts = <String, int>{};
    for (final resource in _resources) {
      counts[resource.category] = (counts[resource.category] ?? 0) + 1;
    }
    return counts;
  }

  void dispose() {
    _resources.clear();
  }
}
