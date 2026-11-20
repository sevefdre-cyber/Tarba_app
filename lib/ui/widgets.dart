import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../format.dart';
import '../theme.dart';

/// Petite bougie verte/rouge dont la taille suit la variation de volume (dynamique, animee).
class VolumeCandle extends StatelessWidget {
  const VolumeCandle({super.key, required this.label, required this.value, required this.ready});
  final String label;
  final double value;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final col = value >= 0 ? kGreen : kRed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 9, color: kMuted)),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: ready ? value : 0.0),
          duration: const Duration(milliseconds: 500),
          builder: (BuildContext context, double v, Widget? _) {
            return SizedBox(
              height: 36,
              width: 14,
              child: CustomPaint(painter: _CandlePainter(v)),
            );
          },
        ),
        Text(
          ready ? fmtPct(value) : '...',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: ready ? col : kMuted,
          ),
        ),
      ],
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter(this.v);
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final base = Paint()
      ..color = kSurface2
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), base);
    final mag = math.min(1.0, v.abs() / 100.0);
    final body = math.max(2.0, mag * (mid - 3));
    final color = v >= 0 ? kGreen : kRed;
    final top = v >= 0 ? mid - body : mid;
    final wick = Paint()
      ..color = color
      ..strokeWidth = 1;
    final cx = size.width / 2;
    canvas.drawLine(Offset(cx, math.max(0.0, top - 3)), Offset(cx, math.min(size.height, top + body + 3)), wick);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(2, top, size.width - 4, body), const Radius.circular(1.5)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _CandlePainter old) => old.v != v;
}

class ScoreBadge extends StatelessWidget {
  const ScoreBadge({super.key, required this.score, required this.direction, required this.hot});
  final double score;
  final String direction;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final col = hot ? kRed : (score >= 30 ? kGold : kMuted);
    final arrow = direction == 'up' ? '↑' : (direction == 'down' ? '↓' : '·');
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: col.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: col.withOpacity(0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('${score.round()}', style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 15)),
          Text(arrow, style: TextStyle(color: col, fontSize: 11)),
        ],
      ),
    );
  }
}
