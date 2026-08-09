import 'package:flutter/material.dart';

import '../models/message.dart';
import '../services/chat_service.dart';

import '../models/transaction.dart';
import 'add_transaction_screen.dart';

class ChatScreen extends StatefulWidget {

  const ChatScreen({super.key});


  @override
  State<ChatScreen> createState() =>
      _ChatScreenState();

}



class _ChatScreenState extends State<ChatScreen> {


  final ChatService chatService =
  ChatService();


  final messageController =
  TextEditingController();


  List<MessageModel> messages = [];




  @override
  void initState() {

    super.initState();

    loadMessages();

  }





  Future<void> loadMessages() async {


    final data =
    await chatService.getMessages();


    setState(() {

      messages = data;

    });


  }





  Future<void> sendMessage() async {


    final text =
    messageController.text.trim();


    if (text.isEmpty) {

      return;

    }



    messageController.clear();



    await chatService.sendMessage(
      text,
    );

    final draft = TransactionModel(

      userId: "local_user",

      amount: 500,

      transactionType: "expense",

      profileType: "personal",

      category: "Food",

      merchant: "Pizza Shop",

      note: text,

      paymentMethod: "credit_card",

      paymentName: "HDFC",

      date: DateTime.now(),

      source: "chat",

      createdAt: DateTime.now(),

      updatedAt: DateTime.now(),

    );



    if (mounted) {

      Navigator.push(

        context,

        MaterialPageRoute(

          builder: (context) =>
              AddTransactionScreen(

                draftTransaction: draft,

              ),

        ),

      );

    }



    loadMessages();


  }






  @override
  Widget build(BuildContext context) {


    return Scaffold(


      appBar: AppBar(

        title: const Text(
          "Expilio Chat",
        ),

      ),




      body: Column(


        children: [



          Expanded(

            child: ListView.builder(


              itemCount: messages.length,


              itemBuilder: (context, index) {


                final message =
                messages[index];


                final isUser =
                    message.role == "user";



                return Align(

                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,


                  child: Container(


                    margin: const EdgeInsets.all(8),


                    padding: const EdgeInsets.all(12),


                    decoration: BoxDecoration(

                      color: isUser
                          ? Colors.blue.shade100
                          : Colors.grey.shade300,


                      borderRadius:
                      BorderRadius.circular(12),

                    ),



                    child: Text(

                      message.message,

                    ),

                  ),

                );


              },

            ),

          ),







          Row(

            children: [


              Expanded(

                child: TextField(

                  controller: messageController,

                  decoration:
                  const InputDecoration(

                    hintText:
                    "Message Expilio",

                  ),

                ),

              ),




              IconButton(

                icon: const Icon(
                  Icons.send,
                ),


                onPressed:
                sendMessage,

              ),


            ],

          ),


        ],

      ),

    );

  }

}