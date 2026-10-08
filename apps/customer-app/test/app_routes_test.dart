import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/auth/login_screen.dart';
import 'package:onehub_customer/features/auth/signup_screen.dart';
import 'package:onehub_customer/features/dashboard/dashboard_screen.dart';
import 'package:onehub_customer/features/requirements/bid_list_screen.dart';
import 'package:onehub_customer/features/requirements/post_requirement_screen.dart';
import 'package:onehub_customer/main.dart';

import 'support/fake_api.dart';

void main() {
  Future<NavigatorState> pumpApp(WidgetTester tester) async {
    installFakeApi({
      'GET /providers': (_) => [],
      'GET /requirements/req-9/bids': (_) => [],
      'GET /requirements/mine': (_) => [],
    });
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OneHubCustomerApp());
    await tester.pumpAndSettle();
    return tester.state<NavigatorState>(find.byType(Navigator));
  }

  testWidgets('starts on the login screen', (tester) async {
    await pumpApp(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('the /signup and /dashboard routes are registered',
      (tester) async {
    final navigator = await pumpApp(tester);

    navigator.pushNamed('/signup');
    await tester.pumpAndSettle();
    expect(find.byType(SignupScreen), findsOneWidget);

    navigator.pushNamed('/dashboard');
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets(
      '/post-requirement opens the post screen for the sub-service passed in',
      (tester) async {
    final navigator = await pumpApp(tester);

    navigator.pushNamed('/post-requirement', arguments: 'sub-9');
    await tester.pumpAndSettle();

    final screen = tester
        .widget<PostRequirementScreen>(find.byType(PostRequirementScreen));
    expect(screen.subServiceId, 'sub-9');
  });

  testWidgets('/bids opens the bid list for the requirement passed in',
      (tester) async {
    final navigator = await pumpApp(tester);

    navigator.pushNamed('/bids', arguments: 'req-9');
    await tester.pumpAndSettle();

    final screen = tester.widget<BidListScreen>(find.byType(BidListScreen));
    expect(screen.requirementId, 'req-9');
  });
}
