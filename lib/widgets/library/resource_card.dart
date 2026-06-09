import 'package:flutter/material.dart';
import '../../models/shared_resource_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_utils.dart';

class ResourceCard extends StatelessWidget {
  final SharedResourceModel resource;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final bool showActions;

  const ResourceCard({
    super.key,
    required this.resource,
    this.onTap,
    this.onShare,
    this.onDownload,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _getCategoryColor().withValues(alpha: 0.1),
                ),
                child: Icon(
                  _getCategoryIcon(),
                  color: _getCategoryColor(),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildCategoryChip(),
                        const SizedBox(width: 8),
                        Text(
                          FileUtils.formatFileSize(resource.fileSize),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    if (resource.description != null &&
                        resource.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        resource.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.download, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(
                          '${resource.downloadCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(
                          resource.uploaderName ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (showActions)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'download':
                        onDownload?.call();
                        break;
                      case 'share':
                        onShare?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: [
                          Icon(Icons.download, size: 20),
                          SizedBox(width: 8),
                          Text('Download'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share, size: 20),
                          SizedBox(width: 8),
                          Text('Share Again'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (resource.category) {
      case 'Education':
        return Colors.blue;
      case 'Agriculture':
        return Colors.green;
      case 'Health':
        return Colors.red;
      case 'Business':
        return Colors.orange;
      case 'Technology':
        return Colors.purple;
      case 'Community':
        return Colors.teal;
      case 'Entertainment':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon() {
    switch (resource.category) {
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

  Widget _buildCategoryChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _getCategoryColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        resource.category,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _getCategoryColor(),
        ),
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final String category;
  final String icon;
  final int count;
  final bool isSelected;
  final VoidCallback? onTap;

  const CategoryCard({
    super.key,
    required this.category,
    required this.icon,
    required this.count,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreenSurface : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGreen
                : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              category,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: isSelected ? AppColors.primaryGreen : null,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryGreen
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
