import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' as fp;
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/shared_resource_model.dart';
import '../../providers/resource_provider.dart';
import '../../widgets/library/resource_card.dart';
import '../../widgets/common/empty_state.dart';

class CommunityLibraryScreen extends ConsumerStatefulWidget {
  const CommunityLibraryScreen({super.key});

  @override
  ConsumerState<CommunityLibraryScreen> createState() =>
      _CommunityLibraryScreenState();
}

class _CommunityLibraryScreenState
    extends ConsumerState<CommunityLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resourceState = ref.watch(resourceStateProvider);
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search resources...',
              prefixIcon: const Icon(Icons.search, size: 22),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(resourceStateProvider.notifier)
                            .setSearchQuery('');
                      },
                      icon: const Icon(Icons.clear, size: 20),
                    )
                  : null,
            ),
            onChanged: (value) {
              ref.read(resourceStateProvider.notifier).setSearchQuery(value);
              setState(() {});
            },
          ),
        ),

        // Categories Horizontal Scroll
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildCategoryChip('All', Icons.explore_outlined,
                  resourceState.selectedCategory == 'All'),
              ...AppConstants.resourceCategories.map((category) =>
                  _buildCategoryChip(
                    category,
                    _getCategoryIcon(category),
                    resourceState.selectedCategory == category,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Featured Section
        if (resourceState.featuredResources.isNotEmpty &&
            resourceState.selectedCategory == 'All' &&
            (resourceState.searchQuery == null ||
                resourceState.searchQuery!.isEmpty)) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.trending_up_rounded,
                    size: 18, color: AppColors.warning),
                const SizedBox(width: 6),
                const Text(
                  'Featured Resources',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: resourceState.featuredResources.length,
              itemBuilder: (context, index) {
                final resource = resourceState.featuredResources[index];
                return Container(
                  width: 200,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.primaryGreenSurface,
                        AppColors.primaryBlueSurface,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        resource.category,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

        // Resources List
        Expanded(
          child: resourceState.filteredResources.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.library_books_outlined,
                  title: 'No resources found',
                  subtitle: 'Be the first to share educational resources',
                  actionText: 'Share Resource',
                  onAction: _shareResource,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: resourceState.filteredResources.length,
                  itemBuilder: (context, index) {
                    final resource =
                        resourceState.filteredResources[index];
                    return ResourceCard(
                      resource: resource,
                      onTap: () => _showResourceDetails(resource),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(
      String label, IconData icon, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          ref
              .read(resourceStateProvider.notifier)
              .setCategory(label);
        },
        avatar: Icon(icon, size: 16),
        selectedColor: AppColors.primaryGreenSurface,
        checkmarkColor: AppColors.primaryGreen,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primaryGreen : null,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 13,
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Education':
        return Icons.school_outlined;
      case 'Agriculture':
        return Icons.agriculture_outlined;
      case 'Health':
        return Icons.local_hospital_outlined;
      case 'Business':
        return Icons.business_center_outlined;
      case 'Technology':
        return Icons.computer_outlined;
      case 'Community':
        return Icons.people_outline;
      case 'Entertainment':
        return Icons.movie_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  Future<void> _shareResource() async {
    try {
      final result = await fp.FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Share Resource'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('File: ${file.name}'),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter resource title',
                ),
                controller: TextEditingController(
                  text: file.name.split('.').first,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(resourceStateProvider.notifier).addResource(
                  title: file.name.split('.').first,
                  fileName: file.name,
                  filePath: file.path!,
                  fileSize: file.size,
                  fileType: file.extension ?? 'unknown',
                  uploaderId: 'local',
                  uploaderName: 'Me',
                  category: 'General',
                );
                Navigator.pop(ctx);
              },
              child: const Text('Share'),
            ),
          ],
        ),
      );
    } catch (_) {}
  }

  Future<void> _downloadResource(SharedResourceModel resource) async {
    if (!mounted) return;
    if (File(resource.filePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening: ${resource.fileName}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resource file not available locally')),
      );
    }
  }

  void _showResourceDetails(SharedResourceModel resource) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resource.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (resource.description != null) ...[
              const SizedBox(height: 8),
              Text(
                resource.description!,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.download, size: 16),
                const SizedBox(width: 4),
                Text('${resource.downloadCount} downloads'),
                const SizedBox(width: 16),
                const Icon(Icons.person, size: 16),
                const SizedBox(width: 4),
                Text(resource.uploaderName ?? 'Unknown'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _downloadResource(resource),
                icon: const Icon(Icons.download),
                label: const Text('Download Resource'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
