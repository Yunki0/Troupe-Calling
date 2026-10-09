import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troupe_manager/theme.dart';

void main() {
  test('primary and text colors remain legible on app surfaces', () {
    expect(
      _contrastRatio(AppColors.primary, AppColors.surfaceWarm),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(AppColors.text, AppColors.canvas),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(AppColors.coral, AppColors.surfaceWarm),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(AppColors.lagoon, AppColors.surfaceWarm),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('theme uses the light scout-branch green palette', () {
    final theme = buildAppTheme();

    expect(theme.scaffoldBackgroundColor, AppColors.canvas);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.secondary, AppColors.lagoon);
    expect(theme.colorScheme.tertiary, AppColors.coral);
    expect(
      _greenChannel(AppColors.primary),
      greaterThan(_blueChannel(AppColors.primary)),
    );
    expect(
      _greenChannel(AppColors.canvas),
      greaterThan(_blueChannel(AppColors.canvas)),
    );
    expect(
      _greenChannel(AppColors.lagoonSoft),
      greaterThan(_blueChannel(AppColors.lagoonSoft)),
    );
  });
}

int _greenChannel(Color color) => (color.toARGB32() >> 8) & 0xFF;

int _blueChannel(Color color) => color.toARGB32() & 0xFF;

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
