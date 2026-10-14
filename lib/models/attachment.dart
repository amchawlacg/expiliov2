class AttachmentModel {
  final int? id;
  final String? transactionId; // Made optional for when creating an attachment before transaction ID is assigned
  final String fileName;
  final String? localPath;
  final String? localThumbnailPath; // Added for local low-res thumbnails
  final String? cloudUrl;
  final String? cloudThumbnailUrl; // Added for R2 low-res thumbnails
  final String? fileType;
  final bool isSynced;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  AttachmentModel({
    this.id,
    this.transactionId,
    required this.fileName,
    this.localPath,
    this.localThumbnailPath,
    this.cloudUrl,
    this.cloudThumbnailUrl,
    this.fileType,
    this.isSynced = false,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'transaction_id': transactionId,
      'file_name': fileName,
      'local_path': localPath,
      'local_thumbnail_path': localThumbnailPath,
      'cloud_url': cloudUrl,
      'cloud_thumbnail_url': cloudThumbnailUrl,
      'file_type': fileType,
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AttachmentModel.fromMap(Map<String, dynamic> map) {
    return AttachmentModel(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as String?,
      fileName: map['file_name'] as String,
      localPath: map['local_path'] as String?,
      localThumbnailPath: map['local_thumbnail_path'] as String?,
      cloudUrl: map['cloud_url'] as String?,
      cloudThumbnailUrl: map['cloud_thumbnail_url'] as String?,
      fileType: map['file_type'] as String?,
      isSynced: (map['is_synced'] as int?) == 1,
      isDeleted: (map['is_deleted'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  AttachmentModel copyWith({
    int? id,
    String? transactionId,
    String? fileName,
    String? localPath,
    String? localThumbnailPath,
    String? cloudUrl,
    String? cloudThumbnailUrl,
    String? fileType,
    bool? isSynced,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttachmentModel(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      fileName: fileName ?? this.fileName,
      localPath: localPath ?? this.localPath,
      localThumbnailPath: localThumbnailPath ?? this.localThumbnailPath,
      cloudUrl: cloudUrl ?? this.cloudUrl,
      cloudThumbnailUrl: cloudThumbnailUrl ?? this.cloudThumbnailUrl,
      fileType: fileType ?? this.fileType,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}