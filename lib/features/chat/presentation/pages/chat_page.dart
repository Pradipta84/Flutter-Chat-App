import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/chat_message.dart';
import '../controllers/chat_controller.dart';
import '../controllers/sessions_controller.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});
  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late final stt.SpeechToText _speech;
  late final FlutterTts _flutterTts;
  bool _listening = false;
  bool _isSpeaking = false;

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allMessages = ref.watch(chatProvider);
    final currentSessionId = ref.watch(sessionsProvider).currentSessionId;
    final messages = allMessages.where((m) => m.sessionId == currentSessionId).toList();
    _scrollToEnd();

    final sessions = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(radius: 14, backgroundColor: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sessions.current?.title ?? 'AI Q&A Chat',
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      drawer: _SessionsDrawer(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              itemCount: messages.length,
              itemBuilder: (_, i) => _Bubble(messages[i], this),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Ask something...'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _toggleMic,
                        child: Icon(
                          _listening ? Icons.mic : Icons.mic_none,
                          color: _listening ? Colors.redAccent : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: Material(
                      color: Colors.indigo,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final text = _controller.text.trim();
                          if (text.isEmpty) return;
                          // If asking weather, attach current location when available
                          if (text.toLowerCase().contains('weather')) {
                            final pos = await _getPosition();
                            if (pos != null) {
                              ref.read(chatProvider.notifier).send(
                                text,
                                latitude: pos.latitude,
                                longitude: pos.longitude,
                              );
                              _controller.clear();
                              return;
                            }
                          }
                          ref.read(chatProvider.notifier).send(text);
                          _controller.clear();
                        },
                        child: const Icon(Icons.send, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(chatProvider.notifier).send(text);
    _controller.clear();
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });
    
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
    
    _flutterTts.setErrorHandler((msg) {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  Future<void> _toggleMic() async {
    if (!_listening) {
      final available = await _speech.initialize(
        onStatus: (s) => setState(() => _listening = s == 'listening'),
        onError: (e) => setState(() => _listening = false),
      );
      if (!available) return;
      setState(() => _listening = true);
      await _speech.listen(
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
        onResult: (r) {
        setState(() => _controller.text = r.recognizedWords);
        _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
      },
      );
    } else {
      await _speech.stop();
      setState(() => _listening = false);
    }
  }

  Future<Position?> _getPosition() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return null;
    }
    if (perm == LocationPermission.deniedForever) return null;
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
  }

  Future<void> _speakText(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
      });
    } else {
      await _flutterTts.speak(text);
    }
  }

  Future<void> _regenerateResponse(BuildContext context, ChatMessage message) async {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Regenerating response...')),
      );
      
      // Find the user message that prompted this response
      final allMessages = ref.read(chatProvider);
      final currentSessionId = ref.read(sessionsProvider).currentSessionId;
      final sessionMessages = allMessages.where((m) => m.sessionId == currentSessionId).toList();
      
      // Find the user message before this assistant message
      int messageIndex = sessionMessages.indexWhere((m) => m.id == message.id);
      if (messageIndex > 0) {
        final userMessage = sessionMessages[messageIndex - 1];
        if (userMessage.role == 'user') {
          // Remove the current assistant message and regenerate
          final updatedMessages = allMessages.where((m) => m.id != message.id).toList();
          ref.read(chatProvider.notifier).state = updatedMessages;
          
          // Send the user message again
          ref.read(chatProvider.notifier).send(userMessage.text);
        }
      }
    }
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m, this.parentState);
  final ChatMessage m;
  final _ChatPageState parentState;

  @override
  Widget build(BuildContext context) {
    final isUser = m.role == 'user';
    final bubbleColor = isUser ? Colors.indigo : Colors.white;
    final textColor = isUser ? Colors.white : Colors.black87;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 640),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            if (!isUser)
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            (m.role == 'assistant')
                ? SelectableLinkify(
                    onOpen: (link) async {
                      await _showLinkActions(context, link.url);
                    },
                    text: m.text.isEmpty && m.isStreaming ? '...' : m.text,
                    style: TextStyle(color: textColor, height: 1.35),
                    linkStyle: const TextStyle(color: Colors.indigo),
                  )
                : SelectableText(
                    m.text.isEmpty && m.isStreaming ? '...' : m.text,
                    style: TextStyle(color: textColor, height: 1.35),
                  ),
            if (m.role == 'assistant' && !m.isStreaming && m.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    _ActionButton(
                      icon: Icons.copy,
                      onTap: () => _copyText(context, m.text),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: Icons.thumb_up_outlined,
                      onTap: () => _showFeedback(context, 'positive'),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: Icons.thumb_down_outlined,
                      onTap: () => _showFeedback(context, 'negative'),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: parentState._isSpeaking ? Icons.volume_off : Icons.volume_up_outlined,
                      onTap: () => parentState._speakText(m.text),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: Icons.refresh,
                      onTap: () => parentState._regenerateResponse(context, m),
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: Icons.share_outlined,
                      onTap: () => _shareText(m.text),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Future<void> _copyText(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
      );
    }
  }

  static Future<void> _showFeedback(BuildContext context, String type) async {
    final message = type == 'positive' ? 'Thanks for the feedback!' : 'Thanks for the feedback!';
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  static Future<void> _shareText(String text) async {
    await Share.share(text);
  }

  // image saving features removed
  static Future<void> _showLinkActions(BuildContext context, String url) async {
    String normalized = url
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim()
        .replaceAll(RegExp(r"[)>.,]+$"), '');
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open link'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final Uri? uri = Uri.tryParse(normalized);
                  if (uri == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid link')));
                    }
                    return;
                  }
                  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open link')));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy link'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: normalized));
                  Navigator.of(ctx).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

class _SessionsDrawer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsState = ref.watch(sessionsProvider);
    final ctrl = ref.read(sessionsProvider.notifier);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  const Text('Chats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'New chat',
                    icon: const Icon(Icons.add),
                    onPressed: ctrl.newSession,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: sessionsState.sessions.length,
                itemBuilder: (context, i) {
                  final s = sessionsState.sessions[i];
                  final selected = s.id == sessionsState.currentSessionId;
                  return ListTile(
                    selected: selected,
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      ctrl.selectSession(s.id);
                      Navigator.of(context).maybePop();
                    },
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ctrl.deleteSession(s.id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}



