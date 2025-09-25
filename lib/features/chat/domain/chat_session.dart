class ChatSession {
  ChatSession({required this.id, required this.title, List<String>? messageIds})
      : messageIds = messageIds ?? <String>[];
  final String id;
  final String title;
  final List<String> messageIds;

  ChatSession copyWith({String? title, List<String>? messageIds}) => ChatSession(
        id: id,
        title: title ?? this.title,
        messageIds: messageIds ?? List<String>.from(this.messageIds),
      );
}




