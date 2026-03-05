import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_provider.dart';
import 'theme/app_theme.dart';
import 'navigation/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authNotifier = AuthNotifier();
  await authNotifier.restoreSession();
  runApp(
    ProviderScope(
      overrides: [authNotifierProvider.overrideWith((ref) => authNotifier)],
      child: InsureAdminApp(routerConfig: AppRouter.createRouter(authNotifier)),
    ),
  );
}

class InsureAdminApp extends StatelessWidget {
  const InsureAdminApp({super.key, required this.routerConfig});

  final GoRouter routerConfig;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'InsureAdmin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: routerConfig,
    );
  }
}
