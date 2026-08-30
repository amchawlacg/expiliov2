import 'package:flutter/material.dart';

import '../models/message.dart';
import '../services/chat_service.dart';
import '../constants/app_colors.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService chatService = ChatService();
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  List<MessageModel> messages = [];
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    loadMessages();
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> loadMessages() async {
    final data = await chatService.getMessages();
    if (mounted) {
      setState(() {
        messages = data;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || isSending) return;

    messageController.clear();

    // 1. Immediately show user message on screen
    // In chat_screen.dart inside sendMessage():
    setState(() {
      messages.add(
        MessageModel(role: "user", message: text, createdAt: DateTime.now()),
      );
      isSending = true;
    });
    _scrollToBottom();

    // 2. Send to backend/AI and refresh
    try {
      await chatService.sendMessage(text);
      await loadMessages();
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text("Expilio Chat"),
        backgroundColor: context.colors.card,
        foregroundColor: context.colors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Message List
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isUser = message.role == "user";

                  return Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.only(
                        top: 4,
                        bottom: 4,
                        left: isUser ? 64 : 12,
                        right: isUser ? 12 : 64,
                      ),
                      padding: isUser
                          ? const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            )
                          : const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                      decoration: BoxDecoration(
                        color: isUser
                            ? context.colors.chatBubbleUser
                            : Colors.transparent,
                        borderRadius: isUser
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(22),
                                bottomLeft: Radius.circular(22),
                                bottomRight: Radius.circular(22),
                                topRight: Radius.zero,
                              )
                            : BorderRadius.zero,
                      ),
                      child: Text(
                        message.message,
                        style: TextStyle(
                          color: isUser
                              ? context.colors.chatBubbleUserText
                              : context.colors.chatBubbleBotText,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Loading indicator while waiting for bot response
            if (isSending)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Expilio is thinking...",
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),

            // Bottom Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.colors.card,
                border: Border(
                  top: BorderSide(color: context.colors.divider, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      style: TextStyle(color: context.colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: "Message Expilio...",
                        hintStyle: TextStyle(color: context.colors.textHint),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      color: context.colors.primary,
                    ),
                    onPressed: sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
