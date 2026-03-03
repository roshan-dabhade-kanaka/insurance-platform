import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:admin_app/auth/auth_provider.dart';
import 'package:admin_app/main.dart';
import 'package:admin_app/navigation/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App loads with layout', (WidgetTester tester) async {
    final authNotifier = AuthNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => authNotifier),
        ],
        child: InsureAdminApp(
          routerConfig: AppRouter.createRouter(authNotifier),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('InsureAdmin'), findsOneWidget);
  });
}
