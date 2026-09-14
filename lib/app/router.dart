import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/create_work/presentation/create_work_screen.dart';
import '../features/credits/presentation/credits_screen.dart';
import '../features/credits/presentation/redeem_code_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/files/presentation/files_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/update/presentation/force_update_screen.dart';
import '../core/widgets/main_layout.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/update_provider.dart';
import '../models/user_profile.dart';
import '../models/academic_work.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Usar select para evitar recriar o roteador quando campos irrelevantes (como créditos) mudarem
  final authUserId = ref.watch(authStateProvider.select((value) => value.value?.uid));
  final userStatus = ref.watch(userProfileProvider.select((value) => value.value?.status));
  final updateState = ref.watch(updateCheckProvider);

  // Chaves criadas dentro do provider para garantir que cada instância do GoRouter tenha suas próprias chaves
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

  return GoRouter(
    initialLocation: '/login',
    navigatorKey: rootNavigatorKey,
    redirect: (context, state) {
      final isLoggedIn = authUserId != null;
      final isLoggingIn = state.uri.path == '/login';
      final isSigningUp = state.uri.path == '/signup';
      final isForcingUpdate = state.uri.path == '/force-update';

      // 1. Verificação de Atualização Obrigatória (Somente após login)
      if (isLoggedIn) {
        final updateRequired = updateState.value?.isUpdateRequired ?? false;
        if (updateRequired && !isForcingUpdate) {
          return '/force-update';
        }
      }

      if (!isLoggedIn) {
        if (isLoggingIn || isSigningUp) return null;
        return '/login';
      }

      // Se logado, verificar status do perfil
      if (userStatus == UserStatus.disabled) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn || isSigningUp) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/force-update',
        builder: (context, state) {
          final config = updateState.value?.config;
          if (config == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return ForceUpdateScreen(config: config);
        },
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return MainLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/create-work',
            builder: (context, state) => CreateWorkScreen(initialWork: state.extra as AcademicWork?),
          ),
          GoRoute(
            path: '/credits',
            builder: (context, state) => const CreditsScreen(),
            routes: [
              GoRoute(
                path: 'redeem',
                builder: (context, state) => const RedeemCodeScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/files',
            builder: (context, state) => const FilesScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
