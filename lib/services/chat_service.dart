import '../database/database_helper.dart';
import '../models/message.dart';


class ChatService {


  final DatabaseHelper _database =
      DatabaseHelper.instance;



  Future<void> sendMessage(
      String text,
      ) async {


    // save user message

    final userMessage = MessageModel(

      role: "user",

      message: text,

      createdAt: DateTime.now(),

    );


    await _database.insertMessage(
      userMessage,
    );





    // temporary fake assistant response
    // AI will replace this later

    final assistantMessage = MessageModel(

      role: "assistant",

      message:
      "I received: $text",

      createdAt: DateTime.now(),

    );


    await _database.insertMessage(
      assistantMessage,
    );

  }






  Future<List<MessageModel>> getMessages() async {


    return await _database.getMessages();


  }


}