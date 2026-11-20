String fmtPrice(double p) {
  if (p >= 1000) return p.toStringAsFixed(2);
  if (p >= 1) return p.toStringAsFixed(4);
  if (p >= 0.01) return p.toStringAsFixed(5);
  return p.toStringAsFixed(8);
}

String fmtVol(double v) {
  if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
  if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
  if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

String fmtPct(double v) {
  final a = v.abs();
  final s = v >= 0 ? '+' : '-';
  if (a >= 1000) return '$s${(a / 1000).toStringAsFixed(1)}k%';
  if (a >= 100) return '$s${a.toStringAsFixed(0)}%';
  return '$s${a.toStringAsFixed(1)}%';
}

String fmtPct2(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';

String two(int n) => n.toString().padLeft(2, '0');

String fmtTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

String fmtUsd(double v) => '${v >= 0 ? '+' : '-'}${v.abs().toStringAsFixed(2)}';
