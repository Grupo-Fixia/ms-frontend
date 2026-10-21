import 'package:flutter/material.dart';

import '../../../../../core/theme/fixia_theme.dart';

class CoverageZonePreview extends StatelessWidget {
  const CoverageZonePreview(
      {super.key, required this.city, required this.radiusKm});

  final String city;
  final int radiusKm;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 180,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _CoverageMapPainter()),
              Center(
                child: Container(
                  key: const ValueKey('coverage-zone-radius'),
                  width: 64 + radiusKm * 1.8,
                  height: 64 + radiusKm * 1.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FixiaColors.secondary.withOpacity(0.15),
                    border: Border.all(
                        color: FixiaColors.secondary.withOpacity(0.65),
                        width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                        color: FixiaColors.secondary, shape: BoxShape.circle),
                    child: const Icon(Icons.home_repair_service_rounded,
                        color: FixiaColors.white, size: 19),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: FixiaColors.white.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(99)),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    child: Text('$city · $radiusKm km',
                        key: const ValueKey('coverage-map-label'),
                        style: const TextStyle(
                            color: FixiaColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const Positioned(
                  right: 10,
                  bottom: 8,
                  child: Text('Vista ilustrativa',
                      style: TextStyle(
                          color: FixiaColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      );
}

class _CoverageMapPainter extends CustomPainter {
  const _CoverageMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFEAF2F8), BlendMode.src);
    final road = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final minorRoad = Paint()
      ..color = const Color(0xFFD5E1EA)
      ..strokeWidth = 2;
    for (var x = -size.height; x < size.width + size.height; x += 42) {
      canvas.drawLine(
          Offset(x.toDouble(), 0), Offset(x + size.height, size.height), road);
      canvas.drawLine(Offset(x.toDouble(), 0),
          Offset(x + size.height, size.height), minorRoad);
    }
    for (var y = 28; y < size.height; y += 46) {
      canvas.drawLine(
          Offset(0, y.toDouble()), Offset(size.width, y.toDouble()), road);
    }
  }

  @override
  bool shouldRepaint(covariant _CoverageMapPainter oldDelegate) => false;
}
