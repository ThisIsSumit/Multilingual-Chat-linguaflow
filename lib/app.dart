import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'core/network/dio_client.dart';
import 'core/network/socket_service.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/rooms/bloc/rooms_bloc.dart';
import 'features/rooms/data/rooms_repository.dart';
import 'features/rooms/screens/home_screen.dart';
import 'features/rooms/screens/create_room_screen.dart';
import 'features/rooms/screens/join_room_screen.dart';
import 'features/chat/bloc/chat_bloc.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/chat/models/room_model.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/chat/screens/room_members_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final SocketService _socketService;
  late final DioClient _dioClient;

  @override
  void initState() {
    super.initState();
    _socketService = SocketService();
    _dioClient = DioClient();
    _dioClient.onUnauthorized = () {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    };
  }

  ThemeData _buildTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: brightness == Brightness.dark
              ? Colors.white
              : AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(
          color: brightness == Brightness.dark
              ? Colors.white
              : AppColors.textPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository()),
        RepositoryProvider(create: (_) => RoomsRepository()),
        RepositoryProvider(create: (_) => ChatRepository()),
        RepositoryProvider(create: (_) => _socketService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (ctx) => AuthBloc(
              authRepository: ctx.read<AuthRepository>(),
              socketService: ctx.read<SocketService>(),
            ),
          ),
          BlocProvider(
            create: (ctx) => RoomsBloc(
              repository: ctx.read<RoomsRepository>(),
              socketService: ctx.read<SocketService>(),
            ),
          ),
          BlocProvider(
            create: (ctx) => ChatBloc(
              repository: ctx.read<ChatRepository>(),
              socketService: ctx.read<SocketService>(),
            ),
          ),
        ],
        child: MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'LinguaFlow',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: ThemeMode.system,
          initialRoute: '/',
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/':
                return MaterialPageRoute(builder: (_) => const SplashScreen());
              case '/login':
                return MaterialPageRoute(builder: (_) => const LoginScreen());
              case '/register':
                return MaterialPageRoute(
                    builder: (_) => const RegisterScreen());
              case '/home':
                return MaterialPageRoute(builder: (_) => const HomeScreen());
              case '/create-room':
                return MaterialPageRoute(
                    builder: (_) => const CreateRoomScreen());
              case '/join-room':
                return MaterialPageRoute(
                    builder: (_) => const JoinRoomScreen());
              case '/chat':
                final room = settings.arguments as Room;
                return PageRouteBuilder(
                  pageBuilder: (_, animation, __) => ChatScreen(room: room),
                  transitionsBuilder: (_, animation, __, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      )),
                      child: child,
                    );
                  },
                );
              case '/room-members':
                final args = settings.arguments as Map<String, dynamic>;
                final room = args['room'] as Room;
                final members = args['members'] as List<RoomMember>;
                return MaterialPageRoute(
                  builder: (_) =>
                      RoomMembersScreen(room: room, members: members),
                );
              default:
                return MaterialPageRoute(builder: (_) => const SplashScreen());
            }
          },
        ),
      ),
    );
  }
}
