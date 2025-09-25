class ChatMessage {
  ChatMessage({required this.id, required this.sessionId, required this.role, required this.text, this.isStreaming = false});
  final String id;
  final String sessionId;
  final String role; // 'user' | 'assistant'
  final String text;
  final bool isStreaming;

  ChatMessage copyWith({String? text, bool? isStreaming}) =>
      ChatMessage(id: id, sessionId: sessionId, role: role, text: text ?? this.text, isStreaming: isStreaming ?? this.isStreaming);
}


