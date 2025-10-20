import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/socket/socket_service.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/chat_repository.dart';

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required ChatRepository chatRepository,
    required SocketService socketService,
    required String currentUserId,
  })  : _chatRepository = chatRepository,
        _socketService = socketService,
        _currentUserId = currentUserId,
        super(const ChatState.initial());

  final ChatRepository _chatRepository;
  final SocketService _socketService;
  final String _currentUserId;

  String get currentUserId => _currentUserId;

  StreamSubscription<Map<String, dynamic>>? _chatMessagesSubscription;

  Future<void> initialize({required String familyId}) async {
    emit(state.copyWith(status: ChatStatus.loading, familyId: familyId));

    await _socketService.connect(AppConstants.socketBaseUrl);
    _socketService.joinRoom(familyId);

    await _chatMessagesSubscription?.cancel();
    _chatMessagesSubscription = _socketService.chatMessages.listen((event) {
      if (event['familyId'] == familyId) {
        final message = ChatMessage.fromJson(event);
        final updatedMessages = List<ChatMessage>.from(state.messages)..add(message);
        emit(state.copyWith(messages: updatedMessages));
      }
    });

    try {
      final messages = await _chatRepository.fetchMessages(familyId);
      final merged = <String, ChatMessage>{
        for (final message in state.messages) message.id: message,
      };
      for (final message in messages) {
        merged[message.id] = message;
      }
      final ordered = merged.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      emit(state.copyWith(status: ChatStatus.ready, messages: ordered));
    } catch (error) {
      emit(state.copyWith(status: ChatStatus.failure, errorMessage: error.toString()));
    }
  }

  void sendMessage(String content) {
    if (state.familyId == null || content.trim().isEmpty) {
      return;
    }

    _socketService.sendChatMessage(
      familyId: state.familyId!,
      senderId: _currentUserId,
      content: content,
    );
  }

  @override
  Future<void> close() {
    _chatMessagesSubscription?.cancel();
    return super.close();
  }
}
