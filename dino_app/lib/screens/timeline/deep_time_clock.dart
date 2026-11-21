import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../models/geologic_period.dart';
import '../../models/geologic_eon.dart';
import '../../models/mass_extinction_event.dart';
import '../../theme/strata_theme.dart';

const _clockSweep = math.pi * 2 * .985;

/// Clockwise angle from 12 o'clock for an age on the full Earth-history dial.
double deepTimeClockProgressAngleForAge(
  double ageMa, {
  required double oldestMa,
  required double youngestMa,
}) {
  final span = oldestMa - youngestMa;
  if (span <= 0) return 0;
  final fraction = ((oldestMa - ageMa) / span).clamp(0.0, 1.0);
  return fraction * _clockSweep;
}

/// Inverse of [deepTimeClockProgressAngleForAge]. Angles are clockwise from
/// 12 o'clock and clamp the small visual gap between oldest and present.
double deepTimeClockAgeAtProgressAngle(
  double angle, {
  required double oldestMa,
  required double youngestMa,
}) {
  final fraction = (angle / _clockSweep).clamp(0.0, 1.0);
  return oldestMa - fraction * (oldestMa - youngestMa);
}

/// A proportional Earth-history clock. Earth forms at 12 o'clock and time
/// advances clockwise toward the present.
class DeepTimeClock extends StatelessWidget {
  const DeepTimeClock({
    super.key,
    required this.periods,
    required this.eons,
    required this.selectedLabel,
    required this.selectedMa,
    required this.extinctions,
    required this.activeExtinctionId,
    required this.onAgeChanged,
    required this.onExtinctionSelected,
  });

  final List<GeologicPeriod> periods;
  final List<GeologicEon> eons;
  final String selectedLabel;
  final double selectedMa;
  final List<MassExtinctionEvent> extinctions;
  final String? activeExtinctionId;
  final ValueChanged<double> onAgeChanged;
  final ValueChanged<MassExtinctionEvent> onExtinctionSelected;

  double get _oldestMa =>
      eons.map((eon) => eon.startMa).reduce((a, b) => a > b ? a : b);
  double get _youngestMa =>
      eons.map((eon) => eon.endMa).reduce((a, b) => a < b ? a : b);

  double _ageAt(Offset offset, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = offset.dx - center.dx;
    final dy = offset.dy - center.dy;
    var angle = math.atan2(dy, dx) + math.pi / 2;
    angle %= math.pi * 2;
    if (angle < 0) angle += math.pi * 2;
    return deepTimeClockAgeAtProgressAngle(
      angle,
      oldestMa: _oldestMa,
      youngestMa: _youngestMa,
    );
  }

  MassExtinctionEvent? _eventAt(Offset offset, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * .93;
    for (var index = 0; index < extinctions.length; index++) {
      final event = extinctions[index];
      final angle =
          -math.pi / 2 +
          deepTimeClockProgressAngleForAge(
            event.markerMa,
            oldestMa: _oldestMa,
            youngestMa: _youngestMa,
          );
      final marker = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if ((marker - offset).distance <= 22) return event;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ordered = [...periods]
      ..sort((a, b) => b.startMa.compareTo(a.startMa));
    final oldestMa = _oldestMa;
    final youngestMa = _youngestMa;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = math.min(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final size = Size.square(side);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final event = _eventAt(details.localPosition, size);
                  if (event != null) {
                    onExtinctionSelected(event);
                  } else {
                    onAgeChanged(_ageAt(details.localPosition, size));
                  }
                },
                onPanUpdate: (details) =>
                    onAgeChanged(_ageAt(details.localPosition, size)),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: size,
                      painter: _DeepTimeClockPainter(
                        periods: ordered,
                        eons: eons,
                        extinctions: extinctions,
                        oldestMa: oldestMa,
                        youngestMa: youngestMa,
                        selectedMa: selectedMa,
                        activeExtinctionId: activeExtinctionId,
                      ),
                    ),
                    IgnorePointer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selectedLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: StrataColors.ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_formatMa(selectedMa)} Ma',
                            style: const TextStyle(
                              color: StrataColors.brown,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'DRAG THE HAND',
                            style: TextStyle(
                              color: StrataColors.muted,
                              fontSize: 9,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DeepTimeClockPainter extends CustomPainter {
  const _DeepTimeClockPainter({
    required this.periods,
    required this.eons,
    required this.extinctions,
    required this.oldestMa,
    required this.youngestMa,
    required this.selectedMa,
    required this.activeExtinctionId,
  });

  final List<GeologicPeriod> periods;
  final List<GeologicEon> eons;
  final List<MassExtinctionEvent> extinctions;
  final double oldestMa;
  final double youngestMa;
  final double selectedMa;
  final String? activeExtinctionId;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final span = oldestMa - youngestMa;
    if (span <= 0) return;

    canvas.drawCircle(
      center,
      radius * .98,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius * .98,
      Paint()
        ..color = StrataColors.brown.withValues(alpha: .15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final bandRadius = radius * .72;
    final bandWidth = radius * .20;
    for (final eon in eons) {
      final startAngle =
          -math.pi / 2 +
          deepTimeClockProgressAngleForAge(
            eon.startMa,
            oldestMa: oldestMa,
            youngestMa: youngestMa,
          );
      final endAngle =
          -math.pi / 2 +
          deepTimeClockProgressAngleForAge(
            eon.endMa,
            oldestMa: oldestMa,
            youngestMa: youngestMa,
          );
      final sweep = endAngle - startAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: bandRadius),
        startAngle,
        sweep,
        false,
        Paint()
          ..color = Color(eon.colorValue)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bandWidth
          ..strokeCap = StrokeCap.butt,
      );
    }
    for (final period in periods) {
      final startAngle =
          -math.pi / 2 +
          deepTimeClockProgressAngleForAge(
            period.startMa,
            oldestMa: oldestMa,
            youngestMa: youngestMa,
          );
      final endAngle =
          -math.pi / 2 +
          deepTimeClockProgressAngleForAge(
            period.endMa,
            oldestMa: oldestMa,
            youngestMa: youngestMa,
          );
      final sweep = endAngle - startAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: bandRadius),
        startAngle,
        sweep,
        false,
        Paint()
          ..color = _periodColor(period)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bandWidth
          ..strokeCap = StrokeCap.butt,
      );
    }

    final outerTickPaint = Paint()
      ..color = StrataColors.brown.withValues(alpha: .22)
      ..strokeWidth = 1.2;
    for (var index = 0; index < 60; index++) {
      final angle = -math.pi / 2 + index / 60 * math.pi * 2;
      final major = index % 5 == 0;
      final inner = radius * (major ? .87 : .90);
      final outer = radius * .94;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        outerTickPaint..strokeWidth = major ? 1.5 : 1,
      );
    }

