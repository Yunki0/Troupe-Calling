import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troupe_manager/screens/splash_screen.dart';
import 'package:troupe_manager/theme.dart';

void main() {
  testWidgets(
    'reaches the app after initialization without an artificial wait',
    (tester) async {
      final start = tester.binding.clock.now();

      await tester.pumpWidget(
        _app(initialize: () async => 'Troupe des Éclaireurs'),
      );
      await tester.pumpAndSettle();

      expect(find.text('RootShell prêt'), findsOneWidget);
      expect(
        tester.binding.clock.now().difference(start),
        lessThan(const Duration(seconds: 1)),
      );
    },
  );

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('holds the matching $brightness splash while initializing', (
      tester,
    ) async {
      final initialization = Completer<String?>();
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(_app(initialize: () => initialization.future));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(
        scaffold.backgroundColor,
        brightness == Brightness.light
            ? AppColors.canvas
            : AppColors.darkCanvas,
      );
      final title = tester.widget<Text>(find.text('Appel Scout'));
      expect(
        title.style?.color,
        brightness == Brightness.light
            ? AppColors.primaryDeep
            : AppColors.darkText,
      );
    });
  }

  testWidgets('skips the splash transition when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(disableAnimations: true, initialize: () async => null),
    );
    await tester.pump();

    expect(find.text('RootShell prêt'), findsOneWidget);
  });

  testWidgets('shows a retry action when startup initialization fails', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      _app(
        initialize: () async {
          attempts++;
          if (attempts == 1) throw StateError('Local database unavailable');
          return 'Troupe des Éclaireurs';
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Impossible de préparer les données locales.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('RootShell prêt'), findsOneWidget);
    expect(attempts, 2);
  });
}

Widget _app({
  required Future<String?> Function() initialize,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: buildAppTheme(),
    darkTheme: buildAppDarkTheme(),
    themeMode: ThemeMode.system,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: SplashScreen(
        initialize: initialize,
        nextBuilder: (context, troopName) =>
            const Scaffold(body: Center(child: Text('RootShell prêt'))),
      ),
    ),
  );
}
