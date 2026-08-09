import '../database/database_helper.dart';
import '../models/attachment.dart';


class AttachmentService {


  final DatabaseHelper _database =
      DatabaseHelper.instance;




  Future<int> addAttachment(
      AttachmentModel attachment,
      ) async {


    final now = DateTime.now();


    final newAttachment = AttachmentModel(

      transactionId: attachment.transactionId,

      fileName: attachment.fileName,

      localPath: attachment.localPath,

      cloudUrl: attachment.cloudUrl,

      fileType: attachment.fileType,

      isSynced: false,

      isDeleted: false,

      createdAt: now,

      updatedAt: now,

    );



    return await _database.insertAttachment(
      newAttachment,
    );

  }





  Future<List<AttachmentModel>> getAttachments(
      int transactionId,
      ) async {


    return await _database.getAttachments(
      transactionId,
    );

  }





  Future<int> deleteAttachment(
      int id,
      ) async {


    return await _database.deleteAttachment(
      id,
    );

  }


}