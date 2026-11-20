import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'models.dart';

class TradePlan {
  TradePlan({
    required this.symbol,
    required this.long,
    required this.entry,
    required this.sl,
    required this.tp1,
    required this.tp2,
    required this.leverage,
    required this.notional,
    required this.riskUsd,
  });
  final String symbol;
  final bool long;
  final double entry;
  final double sl;
  final double tp1;
  final double tp2;
  final double leverage;
  final double notional;
  final double riskUsd;
}

class PaperTrade {
  PaperTrade({
    required this.id,
    required this.symbol,
    required this.long,
    required this.futures,
    required this.entry,
    required this.notional,
    required this.leverage,
    required this.sl,
    required this.tp1,
    required this.tp2,
    required this.openedAt,
  });

  final int id;
  final String symbol;
  final bool long;
  final bool futures;
  final double entry;
  final double notional;
  final double leverage;
  double sl;
  final double tp1;
  final double tp2;
  final int openedAt;

  double remaining = 1.0;
  double realized = 0;
  bool tp1Hit = false;
  String status = 'open'; // open, tp, sl, be, manual
  int? closedAt;
  double? exit;

  double get margin => notional / leverage;
  double unrealized(double p) => notional * remaining * (p / entry - 1) * (long ? 1 : -1);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'symbol': symbol,
        'long': long,
        'futures': futures,
        'entry': entry,
        'notional': notional,
        'leverage': leverage,
        'sl': sl,
        'tp1': tp1,
        'tp2': tp2,
        'openedAt': openedAt,
        'remaining': remaining,
        'realized': realized,
        'tp1Hit': tp1Hit,
        'status': status,
        'closedAt': closedAt,
        'exit': exit,
      };

  factory PaperTrade.fromJson(Map<String, dynamic> j) {
    final t = PaperTrade(
      id: (j['id'] as num).toInt(),
      symbol: j['symbol'] as String,
      long: j['long'] as bool,
      futures: j['futures'] as bool,
      entry: toD(j['entry']),
      notional: toD(j['notional']),
      leverage: toD(j['leverage']),
      sl: toD(j['sl']),
      tp1: toD(j['tp1']),
      tp2: toD(j['tp2']),
      openedAt: (j['openedAt'] as num).toInt(),
    );
    t.remaining = toD(j['remaining']);
    t.realized = toD(j['realized']);
    t.tp1Hit = j['tp1Hit'] as bool;
    t.status = j['status'] as String;
    t.closedAt = j['closedAt'] == null ? null : (j['closedAt'] as num).toInt();
    t.exit = j['exit'] == null ? null : toD(j['exit']);
    return t;
  }
}

class Simulator {
  Simulator(this._priceOf, this._onChange);

  final double? Function(String) _priceOf;
  final VoidCallback _onChange;

  static const double startBalance = 10000;
  double balance = startBalance;
  final List<PaperTrade> open = [];
  final List<PaperTrade> history = [];
  int _id = 1;
  String lastAutoMsg = '';

  double equity() {
    double e = balance;
    for (final t in open) {
      final p = _priceOf(t.symbol);
      if (p != null) e += t.unrealized(p);
    }
    return e;
  }

  String encode() => jsonEncode(<String, dynamic>{
        'balance': balance,
        'id': _id,
        'open': open.map((t) => t.toJson()).toList(),
        'history': history.map((t) => t.toJson()).toList(),
      });

