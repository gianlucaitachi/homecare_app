part of 'chat_cubit.dart';

enum ChatStatus { initial, loading, ready, failure }

class ChatState extends Equatable {
  const ChatState({
    required this.status,
    required this.messages,
    this.familyId,
    this.errorMessage,
  });

  const ChatState.initial()
      : status = ChatStatus.initial,
        messages = const [],
        familyId = null,
        errorMessage = null;

  final ChatStatus status;
  final List<ChatMessage> messages;
  final String? familyId;
  final String? errorMessage;

  ChatState copyWith({
    ChatStatus? status,
    List<ChatMessage>? messages,
    String? familyId,
    String? errorMessage,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      familyId: familyId ?? this.familyId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, messages, familyId, errorMessage];
}
