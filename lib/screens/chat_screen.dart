import 'package:flutter/material.dart';

import '../models/message.dart';
import '../services/chat_service.dart';
import '../constants/app_colors.dart';
import 'add_transaction_screen.dart';
import '../models/transaction.dart';
import '../widgets/transaction_card.dart';
import '../database/database_helper.dart';

import '../widgets/typing_indicator.dart';
import '../widgets/app_alert_dialog.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:file_picker/file_picker.dart';
import '../models/attachment.dart';
import '../services/attachment_service.dart';
import '../widgets/attachment_thumbnail_view.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService chatService = ChatService();
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  String? _failedMessageText;
  // Tracks message indices whose transaction card lists are fully expanded
  final Set<int> _expandedTransactionGroups = {};

  final AttachmentService _attachmentService = AttachmentService();
  AttachmentModel? _pendingAttachment;

  List<MessageModel> messages = [];
  bool isSending = false;
  bool _isSendHovered = false;
  bool _isAttachHovered = false; // 👈 Add this line
  bool _isCloseHovered = false;

  // Tracks message indices that have been manually expanded
  final Set<int> _expandedIndices = {};

  final List<String> _suggestedPrompts = [
    "What did I spend this month?",
    "How much did I spend on food?",
    "Log 15 on lunch today",
    "Show recent transactions",
    "Clear chat", // Added clear action
  ];

  List<String> get _currentPrompts {
    if (messages.isEmpty) {
      return _suggestedPrompts.where((p) => p != "Clear chat").toList();
    }
    return _suggestedPrompts;
  }

  Future<void> _executeClearChat() async {
    try {
      await DatabaseHelper.instance.clearAllMessages();
      if (mounted) {
        setState(() {
          messages.clear();
          _expandedIndices.clear();
          _expandedTransactionGroups.clear();
        });
      }
    } catch (e) {
      debugPrint("Error clearing messages: $e");
    }
  }

  Future<void> _pickAttachment() async {
    if (isSending) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      final String pickedPath = file.path!;
      final String fileName = file.name;
      final String ext = pickedPath.split('.').last.toLowerCase();
      final bool isPdf = ext == 'pdf';

      AttachmentModel model;

      if (isPdf) {
        final String savedPdfPath = await _attachmentService.copyToAppStorage(
          pickedPath,
          fileName,
        );
        final String? thumbPath = await _attachmentService
            .generatePdfThumbnailBestEffort(savedPdfPath, fileName);

        final now = DateTime.now();
        model = AttachmentModel(
          fileName: fileName,
          localPath: savedPdfPath,
          localThumbnailPath: thumbPath,
          fileType: 'application/pdf',
          isSynced: false,
          isDeleted: false,
          createdAt: now,
          updatedAt: now,
        );
      } else {
        model = await _attachmentService.processPickedFilePath(pickedPath);
      }

      if (mounted) {
        setState(() {
          _pendingAttachment = model;
        });
      }
    } catch (e) {
      debugPrint("Error picking attachment in chat: $e");
    }
  }

  void _onPromptTap(String prompt) {
    if (isSending) return;

    if (prompt == "Clear chat") {
      _confirmClearChat();
      return;
    }

    // Set text in controller and submit
    messageController.text = prompt;
    sendMessage();
  }

  Widget _buildPromptPill(String prompt, {bool isInline = false}) {
    final isClear = prompt == "Clear chat";
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.colors.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isClear
                ? Colors.red.withOpacity(0.2)
                : Colors.black.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () => _onPromptTap(prompt),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isClear
                      ? Icons.delete_outline_rounded
                      : Icons.north_east_rounded,
                  size: 15,
                  color: isClear
                      ? Colors.redAccent
                      : context.colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prompt,
                    style: TextStyle(
                      color: isClear
                          ? Colors.redAccent
                          : context.colors.textPrimary,
                      fontSize: 13,
                      fontWeight: isClear ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _shouldShowPills {
    if (messages.isEmpty) return true;

    // Show pills if the latest message is the local greeting response
    final lastMessage = messages.last;
    if (lastMessage.role != "user") {
      final text = lastMessage.message.toLowerCase();
      return text.contains("how can i help you manage your finances today");
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    loadMessages();

    // Scroll to bottom as soon as the keyboard opens
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToBottom();
        });
      }
    });
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
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
      // Delay slightly so layout finishes before computing maxScrollExtent
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animated: false);
      });
    }
  }

  Future<List<TransactionModel>> _fetchTransactionsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await DatabaseHelper.instance.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT * FROM transactions WHERE id IN ($placeholders) ORDER BY date DESC',
      ids,
    );
    return rows.map((r) => TransactionModel.fromMap(r)).toList();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      if (animated) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _confirmClearChat() async {
    final confirmed = await AppAlertDialog.show(
      context,
      title: "Clear Chat?",
      message:
          "This will permanently remove all messages from your chat history.",
      confirmText: "Clear",
      cancelText: "Cancel",
      isDestructive: true,
    );

    if (confirmed == true) {
      await _executeClearChat();
    }
  }

  Future<void> sendMessage({String? retryText}) async {
    // Blocks rapid repeated taps while a request is in-flight
    if (isSending) return;

    final text = retryText ?? messageController.text.trim();
    if (text.isEmpty) return;

    final attachmentToForward = _pendingAttachment; // 👈 ADD THIS

    // Only clear controller and add a bubble if this is a fresh message
    if (retryText == null) {
      messageController.clear();
      final userMessage = MessageModel(
        role: "user",
        message: text,
        createdAt: DateTime.now(),
      );
      setState(() {
        messages.add(userMessage);
        _pendingAttachment =
            null; // 👈 Clears the attachment when message is dispatched
      });
      _scrollToBottom();
    }

    setState(() {
      _failedMessageText = null;
      isSending = true;
    });

    // Intercept simple greetings locally
    final clean = text.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final isGreeting = clean == "hi" || clean == "hello" || clean == "hey";

    if (isGreeting) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) {
        setState(() {
          messages.add(
            MessageModel(
              role: "assistant",
              message: "Hi! How can I help you manage your finances today?",
              createdAt: DateTime.now(),
            ),
          );
          isSending = false;
        });
        _scrollToBottom();
      }
      return;
    }

    try {
      final result = await chatService.sendMessage(text);

      final freshMessages = await chatService.getMessages();
      if (freshMessages.isNotEmpty && mounted) {
        setState(() {
          messages = freshMessages;
        });
      }
      _scrollToBottom();

      if (result?.draftTransaction != null && mounted) {
        final bool? didSave = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(
              draftTransaction: result!.draftTransaction,
              initialAttachments: attachmentToForward != null
                  ? [attachmentToForward]
                  : null,
            ),
          ),
        );

        if (didSave == true && mounted) {
          final draft = result!.draftTransaction!;
          final confirmMessage = MessageModel(
            role: "assistant",
            message: "Recorded ${draft.currency} ${draft.amount.toStringAsFixed(2)} for ${draft.category}.",
            createdAt: DateTime.now(),
          );
          await DatabaseHelper.instance.insertMessage(confirmMessage);
          await loadMessages();
        }
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
      if (mounted) {
        setState(() {
          _failedMessageText = text;
        });
      }
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
      body: SafeArea(
        child: Column(
          children: [
            // Message List / Starter Prompts
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        // MATCHES THE BOT MESSAGE LEFT MARGIN OF 12
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: context.colors.card,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.black.withOpacity(0.08),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        color: context.colors.primary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      "How can I help you today?",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: context.colors.textPrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Choose a prompt below or type your question",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: context.colors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: _currentPrompts
                                      .map((prompt) => _buildPromptPill(prompt))
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.92, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: ListView.builder(
                        controller: scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(top: 8, bottom: 12),
                        itemCount:
                            messages.length +
                            (_shouldShowPills ? 1 : 0) +
                            (isSending ? 1 : 0),
                        itemBuilder: (context, index) {
                          // 1. Inline typing indicator directly below the user bubble
                          if (isSending && index == messages.length) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                top: 8,
                                bottom: 8,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TypingIndicator(
                                  color: context.colors.textSecondary,
                                  dotSize: 6.0,
                                ),
                              ),
                            );
                          }

                          // 2. Render inline vertical pills below the local "hi" greeting
                          final pillsIndex =
                              messages.length + (isSending ? 1 : 0);
                          if (_shouldShowPills && index == pillsIndex) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                left: 12,
                                top: 8,
                                bottom: 12,
                                right: 64,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: _currentPrompts
                                    .map(
                                      (prompt) => _buildPromptPill(
                                        prompt,
                                        isInline: true,
                                      ),
                                    )
                                    .toList(),
                              ),
                            );
                          }

                          final message = messages[index];
                          final isUser = message.role == "user";
                          final isExpanded = _expandedIndices.contains(index);

                          return Column(
                            crossAxisAlignment: isUser
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: isUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (!isUser) {
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          top: 4,
                                          bottom: 4,
                                          left: 16,
                                          right: 16,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          message.message,
                                          strutStyle: const StrutStyle(
                                            fontSize: 15,
                                            height: 1.35,
                                            forceStrutHeight: true,
                                          ),
                                          style: TextStyle(
                                            color: context
                                                .colors
                                                .chatBubbleBotText,
                                            fontSize: 15,
                                            height: 1.35,
                                          ),
                                        ),
                                      );
                                    }

                                    final double maxBubbleWidth =
                                        (constraints.maxWidth - 76).clamp(
                                          0.0,
                                          double.infinity,
                                        );
                                    final double contentWidth =
                                        (maxBubbleWidth - 32).clamp(
                                          0.0,
                                          double.infinity,
                                        );

                                    final textStyle = TextStyle(
                                      color: context.colors.chatBubbleUserText,
                                      fontSize: 15,
                                      height: 1.35,
                                    );

                                    final textPainter = TextPainter(
                                      text: TextSpan(
                                        text: message.message,
                                        style: textStyle,
                                      ),
                                      textDirection: TextDirection.ltr,
                                      maxLines: 3,
                                    )..layout(maxWidth: contentWidth);

                                    final bool exceedsThreeLines =
                                        textPainter.didExceedMaxLines;

                                    return Container(
                                      margin: const EdgeInsets.only(
                                        top: 4,
                                        bottom: 4,
                                        left: 64,
                                        right: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.colors.chatBubbleUser,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(22),
                                          bottomLeft: Radius.circular(22),
                                          bottomRight: Radius.circular(22),
                                          topRight: Radius.zero,
                                        ),
                                      ),
                                      child: IntrinsicWidth(
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                              child: AnimatedSize(
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                curve: Curves.easeInOut,
                                                alignment: Alignment.topLeft,
                                                child: Text(
                                                  message.message,
                                                  strutStyle: const StrutStyle(
                                                    fontSize: 15,
                                                    height: 1.35,
                                                    forceStrutHeight: true,
                                                  ),
                                                  style: textStyle,
                                                  maxLines:
                                                      (!exceedsThreeLines ||
                                                          isExpanded)
                                                      ? null
                                                      : 3,
                                                  overflow:
                                                      (!exceedsThreeLines ||
                                                          isExpanded)
                                                      ? TextOverflow.visible
                                                      : TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            if (exceedsThreeLines)
                                              Positioned(
                                                bottom: 8,
                                                right: 8,
                                                child: MouseRegion(
                                                  cursor:
                                                      SystemMouseCursors.click,
                                                  child: GestureDetector(
                                                    behavior:
                                                        HitTestBehavior.opaque,
                                                    onTap: () {
                                                      setState(() {
                                                        if (isExpanded) {
                                                          _expandedIndices
                                                              .remove(index);
                                                        } else {
                                                          _expandedIndices.add(
                                                            index,
                                                          );
                                                        }
                                                      });
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                  0.12,
                                                                ),
                                                            blurRadius: 4,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  1,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Icon(
                                                        isExpanded
                                                            ? Icons
                                                                  .keyboard_arrow_up_rounded
                                                            : Icons
                                                                  .keyboard_arrow_down_rounded,
                                                        size: 14,
                                                        color: context
                                                            .colors
                                                            .chatBubbleUser,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Retry button anchored directly beneath failed user message
                              if (isUser &&
                                  index == messages.length - 1 &&
                                  _failedMessageText != null &&
                                  !isSending)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: 12,
                                    top: 4,
                                    bottom: 6,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => sendMessage(
                                        retryText: _failedMessageText,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.red.withOpacity(0.25),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.refresh_rounded,
                                              size: 13,
                                              color: Colors.redAccent,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              "Couldn't send. Tap to retry",
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              if (!isUser && message.transactionIds.isNotEmpty)
                                FutureBuilder<List<TransactionModel>>(
                                  future: _fetchTransactionsByIds(
                                    message.transactionIds,
                                  ),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData ||
                                        snapshot.data!.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    final txs = snapshot.data!;
                                    final bool isTxExpanded =
                                        _expandedTransactionGroups.contains(
                                          index,
                                        );
                                    final displayedTxs = isTxExpanded
                                        ? txs
                                        : txs.take(4).toList();

                                    return Container(
                                      margin: const EdgeInsets.only(
                                        left: 12,
                                        right: 12,
                                        top: 6,
                                        bottom: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.colors.card,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.black.withOpacity(0.08),
                                          width: 1,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Column(
                                        children: [
                                          ...displayedTxs.map((tx) {
                                            return TransactionCard(
                                              transaction: tx,
                                              onTap: () async {
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        AddTransactionScreen(
                                                          transaction: tx,
                                                        ),
                                                  ),
                                                );
                                                loadMessages();
                                              },
                                              onDelete: () {},
                                            );
                                          }),
                                          if (txs.length > 4)
                                            InkWell(
                                              onTap: () {
                                                setState(() {
                                                  if (isTxExpanded) {
                                                    _expandedTransactionGroups
                                                        .remove(index);
                                                  } else {
                                                    _expandedTransactionGroups
                                                        .add(index);
                                                  }
                                                });
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      isTxExpanded
                                                          ? "Show less"
                                                          : "+ ${txs.length - 4} more transactions",
                                                      style: TextStyle(
                                                        color: context
                                                            .colors
                                                            .purple,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      isTxExpanded
                                                          ? Icons
                                                                .keyboard_arrow_up_rounded
                                                          : Icons
                                                                .keyboard_arrow_down_rounded,
                                                      size: 16,
                                                      color:
                                                          context.colors.purple,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                    ),
            ),

            // Floating Gemini-style Input Box
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 1. Measure single-line text width
                        final textSpan = TextSpan(
                          text: messageController.text.isEmpty
                              ? "Ask Expilio anything..."
                              : messageController.text,
                          style: const TextStyle(fontSize: 15, height: 1.25),
                        );
                        final textPainter = TextPainter(
                          text: textSpan,
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                        )..layout();

                        // 2. Wrap into Column mode if text exceeds 60% width, has a newline, or has an attachment
                        final bool shouldWrap =
                            _pendingAttachment != null ||
                            (messageController.text.isNotEmpty &&
                                (textPainter.width >
                                        (constraints.maxWidth * 0.60) ||
                                    messageController.text.contains('\n')));

                        // Action buttons row (Attachment + Send)
                        final actionButtons = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Attachment Button
                            MouseRegion(
                              cursor: isSending
                                  ? SystemMouseCursors.basic
                                  : SystemMouseCursors.click,
                              onEnter: (_) =>
                                  setState(() => _isAttachHovered = true),
                              onExit: (_) =>
                                  setState(() => _isAttachHovered = false),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap:
                                    _pickAttachment, // 👈 Hooked to single-file picker
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _isAttachHovered
                                        ? context.colors.cardLight
                                        : context.colors.cardLight.withValues(
                                            alpha: 0,
                                          ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: SvgPicture.asset(
                                    'assets/icons/components/add_outline.svg',
                                    width: 18,
                                    height: 18,
                                    colorFilter: ColorFilter.mode(
                                      isSending
                                          ? context.colors.textSecondary
                                                .withValues(alpha: 0.4)
                                          : context.colors.textPrimary,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Send Button
                            MouseRegion(
                              cursor: isSending
                                  ? SystemMouseCursors.basic
                                  : SystemMouseCursors.click,
                              onEnter: (_) =>
                                  setState(() => _isSendHovered = true),
                              onExit: (_) =>
                                  setState(() => _isSendHovered = false),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: isSending ? null : sendMessage,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: TweenAnimationBuilder<Color?>(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    tween: ColorTween(
                                      end: isSending
                                          ? context.colors.textSecondary
                                                .withValues(alpha: 0.4)
                                          : (_isSendHovered
                                                ? context.colors.purpleLight
                                                : context.colors.purple),
                                    ),
                                    builder: (context, color, child) {
                                      return SvgPicture.asset(
                                        'assets/icons/components/send.svg',
                                        width: 34,
                                        height: 34,
                                        colorFilter: ColorFilter.mode(
                                          color ?? context.colors.purple,
                                          BlendMode.srcIn,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );

                        // Attachment preview thumbnail with a close button
                        Widget? thumbnailPreview;
                        if (_pendingAttachment != null) {
                          thumbnailPreview = Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: context.colors.textSecondary
                                          .withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: AttachmentThumbnailView(
                                    attachment: _pendingAttachment!,
                                    size: 38,
                                    borderRadius:
                                        7, // 1px less so it doesn't bleed through the border
                                  ),
                                ),
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) =>
                                        setState(() => _isCloseHovered = true),
                                    onExit: (_) =>
                                        setState(() => _isCloseHovered = false),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        setState(() {
                                          _pendingAttachment = null;
                                          _isCloseHovered = false;
                                        });
                                      },
                                      child: AnimatedScale(
                                        scale: _isCloseHovered ? 1.1 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          width: 18,
                                          height: 18,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: _isCloseHovered
                                                ? context.colors.cardLight
                                                : context.colors.card,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: _isCloseHovered
                                                  ? context.colors.textSecondary
                                                        .withValues(alpha: 0.35)
                                                  : context.colors.textSecondary
                                                        .withValues(alpha: 0.2),
                                              width: 1,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 11,
                                            color: context.colors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Unified tree: TextField stays in the identical tree location
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Stack(
                              alignment: Alignment.centerRight,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    right: shouldWrap ? 0 : 86,
                                  ),
                                  child: TextField(
                                    controller: messageController,
                                    focusNode: _inputFocusNode,
                                    onChanged: (_) => setState(() {}),
                                    style: TextStyle(
                                      color: context.colors.textPrimary,
                                      fontSize: 15,
                                      height: 1.25,
                                    ),
                                    strutStyle: const StrutStyle(
                                      fontSize: 15,
                                      height: 1.25,
                                      forceStrutHeight: true,
                                    ),
                                    cursorHeight: 18,
                                    minLines: 1,
                                    maxLines: 5,
                                    keyboardType: TextInputType.multiline,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: InputDecoration(
                                      hintText: "Ask Expilio anything...",
                                      hintStyle: TextStyle(
                                        color: context.colors.textHint,
                                        fontSize: 15,
                                        height: 1.25,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                    ),
                                  ),
                                ),

                                // Inline buttons: visible only when NOT wrapped
                                if (!shouldWrap) actionButtons,
                              ],
                            ),

                            // Bottom row: Thumbnail on the left, buttons on the right
                            if (shouldWrap) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  thumbnailPreview ?? const SizedBox.shrink(),
                                  actionButtons,
                                ],
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
