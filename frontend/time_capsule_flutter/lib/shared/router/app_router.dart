import 'package:flutter/material.dart';
import '../../features/profile/screens/user_profile_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/feed/screens/create_post_screen.dart';
import '../../features/capsule/screens/create_capsule_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/gameroom/screens/gameroom_detail_screen.dart';
import '../../features/gameroom/screens/create_gameroom_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/user-profile':
        final userId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: userId),
        );
      case '/create-post':
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) =>
              CreatePostScreen(initialImagePath: args?['imagePath'] as String?),
        );
      case '/create-capsule':
        return MaterialPageRoute(
          builder: (_) => const CreateCapsuleScreen(),
          fullscreenDialog: true,
        );
      case '/chat':
        final args = settings.arguments as Map<String, String>;
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            receiverId: args['userId']!,
            receiverName: args['name']!,
          ),
        );
      case '/gameroom':
        final args = settings.arguments as Map<String, String>;
        return MaterialPageRoute(
          builder: (_) => GameRoomDetailScreen(
            roomId: args['id']!,
            roomTitle: args['title']!,
          ),
        );
      case '/create-gameroom':
        return MaterialPageRoute(
          builder: (_) => const CreateGameRoomScreen(),
          fullscreenDialog: true,
        );
      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Not found'))),
        );
    }
  }
}
