import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forgefit/core/theme.dart';

void main() {
  group('ForgeFit Obsidian design system', () {
    test('uses Material 3 and the accessible premium palette', () {
      final theme = AppTheme.darkTheme;

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, AppTheme.cyan);
      expect(theme.colorScheme.secondary, AppTheme.vividPurple);
      expect(theme.navigationBarTheme.height, 72);
      expect(theme.filledButtonTheme.style?.minimumSize?.resolve({}),
          const Size(48, 54));
    });

    testWidgets('navigation destinations expose readable labels',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Oggi'),
                NavigationDestination(
                    icon: Icon(Icons.history), label: 'Storico'),
                NavigationDestination(
                    icon: Icon(Icons.insights), label: 'Progressi'),
                NavigationDestination(
                    icon: Icon(Icons.auto_awesome), label: 'Coach'),
                NavigationDestination(
                    icon: Icon(Icons.person), label: 'Profilo'),
              ],
            ),
          ),
        ),
      );

      for (final label in [
        'Oggi',
        'Storico',
        'Progressi',
        'Coach',
        'Profilo'
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });
  });
}