  void load(String? s) {
    if (s == null) return;
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      balance = toD(j['balance']);
      _id = (j['id'] as num).toInt();
      open
        ..clear()
        ..addAll((j['open'] as List<dynamic>)
            .map((e) => PaperTrade.fromJson(Map<String, dynamic>.from(e as Map))));
      history
        ..clear()
        ..addAll((j['history'] as List<dynamic>)
            .map((e) => PaperTrade.fromJson(Map<String, dynamic>.from(e as Map))));
    } catch (_) {}
  }

  void reset() {
    balance = startBalance;
    open.clear();
    history.clear();
    _onChange();
  }

  TradePlan buildPlan({
    required String symbol,
    required bool long,
    required double entry,
    required double slPct,
    required Market market,
    required double riskPct,
  }) {
    final slFrac = slPct / 100;
    final dir = long ? 1.0 : -1.0;
    final sl = entry * (1 - dir * slFrac);
    final tp1 = entry * (1 + dir * slFrac * 1.5);
    final tp2 = entry * (1 + dir * slFrac * 3);
    final risk = balance * riskPct / 100;
    var notional = risk / slFrac;
    double lev = 1.0;
    if (market == Market.futures) {
      lev = math.max(1.0, math.min(10.0, (1 / (2 * slFrac)).floorToDouble()));
      notional = math.min(notional, balance * 0.25 * lev);
    } else {
      notional = math.min(notional, balance * 0.25);
    }
    return TradePlan(
      symbol: symbol,
      long: long,
      entry: entry,
      sl: sl,
      tp1: tp1,
      tp2: tp2,
      leverage: lev,
      notional: notional,
      riskUsd: notional * slFrac,
    );
  }

  PaperTrade? openPlan(TradePlan p, Market m) {
    if (open.length >= 5) return null;
    if (open.any((t) => t.symbol == p.symbol)) return null;
    if (!p.long && m == Market.spot) return null;
    final t = PaperTrade(
      id: _id++,
      symbol: p.symbol,
      long: p.long,
      futures: m == Market.futures,
      entry: p.entry,
      notional: p.notional,
      leverage: p.leverage,
      sl: p.sl,
      tp1: p.tp1,
      tp2: p.tp2,
      openedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final fee = p.notional * m.fee;
    t.realized -= fee;
    balance -= fee;
    open.add(t);
    _onChange();
    return t;
  }

  /// Ouverture automatique sur alerte, uniquement si le flux BTC est aligne.
  void autoOpen(TokenData tk, bool up, Trend trend, Market m, double riskPct) {
    if (trend == Trend.unknown) {
      lastAutoMsg = '${tk.base} : flux BTC inconnu, ignore';
      return;
    }
    if (up && trend != Trend.bull) {
      lastAutoMsg = '${tk.base} : long refuse (BTC baissier)';
      return;
    }
    if (!up && trend != Trend.bear) {
      lastAutoMsg = '${tk.base} : short refuse (BTC haussier)';
      return;
    }
    if (!up && m == Market.spot) {
      lastAutoMsg = '${tk.base} : short impossible en SPOT';
      return;
    }
    final slPct = clampD(tk.rangePct * 0.2, 0.6, 6.0);
    final plan = buildPlan(
      symbol: tk.symbol,
      long: up,
      entry: tk.price,
      slPct: slPct,
      market: m,
      riskPct: riskPct,
    );
    final t = openPlan(plan, m);
    lastAutoMsg = t == null ? '${tk.base} : position non ouverte (limite)' : '${tk.base} : paper trade ouvert';
  }

  double _fee(PaperTrade t) => t.futures ? Market.futures.fee : Market.spot.fee;

  void _realize(PaperTrade t, double frac, double price) {
    final pnl = t.notional * frac * (price / t.entry - 1) * (t.long ? 1 : -1) -
        t.notional * frac * _fee(t);
    t.realized += pnl;
    balance += pnl;
  }

  void _close(PaperTrade t, double price, String status) {
    _realize(t, t.remaining, price);
    t.remaining = 0;
    t.exit = price;
    t.status = status;
    t.closedAt = DateTime.now().millisecondsSinceEpoch;
    open.remove(t);
    history.insert(0, t);
    if (history.length > 100) history.removeLast();
    _onChange();
  }

  void closeManual(PaperTrade t) {
    final p = _priceOf(t.symbol);
    if (p == null) return;
    _close(t, p, 'manual');
  }

  void onPrices() {
    for (final t in List<PaperTrade>.from(open)) {
      final p = _priceOf(t.symbol);
      if (p == null || p <= 0) continue;
      final hitSl = t.long ? p <= t.sl : p >= t.sl;
      if (hitSl) {
        _close(t, t.sl, t.tp1Hit ? 'be' : 'sl');
        continue;
      }
      if (!t.tp1Hit && (t.long ? p >= t.tp1 : p <= t.tp1)) {
        _realize(t, 0.5, t.tp1);
        t.remaining = 0.5;
        t.tp1Hit = true;
        t.sl = t.entry;
        _onChange();
      }
      if (t.tp1Hit && (t.long ? p >= t.tp2 : p <= t.tp2)) {
        _close(t, t.tp2, 'tp');
      }
    }
  }
}
