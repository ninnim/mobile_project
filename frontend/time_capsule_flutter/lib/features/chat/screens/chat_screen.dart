import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_message.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/signalr_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';

// ─── State ───────────────────────────────────────────────────────────────────

class _ChatState {
  final List<ChatMessage> messages;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final bool sending;
  final bool otherTyping;
  final bool otherOnline;

  const _ChatState({
    this.messages = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.sending = false,
    this.otherTyping = false,
    this.otherOnline = false,
  });

  _ChatState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    bool? sending,
    bool? otherTyping,
    bool? otherOnline,
  }) => _ChatState(
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    sending: sending ?? this.sending,
    otherTyping: otherTyping ?? this.otherTyping,
    otherOnline: otherOnline ?? this.otherOnline,
  );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class _ChatNotifier extends StateNotifier<_ChatState> {
  final String myId;
  final String otherId;
  final String otherName;
  Timer? _typingTimer;
  StreamSubscription? _msgSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _readSub;
  StreamSubscription? _reactionSub;
  static const _pageSize = 30;

  _ChatNotifier(this.myId, this.otherId, this.otherName)
    : super(const _ChatState()) {
    _init();
  }

  Future<void> _init() async {
    await _fetchMessages();
    _subscribeSignalR();
  }

  Future<void> _fetchMessages() async {
    try {
      final res = await dioClient.get(
        '/chats/$otherId',
        queryParameters: {'limit': _pageSize},
      );
      final msgs = (res.data as List<dynamic>)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        messages: msgs,
        loading: false,
        hasMore: msgs.length >= _pageSize,
      );
      dioClient.put('/chats/read/$otherId');
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.messages.isEmpty) return;
    state = state.copyWith(loadingMore: true);
    try {
      final oldest = state.messages.first.createdAt;
      final res = await dioClient.get(
        '/chats/$otherId',
        queryParameters: {'before': oldest, 'limit': _pageSize},
      );
      final older = (res.data as List<dynamic>)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        messages: [...older, ...state.messages],
        loadingMore: false,
        hasMore: older.length >= _pageSize,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  void _subscribeSignalR() {
    final signalR = SignalRService.instance;
    // Ensure connected
    signalR.connect();

    _msgSub = signalR.onMessage.listen((data) {
      final msg = ChatMessage.fromJson(data);
      // Only accept messages from the other user in this conversation
      if (msg.senderId == otherId) {
        if (!state.messages.any((m) => m.id == msg.id)) {
          state = state.copyWith(messages: [...state.messages, msg]);
          dioClient.put('/chats/read/$otherId');
        }
      }
    });

    _typingSub = signalR.onTyping.listen((record) {
      final (userId, isTyping) = record;
      if (userId == otherId) {
        state = state.copyWith(otherTyping: isTyping);
      }
    });

    _readSub = signalR.onMessagesRead.listen((record) {
      final (userId, messageIds) = record;
      if (userId == otherId) {
        final updated = state.messages.map((m) {
          if (messageIds.contains(m.id)) {
            return m.copyWith(status: 'Read', isRead: true);
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updated);
      }
    });

    _reactionSub = signalR.onReaction.listen((data) {
      final chatId = data['chatId'] as String?;
      if (chatId == null) return;
      final reaction = ChatReaction.fromJson(data);
      final updated = state.messages.map((m) {
        if (m.id == chatId) {
          final reactions = List<ChatReaction>.from(m.reactions);
          final idx = reactions.indexWhere((r) => r.userId == reaction.userId);
          if (idx >= 0) {
            reactions[idx] = reaction;
          } else {
            reactions.add(reaction);
          }
          return m.copyWith(reactions: reactions);
        }
        return m;
      }).toList();
      state = state.copyWith(messages: updated);
    });
  }

  Future<ChatMessage?> sendMessage(String text) async {
    if (text.trim().isEmpty) return null;
    state = state.copyWith(sending: true);
    try {
      final res = await dioClient.post(
        '/chats',
        data: dio_lib.FormData.fromMap({
          'receiverId': otherId,
          'message': text.trim(),
        }),
      );
      final msg = ChatMessage.fromJson(res.data as Map<String, dynamic>);
      state = state.copyWith(
        messages: [...state.messages, msg],
        sending: false,
      );
      // Relay via SignalR
      SignalRService.instance.sendMessage(_toMap(msg), otherId);
      return msg;
    } catch (_) {
      state = state.copyWith(sending: false);
      return null;
    }
  }

  Future<void> sendMedia(String path, String type) async {
    state = state.copyWith(sending: true);
    try {
      final filename = type == 'Voice' ? 'voice.m4a' : 'img.jpg';
      final form = dio_lib.FormData.fromMap({
        'receiverId': otherId,
        'message': type == 'Voice' ? '[Voice]' : '[Image]',
        'messageType': type,
        'mediaFile': await dio_lib.MultipartFile.fromFile(
          path,
          filename: filename,
        ),
      });
      final res = await dioClient.post('/chats', data: form);
      final msg = ChatMessage.fromJson(res.data as Map<String, dynamic>);
      state = state.copyWith(
        messages: [...state.messages, msg],
        sending: false,
      );
      SignalRService.instance.sendMessage(_toMap(msg), otherId);
    } catch (_) {
      state = state.copyWith(sending: false);
    }
  }

  Future<void> reactToMessage(String messageId, String reactionType) async {
    try {
      final res = await dioClient.post(
        '/chats/$messageId/react',
        data: {'reactionType': reactionType},
      );
      final reaction = ChatReaction.fromJson(res.data as Map<String, dynamic>);
      final updated = state.messages.map((m) {
        if (m.id == messageId) {
          final reactions = List<ChatReaction>.from(m.reactions);
          final idx = reactions.indexWhere((r) => r.userId == myId);
          if (idx >= 0) {
            reactions[idx] = reaction;
          } else {
            reactions.add(reaction);
          }
          return m.copyWith(reactions: reactions);
        }
        return m;
      }).toList();
      state = state.copyWith(messages: updated);

      // Notify other user via SignalR
      final otherUser =
          state.messages.firstWhere((m) => m.id == messageId).senderId == myId
          ? otherId
          : otherId;
      SignalRService.instance.sendReactionUpdated(otherUser, {
        'id': reaction.id,
        'chatId': messageId,
        'userId': reaction.userId,
        'displayName': reaction.displayName,
        'reactionType': reactionType,
        'createdAt': reaction.createdAt,
      });
    } catch (_) {}
  }

  Future<void> removeReaction(String messageId) async {
    try {
      await dioClient.delete('/chats/$messageId/react');
      final updated = state.messages.map((m) {
        if (m.id == messageId) {
          final reactions = m.reactions.where((r) => r.userId != myId).toList();
          return m.copyWith(reactions: reactions);
        }
        return m;
      }).toList();
      state = state.copyWith(messages: updated);
    } catch (_) {}
  }

  void broadcastTyping(bool isTyping) {
    _typingTimer?.cancel();
    SignalRService.instance.sendTyping(otherId, isTyping);
    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        SignalRService.instance.sendTyping(otherId, false);
      });
    }
  }

  Map<String, dynamic> _toMap(ChatMessage m) => {
    'id': m.id,
    'senderId': m.senderId,
    'receiverId': m.receiverId,
    'message': m.message,
    'mediaUrl': m.mediaUrl,
    'messageType': m.messageType,
    'status': m.status,
    'isRead': m.isRead,
    'createdAt': m.createdAt,
    'reactions': m.reactions
        .map(
          (r) => {
            'id': r.id,
            'chatId': r.chatId,
            'userId': r.userId,
            'displayName': r.displayName,
            'reactionType': r.reactionType,
            'createdAt': r.createdAt,
          },
        )
        .toList(),
  };

  @override
  void dispose() {
    _typingTimer?.cancel();
    _msgSub?.cancel();
    _typingSub?.cancel();
    _readSub?.cancel();
    _reactionSub?.cancel();
    super.dispose();
  }
}

