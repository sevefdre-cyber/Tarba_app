import 'dart:math' as math;

class Candle {
  const Candle(this.t, this.o, this.h, this.l, this.c, this.v, this.qv);
  final int t;
  final double o;
  final double h;
  final double l;
  final double c;
  final double v;
  final double qv;
}

List<double> ema(List<double> v, int p) {
  if (v.isEmpty) return <double>[];
  final k = 2 / (p + 1);
  final out = List<double>.filled(v.length, v[0]);
  for (var i = 1; i < v.length; i++) {
    out[i] = v[i] * k + out[i - 1] * (1 - k);
  }
  return out;
}

List<double> rsi(List<double> c, [int p = 14]) {
  final out = List<double>.filled(c.length, 50.0);
  if (c.length <= p) return out;
  double g = 0;
  double l = 0;
  for (var i = 1; i <= p; i++) {
    final d = c[i] - c[i - 1];
    if (d >= 0) {
      g += d;
    } else {
      l -= d;
    }
  }
  g /= p;
  l /= p;
  out[p] = l == 0 ? 100.0 : 100 - 100 / (1 + g / l);
  for (var i = p + 1; i < c.length; i++) {
    final d = c[i] - c[i - 1];
    final gg = d > 0 ? d : 0.0;
    final ll = d < 0 ? -d : 0.0;
    g = (g * (p - 1) + gg) / p;
    l = (l * (p - 1) + ll) / p;
    out[i] = l == 0 ? 100.0 : 100 - 100 / (1 + g / l);
  }
  return out;
}

List<double> macdHist(List<double> c) {
  final e12 = ema(c, 12);
  final e26 = ema(c, 26);
  final m = List<double>.generate(c.length, (i) => e12[i] - e26[i]);
  final s = ema(m, 9);
  return List<double>.generate(c.length, (i) => m[i] - s[i]);
}

List<double> atr(List<Candle> c, [int p = 14]) {
  final out = List<double>.filled(c.length, 0.0);
  if (c.isEmpty) return out;
  out[0] = c[0].h - c[0].l;
  for (var i = 1; i < c.length; i++) {
    final tr = math.max(c[i].h - c[i].l,
        math.max((c[i].h - c[i - 1].c).abs(), (c[i].l - c[i - 1].c).abs()));
    out[i] = (out[i - 1] * (p - 1) + tr) / p;
  }
  return out;
}

/// Retourne 1 (haussier) ou -1 (baissier) pour chaque bougie.
List<int> supertrend(List<Candle> c, {int period = 10, double mult = 3.0}) {
  final n = c.length;
  final a = atr(c, period);
  final dir = List<int>.filled(n, 1);
  double fu = 0;
  double fl = 0;
  for (var i = 0; i < n; i++) {
    final hl2 = (c[i].h + c[i].l) / 2;
    final bu = hl2 + mult * a[i];
    final bl = hl2 - mult * a[i];
    if (i == 0) {
      fu = bu;
      fl = bl;
      dir[i] = 1;
      continue;
    }
    final pfu = fu;
    final pfl = fl;
    fu = (bu < pfu || c[i - 1].c > pfu) ? bu : pfu;
    fl = (bl > pfl || c[i - 1].c < pfl) ? bl : pfl;
    if (c[i].c > pfu) {
      dir[i] = 1;
    } else if (c[i].c < pfl) {
      dir[i] = -1;
    } else {
      dir[i] = dir[i - 1];
    }
  }
  return dir;
}
