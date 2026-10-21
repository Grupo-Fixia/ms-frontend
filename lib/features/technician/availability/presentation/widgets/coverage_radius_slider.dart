import 'package:flutter/material.dart';

import '../../../../../core/theme/fixia_theme.dart';

class CoverageRadiusSlider extends StatelessWidget {
  const CoverageRadiusSlider(
      {super.key, required this.radiusKm, required this.onChanged});

  final int radiusKm;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('Radio de cobertura',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              Text('$radiusKm km',
                  key: const ValueKey('coverage-radius-value'),
                  style: const TextStyle(
                      color: FixiaColors.secondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ],
          ),
          Slider(
            key: const ValueKey('coverage-radius-slider'),
            value: radiusKm.toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            label: '$radiusKm km',
            activeColor: FixiaColors.secondary,
            onChanged: (value) => onChanged(value.round()),
          ),
          const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('1 km'), Text('50 km')]),
        ],
      );
}
