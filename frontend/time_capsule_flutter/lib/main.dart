import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_constants.dart';
import 'core/services/fcm_service.dart';
import 'core/services/signalr_service.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/feed/screens/feed_screen.dart';
import 'features/feed/providers/feed_provider.dart';
import 'features/chat/screens/chat_list_screen.dart';
import 'features/capsule/screens/capsule_list_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'shared/widgets/liquid_glass_navbar.dart';
import 'shared/router/app_router.dart';
import 'core/notifications/notification_service.dart'; // init called after widget tree is ready

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize Firebase (reads google-services.json on Android,
  // GoogleService-Info.plist on iOS at build time).
  // Wrapped in try-catch so the app still works during local dev
  // before real Firebase credentials are set up.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[FCM] Firebase init failed: $e');
  }

  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );

  runApp(const ProviderScope(child: TimeCapsuleApp()));
}

class TimeCapsuleApp extends ConsumerWidget {
  const TimeCapsuleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    return MaterialApp(
      title: 'TimeCapsule',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(themeState.accent),
      darkTheme: buildDarkTheme(themeState.accent),
      themeMode: themeState.mode,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  bool _showLogin = true;
  bool _servicesInitialized = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.loading) {
      return const _SplashScreen();
    }

    if (!authState.isAuthenticated) {
      _servicesInitialized = false; // reset so it re-runs on next login
      SignalRService.instance.disconnect();
      return _showLogin
          ? LoginScreen(onGoRegister: () => setState(() => _showLogin = false))
          : RegisterScreen(onGoLogin: () => setState(() => _showLogin = true));
    }

    // Initialize notifications + FCM once after the user is authenticated
    // (must be inside the widget tree so Android Activity exists for permission dialogs).
    if (!_servicesInitialized) {
      _servicesInitialized = true;
      NotificationService.init().catchError((e) {
        debugPrint('[Notifications] init failed: $e');
      });
      FcmService.init().catchError((e) {
        debugPrint('[FCM] init failed: $e');
      });
      SignalRService.instance.connect().catchError((e) {
        debugPrint('[SignalR] init failed: $e');
      });
    }

    return const MainShell();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0B0D21), const Color(0xFF1A1D3D)]
                : [const Color(0xFFF0F2FF), const Color(0xFFE8ECFF)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary.withAlpha(20),
                      border: Border.all(
                        color: scheme.primary.withAlpha(100),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withAlpha(60),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.archive_rounded,
                      size: 48,
                      color: scheme.primary,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(
                    end: 1.08,
                    duration: 1200.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 24),
              Text(
                    'TimeCapsule',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                      letterSpacing: 1,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 2000.ms, color: scheme.primary),
              const SizedBox(height: 12),
              SizedBox(
                width: 40,
                child: LinearProgressIndicator(
                  color: scheme.primary,
                  backgroundColor: scheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  final List<int> _tabHistory = [];

  static const _navItems = [
    NavItem(
      icon: Icons.newspaper_outlined,
      activeIcon: Icons.newspaper_rounded,
      label: 'Feed',
    ),
    NavItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Chats',
    ),
    NavItem(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      label: 'Capsules',
    ),
    NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  void _onTabTap(int i) {
    if (i == _currentIndex) return; // already on this tab, do nothing
    setState(() {
      _tabHistory.add(_currentIndex);
      _currentIndex = i;
    });
    if (i == 0) {
      ref.read(feedProvider.notifier).fetchFeed(refresh: true);
    }
  }

  Future<void> _handleCameraTap() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo != null && mounted) {
      Navigator.pushNamed(
        context,
        '/create-post',
        arguments: {'imagePath': photo.path},
      );
    }
  }

  Future<void> _handleGalleryTap() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (photo != null && mounted) {
      Navigator.pushNamed(
        context,
        '/create-post',
        arguments: {'imagePath': photo.path},
      );
    }
  }

  void _handleTextPostTap() {
    Navigator.pushNamed(context, '/create-post');
  }

  @override
  Widget build(BuildContext context) {
    // Count capsules that are locked but past their unlock date = ready to unlock
    final capsuleAsync = ref.watch(myCapsuleProvider);
    final readyCount =
        capsuleAsync.whenOrNull(
          data: (list) => list.where((c) {
            if (!c.isLocked) return false;
            final unlockDate = DateTime.tryParse(c.unlockDate);
            return unlockDate != null && DateTime.now().isAfter(unlockDate);
          }).length,
        ) ??
        0;

    return Scaffold(
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_tabHistory.isNotEmpty) {
            setState(() => _currentIndex = _tabHistory.removeLast());
          } else {
            SystemNavigator.pop();
          }
        },
        child: IndexedStack(
          index: _currentIndex,
          children: [
            FeedScreen(
              onTapUser: (uid) {
                final myId = ref.read(authProvider).user?.id;
                if (uid == myId) {
                  setState(() {
                    _tabHistory.add(_currentIndex);
                    _currentIndex = 3;
                  });
                } else {
                  Navigator.pushNamed(context, '/user-profile', arguments: uid);
                }
              },
              onCreatePost: () => Navigator.pushNamed(context, '/create-post'),
            ),
            ChatListScreen(
              onOpenChat: (userId, name) => Navigator.pushNamed(
                context,
                '/chat',
                arguments: {'userId': userId, 'name': name},
              ),
            ),
            CapsuleListScreen(
              onCreateCapsule: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/create-capsule',
                );
                if (result == true) setState(() {});
              },
            ),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: LiquidGlassNavBar(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: _onTabTap,
        badges: readyCount > 0 ? {2: readyCount} : const {},
        onCameraTap: _handleCameraTap,
        onGalleryTap: _handleGalleryTap,
        onTextPostTap: _handleTextPostTap,
      ),
    );
  }
}
