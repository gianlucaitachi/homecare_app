import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../data/repositories/chat_repository.dart';
import '../cubit/chat_cubit.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.familyId, required this.currentUserId});

  final String familyId;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChatCubit(
        chatRepository: sl<ChatRepository>(),
        socketService: sl(),
        currentUserId: currentUserId,
      )..initialize(familyId: familyId),
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final TextEditingController _textEditingController = TextEditingController();

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatCubit, ChatState>(
              builder: (context, state) {
                if (state.status == ChatStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == ChatStatus.failure) {
                  return Center(child: Text(state.errorMessage ?? 'Failed to load messages'));
                }

                if (state.messages.isEmpty) {
                  return const Center(child: Text('No messages yet. Start the conversation!'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) {
                    final message = state.messages[index];
                    final isMine = message.senderId == context.read<ChatCubit>().currentUserId;
                    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;
                    final color = isMine ? Colors.blueAccent : Colors.grey.shade300;
                    final textColor = isMine ? Colors.white : Colors.black87;
                    return Align(
                      alignment: alignment,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message.content,
                          style: TextStyle(color: textColor),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textEditingController,
                      decoration: const InputDecoration(hintText: 'Type a message'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      final text = _textEditingController.text.trim();
                      if (text.isEmpty) return;
                      context.read<ChatCubit>().sendMessage(text);
                      _textEditingController.clear();
                    },
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