    for (var index = 0; index < extinctions.length; index++) {
      final event = extinctions[index];
      final angle =
          -math.pi / 2 +
          deepTimeClockProgressAngleForAge(
            event.markerMa,
            oldestMa: oldestMa,
            youngestMa: youngestMa,
          );
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * .93;
      final active = event.id == activeExtinctionId;
      canvas.drawCircle(
        point,
        active ? 13 : 11,
        Paint()..color = StrataColors.ink,
      );
      canvas.drawCircle(
        point,
        active ? 10 : 8,
        Paint()..color = StrataColors.gold,
      );
      _paintCenteredText(
        canvas,
        '${index + 1}',
        point,
        color: StrataColors.ink,
        fontSize: 9,
      );
    }

    final handAngle =
        -math.pi / 2 +
        deepTimeClockProgressAngleForAge(
          selectedMa,
          oldestMa: oldestMa,
          youngestMa: youngestMa,
        );
    final handEnd =
        center +
        Offset(math.cos(handAngle), math.sin(handAngle)) * radius * .58;
    canvas.drawLine(
      center,
      handEnd,
      Paint()
        ..color = StrataColors.ink
        ..strokeWidth = math.max(3.0, radius * .018).toDouble()
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      center,
      radius * .06,
      Paint()..color = StrataColors.orange,
    );
    canvas.drawCircle(center, radius * .027, Paint()..color = StrataColors.ink);

    _paintCenteredText(
      canvas,
      '${_formatMa(oldestMa)} Ma',
      center + Offset(0, -radius * .47),
      color: StrataColors.muted,
      fontSize: math.max(9.0, radius * .045).toDouble(),
    );
    final endpointAngle = -math.pi / 2 + _clockSweep;
    canvas.drawCircle(
      center +
          Offset(math.cos(endpointAngle), math.sin(endpointAngle)) *
              radius *
              .98,
      radius * .022,
      Paint()..color = StrataColors.ink,
    );
  }

  @override
  bool shouldRepaint(covariant _DeepTimeClockPainter oldDelegate) =>
      oldDelegate.periods != periods ||
      oldDelegate.eons != eons ||
      oldDelegate.selectedMa != selectedMa ||
      oldDelegate.activeExtinctionId != activeExtinctionId ||
      oldDelegate.extinctions != extinctions;
}

void _paintCenteredText(
  Canvas canvas,
  String text,
  Offset center, {
  required Color color,
  required double fontSize,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}

Color _periodColor(GeologicPeriod period) {
  final value = period.color;
  if (value == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
    return StrataColors.orange;
  }
  return Color(int.parse(value.substring(1), radix: 16) | 0xFF000000);
}

String _formatMa(double age) => age == age.roundToDouble()
    ? age.toStringAsFixed(0)
    : age.toStringAsFixed(1);
