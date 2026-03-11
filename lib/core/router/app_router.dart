import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/wallet_screen.dart';
import '../../features/chess/screens/chess_lobby_screens.dart';
import '../../features/chess/screens/chess_game_screen.dart';
import '../../features/whot/screens/whot_lobby_screen.dart';
import '../../features/whot/screens/whot_game_screen.dart';
import '../../features/ludo/screens/ludo_lobby_screen.dart';
import '../../features/ludo/screens/ludo_game_screen.dart';
import '../../shared/services/auth_service.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuth = authState.valueOrNull != null;
      final loc = state.matchedLocation;

      if (loc == '/splash') return null;
      if (!isAuth && loc != '/login' && loc != '/register') return '/login';
      if (isAuth && (loc == '/login' || loc == '/register')) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash',   builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/home',     builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/chess/lobby',
        builder: (_, __) => const ChessLobbyScreen(),
      ),
      GoRoute(
        path: '/chess/game/:gameId',
        builder: (_, state) => ChessGameScreen(gameId: state.pathParameters['gameId']!),
      ),
      GoRoute(
        path: '/whot/lobby',
        builder: (context, state) => WhotLobbyScreen(
          playerCount: (state.extra as int?) ?? 4,
        ),
      ),
      GoRoute(
        path: '/whot/game/:gameId',
        builder: (_, state) => WhotGameScreen(gameId: state.pathParameters['gameId']!),
      ),
      GoRoute(
        path: '/ludo/lobby',
        builder: (context, state) {
          final mode = state.extra as int? ?? 4;  // Get mode from extra, default to 4
          return LudoLobbyScreen(modeArg: mode);
        },
      ),
      GoRoute(
        path: '/ludo/game/:gameId',
        builder: (_, state) => LudoGameScreen(gameId: state.pathParameters['gameId']!),
      ),
      GoRoute(
        path: '/wallet', 
        builder: (_, __) => const WalletScreen()
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});