import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shared_resource_model.dart';
import '../services/resource_service.dart';

final resourceServiceProvider = Provider<ResourceService>((ref) {
  return ResourceService.instance;
});

final resourceStateProvider =
    StateNotifierProvider<ResourceNotifier, ResourceState>((ref) {
  final resourceService = ref.read(resourceServiceProvider);
  return ResourceNotifier(resourceService);
});

class ResourceState {
  final List<SharedResourceModel> resources;
  final List<SharedResourceModel> featuredResources;
  final String selectedCategory;
  final String? searchQuery;
  final bool isLoading;
  final String? error;

  const ResourceState({
    this.resources = const [],
    this.featuredResources = const [],
    this.selectedCategory = 'All',
    this.searchQuery,
    this.isLoading = false,
    this.error,
  });

  List<SharedResourceModel> get filteredResources {
    var filtered = resources;
    if (selectedCategory != 'All') {
      filtered = filtered.where((r) => r.category == selectedCategory).toList();
    }
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final query = searchQuery!.toLowerCase();
      filtered = filtered.where((r) {
        return r.title.toLowerCase().contains(query) ||
            (r.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    return filtered;
  }

  ResourceState copyWith({
    List<SharedResourceModel>? resources,
    List<SharedResourceModel>? featuredResources,
    String? selectedCategory,
    String? searchQuery,
    bool? isLoading,
    String? error,
  }) =>
      ResourceState(
        resources: resources ?? this.resources,
        featuredResources: featuredResources ?? this.featuredResources,
        selectedCategory: selectedCategory ?? this.selectedCategory,
        searchQuery: searchQuery ?? this.searchQuery,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );
}

class ResourceNotifier extends StateNotifier<ResourceState> {
  final ResourceService _resourceService;

  ResourceNotifier(this._resourceService) : super(const ResourceState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      await _resourceService.initialize();
      state = state.copyWith(
        resources: _resourceService.resources,
        featuredResources: _resourceService.getFeaturedResources(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> addResource({
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
    try {
      await _resourceService.addResource(
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
        tags: tags,
      );
      state = state.copyWith(resources: _resourceService.resources);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteResource(String resourceId) async {
    try {
      await _resourceService.deleteResource(resourceId);
      state = state.copyWith(resources: _resourceService.resources);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}