final _chatProvider = StateNotifierProvider.family
    .autoDispose<_ChatNotifier, _ChatState, (String, String, String)>(
      (ref, ids) => _ChatNotifier(ids.$1, ids.$2, ids.$3),
    );

// ─── Screen ──────────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? receiverAvatar;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _player = AudioPlayer();
  final _recorder = FlutterSoundRecorder();
  bool _recorderOpen = false;
  String? _playingId;
  bool _recording = false;
  String? _recordingPath;
  Timer? _recordTimer;
  int _recordSeconds = 0;

  String get _myId => ref.read(authProvider).user?.id ?? '';
  (String, String, String) get _key =>
      (_myId, widget.receiverId, widget.receiverName);

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels <= 80) {
      ref.read(_chatProvider(_key).notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _player.dispose();
    _recordTimer?.cancel();
    if (_recorderOpen) {
      _recorder.closeRecorder();
      _recorderOpen = false;
    }
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (animated) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text;
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    ref.read(_chatProvider(_key).notifier).broadcastTyping(false);
    await ref.read(_chatProvider(_key).notifier).sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    final res = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (res == null) return;
    await ref.read(_chatProvider(_key).notifier).sendMedia(res.path, 'Image');
    _scrollToBottom();
  }

  Future<void> _startRecording() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;
    try {
      if (!_recorderOpen) {
        await _recorder.openRecorder();
        _recorderOpen = true;
      }
      final dir = await getTemporaryDirectory();
      _recordingPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacADTS,
      );
      _recordSeconds = 0;
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
      setState(() => _recording = true);
    } catch (_) {}
  }

  Future<void> _stopRecording({bool send = true}) async {
    _recordTimer?.cancel();
    String? path;
    try {
      path = await _recorder.stopRecorder();
      path ??= _recordingPath;
    } catch (_) {
      path = _recordingPath;
    }
    setState(() {
      _recording = false;
      _recordSeconds = 0;
      _recordingPath = null;
    });
    if (send && path != null && File(path).existsSync()) {
      await ref.read(_chatProvider(_key).notifier).sendMedia(path, 'Voice');
      _scrollToBottom();
    }
  }

  Future<void> _playVoice(String msgId, String url) async {
    if (_playingId == msgId) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }
    final fullUrl = url.startsWith('http')
        ? url
        : '${ApiConstants.uploadsBase}/$url';
    try {
      await _player.setUrl(fullUrl);
      _player.play();
      setState(() => _playingId = msgId);
      _player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted) {
          setState(() => _playingId = null);
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(_chatProvider(_key));
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(_chatProvider(_key), (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 32,
        title: Row(
          children: [
            Stack(
              children: [
                AvatarWidget(
                  url: widget.receiverAvatar,
                  name: widget.receiverName,
                  radius: 20,
                ),
                if (chatState.otherOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF0B0D21)
                              : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.receiverName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (chatState.otherTyping)
                  Text(
                        'typing...',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(duration: 1200.ms, color: scheme.primary)
                else if (chatState.otherOnline)
                  Text(
                    'online',
                    style: TextStyle(fontSize: 11, color: scheme.primary),
                  )
                else
                  Text(
                    'offline',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurface.withAlpha(100),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Load more indicator
          if (chatState.loadingMore)
            LinearProgressIndicator(
              color: scheme.primary,
              backgroundColor: scheme.primary.withAlpha(20),
              minHeight: 2,
            ),
          Expanded(
            child: chatState.loading
                ? const Center(child: CircularProgressIndicator())
                : chatState.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 60,
                          color: scheme.primary.withAlpha(80),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Say hello!',
                          style: TextStyle(
                            color: scheme.onSurface.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: chatState.messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = chatState.messages[i];
                      final isMine = msg.senderId == _myId;
                      final showDate =
                          i == 0 ||
                          _differentDay(
                            chatState.messages[i - 1].createdAt,
                            msg.createdAt,
                          );
                      return Column(
                        children: [
                          if (showDate) _DateDivider(iso: msg.createdAt),
                          _MessageBubble(
                            msg: msg,
                            isMine: isMine,
                            playingId: _playingId,
                            onPlayVoice: _playVoice,
                            myId: _myId,
                            onReact: (emoji) => ref
                                .read(_chatProvider(_key).notifier)
                                .reactToMessage(msg.id, emoji),
                            onRemoveReaction: () => ref
                                .read(_chatProvider(_key).notifier)
                                .removeReaction(msg.id),
                          ).animate().fadeIn(duration: 150.ms),
                        ],
                      );
                    },
                  ),
          ),
          _buildInputBar(scheme, isDark, chatState.sending),
        ],
      ),
    );
  }

  bool _differentDay(String a, String b) {
    try {
      final da = DateTime.parse(a);
      final db = DateTime.parse(b);
      return da.day != db.day || da.month != db.month || da.year != db.year;
    } catch (_) {
      return false;
    }
  }

  Widget _buildInputBar(ColorScheme scheme, bool isDark, bool sending) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B0D21) : Colors.white,
          border: Border(top: BorderSide(color: scheme.primary.withAlpha(40))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: _recording
            ? _buildRecordingBar(scheme)
            : _buildNormalBar(scheme, isDark, sending),
      ),
    );
  }

  Widget _buildRecordingBar(ColorScheme scheme) {
    final mins = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_recordSeconds % 60).toString().padLeft(2, '0');
    return Row(
      children: [
        Icon(Icons.fiber_manual_record, color: scheme.error, size: 16)
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fadeOut(duration: 600.ms),
        const SizedBox(width: 8),
        Text(
          '$mins:$secs',
          style: TextStyle(
            color: scheme.error,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        // Cancel
        IconButton(
          icon: Icon(Icons.delete_outline, color: scheme.error),
          onPressed: () => _stopRecording(send: false),
        ),
        const SizedBox(width: 8),
        // Send voice
        GestureDetector(
          onTap: () => _stopRecording(send: true),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: scheme.primary.withAlpha(80), blurRadius: 10),
              ],
            ),
            child: Icon(
              Icons.send_rounded,
              size: 20,
              color: scheme.brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalBar(ColorScheme scheme, bool isDark, bool sending) {
    return Row(
      children: [
        // Image
        IconButton(
          icon: Icon(Icons.image_outlined, color: scheme.primary),
          onPressed: sending ? null : _sendImage,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 2),
        // Text input
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D3D) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.primary.withAlpha(40)),
            ),
            child: TextField(
              controller: _ctrl,
              onChanged: (v) => ref
                  .read(_chatProvider(_key).notifier)
                  .broadcastTyping(v.isNotEmpty),
              decoration: const InputDecoration(
                hintText: 'Message...',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
              ),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Voice record (hold) / Send (tap when text)
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _ctrl,
          builder: (ctx, value, child) {
            final hasText = value.text.trim().isNotEmpty;
            if (hasText) {
              return GestureDetector(
                onTap: sending ? null : _send,
                child: _CircleActionButton(
                  color: scheme.primary,
                  child: Icon(
                    Icons.send_rounded,
                    size: 18,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              );
            }
            return GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(send: true),
              child: _CircleActionButton(
                color: scheme.primary,
                child: Icon(
                  Icons.mic_rounded,
                  size: 20,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final Color color;
  final Widget child;
  const _CircleActionButton({required this.color, required this.child});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: color.withAlpha(80), blurRadius: 10)],
    ),
    child: Center(child: child),
  );
}

// ─── Date Divider ─────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final String iso;
  const _DateDivider({required this.iso});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String label;
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        label = 'Today';
      } else if (dt.day == now.subtract(const Duration(days: 1)).day &&
          dt.month == now.month &&
          dt.year == now.year) {
        label = 'Yesterday';
      } else {
        label = '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) {
      label = '';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.onSurface.withAlpha(30))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurface.withAlpha(100),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: scheme.onSurface.withAlpha(30))),
        ],
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMine;
  final String? playingId;
  final Future<void> Function(String, String) onPlayVoice;
  final String myId;
  final void Function(String emoji) onReact;
  final VoidCallback onRemoveReaction;

  const _MessageBubble({
    required this.msg,
    required this.isMine,
    this.playingId,
    required this.onPlayVoice,
    required this.myId,
    required this.onReact,
    required this.onRemoveReaction,
  });

  static const _reactionEmojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];

  void _showReactionPicker(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myReaction = msg.reactions
        .where((r) => r.userId == myId)
        .firstOrNull
        ?.reactionType;

    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => _ReactionPickerDialog(
        emojis: _reactionEmojis,
        selectedEmoji: myReaction,
        scheme: scheme,
        isDark: isDark,
        onSelect: (emoji) {
          Navigator.of(ctx).pop();
          if (emoji == myReaction) {
            onRemoveReaction();
          } else {
            onReact(emoji);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isMine
        ? scheme.primary
        : (isDark ? const Color(0xFF1E2148) : const Color(0xFFECEFF1));
    final textColor = isMine
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white : Colors.black87);

    Widget content;
    if (msg.messageType == 'Image' && msg.mediaUrl != null) {
      final url = msg.mediaUrl!.startsWith('http')
          ? msg.mediaUrl!
          : '${ApiConstants.uploadsBase}/${msg.mediaUrl}';
      content = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 200,
          fit: BoxFit.cover,
          placeholder: (ctx, url) =>
              Container(height: 140, color: scheme.surface),
          errorWidget: (ctx, url, err) => const Icon(Icons.broken_image),
        ),
      );
    } else if (msg.messageType == 'Voice' && msg.mediaUrl != null) {
      final isPlaying = playingId == msg.id;
      content = GestureDetector(
        onTap: () => onPlayVoice(msg.id, msg.mediaUrl!),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: textColor,
              size: 32,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice message',
                  style: TextStyle(color: textColor, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 3,
                  width: 100,
                  decoration: BoxDecoration(
                    color: textColor.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      content = Text(
        msg.message,
        style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
      );
    }

    // Build reaction chips
    final hasReactions = msg.reactions.isNotEmpty;
    final reactionGroups = <String, int>{};
    for (final r in msg.reactions) {
      reactionGroups[r.reactionType] =
          (reactionGroups[r.reactionType] ?? 0) + 1;
    }

    return Padding(
      padding: EdgeInsets.only(top: 2, bottom: hasReactions ? 10 : 2),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) const SizedBox(width: 4),
          GestureDetector(
            onLongPress: () => _showReactionPicker(context),
            onDoubleTap: () => onReact('❤️'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMine ? 18 : 4),
                        bottomRight: Radius.circular(isMine ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: isMine
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        content,
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(msg.createdAt),
                              style: TextStyle(
                                color: textColor.withAlpha(130),
                                fontSize: 10,
                              ),
                            ),
                            if (isMine) ...[
                              const SizedBox(width: 4),
                              _StatusTick(status: msg.status, color: textColor),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Reaction badges at the bottom
                if (hasReactions)
                  Positioned(
                    bottom: -8,
                    right: isMine ? 8 : null,
                    left: isMine ? null : 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2D4D) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withAlpha(20)
                              : Colors.black.withAlpha(10),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: reactionGroups.entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Text(
                              e.value > 1 ? '${e.key}${e.value}' : e.key,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isMine) const SizedBox(width: 4),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _StatusTick extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusTick({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final tickColor = status == 'Read' ? Colors.blue : color.withAlpha(150);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check, size: 11, color: tickColor),
        if (status == 'Delivered' || status == 'Read')
          Transform.translate(
            offset: const Offset(-5, 0),
            child: Icon(Icons.check, size: 11, color: tickColor),
          ),
      ],
    );
  }
}

// ─── Reaction Picker Dialog ──────────────────────────────────────────────────

class _ReactionPickerDialog extends StatelessWidget {
  final List<String> emojis;
  final String? selectedEmoji;
  final ColorScheme scheme;
  final bool isDark;
  final void Function(String emoji) onSelect;

  const _ReactionPickerDialog({
    required this.emojis,
    this.selectedEmoji,
    required this.scheme,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.black.withAlpha(80),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1D3D).withAlpha(240)
                  : Colors.white.withAlpha(240),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: scheme.primary.withAlpha(60)),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withAlpha(30),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: emojis.asMap().entries.map((entry) {
                final idx = entry.key;
                final emoji = entry.value;
                final isSelected = selectedEmoji == emoji;
                return GestureDetector(
                  onTap: () => onSelect(emoji),
                  child:
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(6),
                        decoration: isSelected
                            ? BoxDecoration(
                                color: scheme.primary.withAlpha(40),
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ).animate().scale(
                        begin: const Offset(0, 0),
                        end: const Offset(1, 1),
                        duration: Duration(milliseconds: 200 + idx * 50),
                        curve: Curves.elasticOut,
                      ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
