import 'package:bookbeam/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Onboarding screen is scrollable on smaller viewports',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
