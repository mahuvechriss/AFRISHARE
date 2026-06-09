class SharedResourceModel {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String? subCategory;
  final String fileName;
  final String filePath;
  final int fileSize;
  final String fileType;
  final String? thumbnailPath;
  final String uploaderId;
  final String? uploaderName;
  int downloadCount;
  double rating;
  final String? tags;
  bool isFeatured;
  final DateTime createdAt;
  DateTime updatedAt;

  SharedResourceModel({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    this.subCategory,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.fileType,
    this.thumbnailPath,
    required this.uploaderId,
    this.uploaderName,
    this.downloadCount = 0,
    this.rating = 0,
    this.tags,
    this.isFeatured = false,
    required this.createdAt,
    required this.updatedAt,
  });

  List<String> get tagList {
    if (tags == null || tags!.isEmpty) return [];
    return tags!.split(',').map((t) => t.trim()).toList();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'sub_category': subCategory,
        'file_name': fileName,
        'file_path': filePath,
        'file_size': fileSize,
        'file_type': fileType,
        'thumbnail_path': thumbnailPath,
        'uploader_id': uploaderId,
        'uploader_name': uploaderName,
        'download_count': downloadCount,
        'rating': rating,
        'tags': tags,
        'is_featured': isFeatured ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory SharedResourceModel.fromJson(Map<String, dynamic> json) =>
      SharedResourceModel(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        category: json['category'] as String,
        subCategory: json['sub_category'] as String?,
        fileName: json['file_name'] as String,
        filePath: json['file_path'] as String,
        fileSize: json['file_size'] as int,
        fileType: json['file_type'] as String,
        thumbnailPath: json['thumbnail_path'] as String?,
        uploaderId: json['uploader_id'] as String,
        uploaderName: json['uploader_name'] as String?,
        downloadCount: json['download_count'] as int? ?? 0,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        tags: json['tags'] as String?,
        isFeatured: (json['is_featured'] as int?) == 1,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  SharedResourceModel copyWith({
    String? title,
    String? description,
    String? category,
    String? subCategory,
    String? thumbnailPath,
    int? downloadCount,
    double? rating,
    String? tags,
    bool? isFeatured,
  }) =>
      SharedResourceModel(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        subCategory: subCategory ?? this.subCategory,
        fileName: fileName,
        filePath: filePath,
        fileSize: fileSize,
        fileType: fileType,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        uploaderId: uploaderId,
        uploaderName: uploaderName,
        downloadCount: downloadCount ?? this.downloadCount,
        rating: rating ?? this.rating,
        tags: tags ?? this.tags,
        isFeatured: isFeatured ?? this.isFeatured,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
