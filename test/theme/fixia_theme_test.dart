import 'package:ms_frontend/core/theme/fixia_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('usa la paleta oficial de Fixia y la tipografía Inter', () {
    final theme = FixiaTheme.light;

    expect(theme.colorScheme.primary, const Color(0xFF01255D));
    expect(theme.colorScheme.secondary, const Color(0xFF006DFD));
    expect(theme.colorScheme.tertiary, const Color(0xFF00B79E));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF4F7FB));
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
  });
}
