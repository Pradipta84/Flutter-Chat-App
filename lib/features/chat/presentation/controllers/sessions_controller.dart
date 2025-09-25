import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/chat_session.dart';

class SessionsState {
  SessionsState({required this.sessions, required this.currentSessionId});
  final List<ChatSession> sessions;
  final String currentSessionId;

  ChatSession? get current => sessions.firstWhere((s) => s.id == currentSessionId, orElse: () => sessions.isEmpty ? null as ChatSession : sessions.first);
}

final sessionsProvider = NotifierProvider<SessionsController, SessionsState>(SessionsController.new);

class SessionsController extends Notifier<SessionsState> {
  final _uuid = const Uuid();

  @override
  SessionsState build() {
    final first = ChatSession(id: _uuid.v4(), title: 'New chat');
    return SessionsState(sessions: [first], currentSessionId: first.id);
  }

  void newSession() {
    final s = ChatSession(id: _uuid.v4(), title: 'New chat');
    state = SessionsState(sessions: [...state.sessions, s], currentSessionId: s.id);
  }

  void deleteSession(String id) {
    final filtered = state.sessions.where((s) => s.id != id).toList();
    if (filtered.isEmpty) {
      final s = ChatSession(id: _uuid.v4(), title: 'New chat');
      state = SessionsState(sessions: [s], currentSessionId: s.id);
    } else {
      final currentId = state.currentSessionId == id ? filtered.first.id : state.currentSessionId;
      state = SessionsState(sessions: filtered, currentSessionId: currentId);
    }
  }

  void renameSession(String id, String title) {
    state = SessionsState(
      sessions: [
        for (final s in state.sessions) if (s.id == id) s.copyWith(title: title) else s
      ],
      currentSessionId: state.currentSessionId,
    );
  }

  void selectSession(String id) {
    state = SessionsState(sessions: state.sessions, currentSessionId: id);
  }
}


