import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/chat_repository.dart';
import '../../domain/chat_message.dart';
import 'sessions_controller.dart';

final chatRepoProvider = Provider((_) => ChatRepository());
final chatProvider = NotifierProvider<ChatController, List<ChatMessage>>(ChatController.new);

class ChatController extends Notifier<List<ChatMessage>> {
  late final ChatRepository _repo;
  final _uuid = const Uuid();

  @override
  List<ChatMessage> build() {
    _repo = ref.read(chatRepoProvider);
    return <ChatMessage>[];
  }

  Future<void> send(String prompt, {double? latitude, double? longitude}) async {
    if (prompt.trim().isEmpty) return;
    final sessions = ref.read(sessionsProvider);
    final sessionId = sessions.currentSessionId;
    final userMsg = ChatMessage(id: _uuid.v4(), sessionId: sessionId, role: 'user', text: prompt);
    state = [...state, userMsg];

    // If the user is asking for image links, generate them locally and skip backend
    if (_isLinksIntent(prompt)) {
      final linksText = _formatImageProviderLinks(prompt);
      final assistantInstant = ChatMessage(
        id: _uuid.v4(),
        sessionId: sessionId,
        role: 'assistant',
        text: linksText,
        isStreaming: false,
      );
      state = [...state, assistantInstant];
      _maybeRenameSession(prompt);
      return;
    }

    final assistantId = _uuid.v4();
    final assistantMsg = ChatMessage(id: assistantId, sessionId: sessionId, role: 'assistant', text: '', isStreaming: true);
    state = [...state, assistantMsg];

    // Build simple text transcript to provide basic context to backend
    final historyForSession = state
        .where((m) => m.sessionId == sessionId)
        .map((m) => m.role == 'user' ? 'User: ${m.text}' : 'Assistant: ${m.text}')
        .join('\n');
    final composedPrompt = historyForSession.isEmpty
        ? prompt
        : historyForSession + '\nUser: ' + prompt + '\nAssistant:';
    final promptToSend = composedPrompt;

    final buffer = StringBuffer();
    try {
      await for (final chunk in _repo.streamAnswer(promptToSend, latitude: latitude, longitude: longitude)) {
        buffer.write(chunk);
        final text = buffer.toString();
        state = [
          for (final m in state)
            if (m.id == assistantId) m.copyWith(text: text, isStreaming: true) else m
        ];
      }
    } catch (e) {
      state = [
        for (final m in state)
          if (m.id == assistantId) m.copyWith(text: 'Error: $e', isStreaming: false) else m
      ];
    } finally {
      state = [
        for (final m in state)
          if (m.id == assistantId) m.copyWith(isStreaming: false) else m
      ];
    }

    _maybeRenameSession(prompt);
  }

  void _maybeRenameSession(String prompt) {
    final sessionsCtrl = ref.read(sessionsProvider.notifier);
    final current = sessionsCtrl.state.current;
    if (current != null && (current.title == 'New chat' || current.title.trim().isEmpty)) {
      final title = prompt.length > 24 ? '${prompt.substring(0, 24)}…' : prompt;
      sessionsCtrl.renameSession(current.id, title);
    }
  }

  bool _isLinksIntent(String text) {
    final t = text.toLowerCase();
    // Only trigger for explicit link/image requests
    const explicitKeywords = [
      'link', 'links', 'image', 'images', 'photo', 'photos', 'picture', 'pictures', 'wallpaper'
    ];
    
    // Check for explicit patterns like "give me bike image link" or "show me photos of cats"
    final explicitPatterns = [
      RegExp(r"(give|show|find|get)\s+.*\s+(image|photo|picture)s?\s+link", caseSensitive: false),
      RegExp(r"(show|find|get)\s+(me\s+)?(image|photo|picture)s?\s+of", caseSensitive: false),
      RegExp(r"(image|photo|picture)s?\s+(of|for)\s+", caseSensitive: false),
      RegExp(r"wallpaper\s+(of|for)\s+", caseSensitive: false),
    ];
    
    // Only return true if there's an explicit keyword AND it's clearly about getting links/images
    bool hasExplicitKeyword = explicitKeywords.any((k) => t.contains(k));
    bool matchesExplicitPattern = explicitPatterns.any((pattern) => pattern.hasMatch(text));
    
    return hasExplicitKeyword && matchesExplicitPattern;
  }

  String _formatImageProviderLinks(String prompt) {
    String q = prompt.trim();
    final parts = q.split(":");
    if (parts.length > 1 && parts[1].trim().isNotEmpty) {
      q = parts.sublist(1).join(":").trim();
    } else {
      for (final sep in [" for ", " about ", " on ", " of "]) {
        final idx = q.toLowerCase().indexOf(sep);
        if (idx != -1 && idx + sep.length < q.length) {
          q = q.substring(idx + sep.length).trim();
          break;
        }
      }
    }
    final cleaned = q
        .replaceAll("\n", " ")
        .replaceAll("?", " ")
        .replaceAll(".", " ")
        .split(RegExp(r"\s+"))
        .where((w) => w.isNotEmpty)
        .where((w) => !{
              'give', 'show', 'find', 'me', 'link', 'links', 'please',
              'a', 'an', 'the', 'for', 'this', 'these', 'to', 'get'
            }.contains(w.toLowerCase()))
        .join(" ")
        .trim();
    final query = cleaned.isEmpty ? q : cleaned;

    final encPath = Uri.encodeComponent(query);
    final encPlus = Uri.encodeQueryComponent(query);

    final lines = <String>[
      '@https://unsplash.com/s/photos/' + encPath,
      '@https://www.pexels.com/search/' + encPath + '/',
      '@https://pixabay.com/images/search/' + encPath + '/',
      '@https://www.freepik.com/search?format=search&query=' + encPlus,
      '@https://www.istockphoto.com/photos/' + encPath,
      '@https://www.gettyimages.com/photos/' + encPath,
    ];
    return lines.join('\n');
  }
}


