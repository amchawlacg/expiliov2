class AttachmentModel {

  final int? id;

  final int transactionId;

  final String fileName;

  final String? localPath;

  final String? cloudUrl;

  final String? fileType;

  final bool isSynced;

  final bool isDeleted;

  final DateTime createdAt;

  final DateTime updatedAt;



  AttachmentModel({

    this.id,

    required this.transactionId,

    required this.fileName,

    this.localPath,

    this.cloudUrl,

    this.fileType,

    this.isSynced = false,

    this.isDeleted = false,

    required this.createdAt,

    required this.updatedAt,

  });



  Map<String, dynamic> toMap() {

    return {

      'id': id,

      'transaction_id': transactionId,

      'file_name': fileName,

      'local_path': localPath,

      'cloud_url': cloudUrl,

      'file_type': fileType,

      'is_synced': isSynced ? 1 : 0,

      'is_deleted': isDeleted ? 1 : 0,

      'created_at': createdAt.toIso8601String(),

      'updated_at': updatedAt.toIso8601String(),

    };

  }



  factory AttachmentModel.fromMap(
      Map<String, dynamic> map,
      ) {

    return AttachmentModel(

      id: map['id'],

      transactionId: map['transaction_id'],

      fileName: map['file_name'],

      localPath: map['local_path'],

      cloudUrl: map['cloud_url'],

      fileType: map['file_type'],

      isSynced: map['is_synced'] == 1,

      isDeleted: map['is_deleted'] == 1,

      createdAt: DateTime.parse(
        map['created_at'],
      ),

      updatedAt: DateTime.parse(
        map['updated_at'],
      ),

    );

  }

}