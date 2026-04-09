import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../constants/api_constants.dart';

class SignalRService {
  static SignalRService? _instance;
  static SignalRService get instance => _instance ??= SignalRService._();
  SignalRService._();

  HubConnection? _hub;
  bool _isConnecting = false;
  final _storage = const FlutterSecureStorage();

  // Streams
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<(String, bool)>.broadcast();
  final _readController = StreamController<(String, List<String>)>.broadcast();
  final _reactionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;
  Stream<(String, bool)> get onTyping => _typingController.stream;
  Stream<(String, List<String>)> get onMessagesRead => _readController.stream;
  Stream<Map<String, dynamic>> get onReaction => _reactionController.stream;
  Stream<Map<String, dynamic>> get onNotification =>
      _notificationController.stream;

  bool get isConnected =>
      _hub != null && _hub!.state == HubConnectionState.Connected;

  Future<void> connect() async {
    if (_isConnecting || isConnected) return;
    _isConnecting = true;

    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        _isConnecting = false;
        return;
      }

      _hub = HubConnectionBuilder()
          .withUrl(
            ApiConstants.chatHubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async => token,
              skipNegotiation: true,
              transport: HttpTransportType.WebSockets,
            ),
          )
          .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 30000])
          .build();

      _hub!.on('ReceiveMessage', (args) {
        if (args != null && args.isNotEmpty) {
          final data = args[0] as Map<String, dynamic>?;
          if (data != null) _messageController.add(data);
        }
      });

      _hub!.on('UserTyping', (args) {
        if (args != null && args.length >= 2) {
          final userId = args[0] as String;
          final isTyping = args[1] as bool;
          _typingController.add((userId, isTyping));
        }
      });

      _hub!.on('MessagesRead', (args) {
        if (args != null && args.length >= 2) {
          final userId = args[0] as String;
          final ids = (args[1] as List).map((e) => e.toString()).toList();
          _readController.add((userId, ids));
        }
      });

      _hub!.on('ReactionUpdated', (args) {
        if (args != null && args.isNotEmpty) {
          final data = args[0] as Map<String, dynamic>?;
          if (data != null) _reactionController.add(data);
        }
      });

      _hub!.on('ReceiveNotification', (args) {
        if (args != null && args.isNotEmpty) {
          final data = args[0] as Map<String, dynamic>?;
          if (data != null) {
            debugPrint('[SignalR] ReceiveNotification: ${data['type']}');
            _notificationController.add(data);
          }
        }
      });

      _hub!.onclose(({Exception? error}) {
        debugPrint('[SignalR] Connection closed: $error');
      });

      _hub!.onreconnecting(({Exception? error}) {
        debugPrint('[SignalR] Reconnecting: $error');
      });

      _hub!.onreconnected(({String? connectionId}) {
        debugPrint('[SignalR] Reconnected: $connectionId');
      });

      await _hub!.start();
      debugPrint('[SignalR] Connected');
    } catch (e) {
      debugPrint('[SignalR] Connection error: $e');
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> sendMessage(
    Map<String, dynamic> message,
    String receiverId,
  ) async {
    if (!isConnected) return;
    try {
      await _hub!.invoke('SendMessage', args: [message, receiverId]);
    } catch (e) {
      debugPrint('[SignalR] SendMessage error: $e');
    }
  }

  Future<void> sendTyping(String receiverId, bool isTyping) async {
    if (!isConnected) return;
    try {
      await _hub!.invoke('Typing', args: [receiverId, isTyping]);
    } catch (e) {
      debugPrint('[SignalR] Typing error: $e');
    }
  }

  Future<void> sendMessageRead(
    String otherUserId,
    List<String> messageIds,
  ) async {
    if (!isConnected) return;
    try {
      await _hub!.invoke('MessageRead', args: [otherUserId, messageIds]);
    } catch (e) {
      debugPrint('[SignalR] MessageRead error: $e');
    }
  }

  Future<void> sendReactionUpdated(
    String otherUserId,
    Map<String, dynamic> data,
  ) async {
    if (!isConnected) return;
    try {
      await _hub!.invoke('ReactionUpdated', args: [otherUserId, data]);
    } catch (e) {
      debugPrint('[SignalR] ReactionUpdated error: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await _hub?.stop();
    } catch (_) {}
    _hub = null;
  }

  void dispose() {
    _messageController.close();
    _typingController.close();
    _readController.close();
    _reactionController.close();
    _notificationController.close();
    disconnect();
    _instance = null;
  }
}
