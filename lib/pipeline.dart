import 'dart:math' as math;
import 'binance_service.dart';
import 'engine.dart';
import 'format.dart';
import 'indicators.dart';
import 'models.dart';
import 'simulator.dart';

class DeskReport {
  DeskReport(this.title, this.verdict, this.lines, {this.ok = true});
  final String title;
  final String verdict;
  final List<String> lines;
  final bool ok;
}

class PipelineResult {
  PipelineResult(this.reports, this.plan, this.execute);
  final List<DeskReport> reports;
  final TradePlan? plan;
  final bool execute;
}

class BtStats {
  int trades = 0;
  int wins = 0;
  double grossWin = 0;
  double grossLoss = 0;
  double totalR = 0;
  double maxDd = 0;
  double get profitFactor => grossLoss > 0 ? grossWin / grossLoss : (grossWin > 0 ? 99.0 : 0.0);
  double get winRate => trades > 0 ? wins / trades * 100 : 0;
}

/// Backtest simplifie : retournement Supertrend + EMA20/50, SL 1.5 ATR, TP 1.5R, sortie max 48 bougies.
BtStats backtest(List<Candle> c, double feeRate, bool allowShort) {
  final closes = c.map((x) => x.c).toList();
  final e20 = ema(closes, 20);
  final e50 = ema(closes, 50);
  final st = supertrend(c);
  final a = atr(c, 14);
  final s = BtStats();
  double eq = 0;
  double peak = 0;
  var i = 60;
  while (i < c.length - 1) {
    final flipUp = st[i] == 1 && st[i - 1] == -1 && e20[i] > e50[i];
    final flipDn = allowShort && st[i] == -1 && st[i - 1] == 1 && e20[i] < e50[i];
    if (!flipUp && !flipDn) {
      i++;
      continue;
    }
    final long = flipUp;
    final entry = c[i].c;
    final risk = a[i] * 1.5;
    if (risk <= 0) {
      i++;
      continue;
    }
    final sl = long ? entry - risk : entry + risk;
    final tp = long ? entry + risk * 1.5 : entry - risk * 1.5;
    final last = math.min(c.length - 1, i + 48);
    var j = i + 1;
    var done = false;
    double r = 0;
    for (; j <= last; j++) {
      final hitSl = long ? c[j].l <= sl : c[j].h >= sl;
      final hitTp = long ? c[j].h >= tp : c[j].l <= tp;
      if (hitSl) {
        r = -1;
        done = true;
        break;
      }
      if (hitTp) {
        r = 1.5;
        done = true;
        break;
      }
    }
    if (!done) {
      final exitP = c[last].c;
      r = (long ? exitP - entry : entry - exitP) / risk;
    }
    r -= feeRate * 2 * entry / risk;
    s.trades++;
    if (r > 0) {
      s.wins++;
      s.grossWin += r;
    } else {
      s.grossLoss += -r;
    }
    s.totalR += r;
    eq += r;
    peak = math.max(peak, eq);
    s.maxDd = math.max(s.maxDd, peak - eq);
    i = math.min(j, last) + 1;
  }
  return s;
}

Future<PipelineResult> runPipeline(RadarEngine e, String symbol) async {
  final t = e.tokens[symbol];
  if (t == null) {
    return PipelineResult(
        [DeskReport('Radar', 'ERREUR', ['Jeton introuvable'], ok: false)], null, false);
  }
  final reports = <DeskReport>[];

  // 1 - Radar de detection + rapport de detection
  reports.add(DeskReport(
    '1 · Radar de detection',
    'Score ${t.score.round()}/100',
    [
      'Seuil d alerte (${e.sens.label}) : ${e.sens.alertScore.round()}',
      'Direction : ${t.direction == 'up' ? 'HAUT ↑' : (t.direction == 'down' ? 'BAS ↓' : 'neutre')}',
      'Vitesse : ${t.speed} (${fmtPct2(t.move1m)} sur 1 min)',
      'Variation 5 min : ${fmtPct2(t.move5m)}',
      'Mouvements (10 min) : ↑${t.upEvents}  ↓${t.downEvents}  (pas ${e.sens.step}%)',
      'Flux de volume : x${t.volRatio.toStringAsFixed(2)} vs moyenne',
    ],
  ));

  // Donnees 1h
  List<Candle> c;
  try {
    c = await BinanceService(e.market).klines(symbol, '1h', 1000);
  } catch (err) {
    reports.add(DeskReport('2 · Bureau analyse 1', 'ERREUR',
        ['Impossible de charger les bougies 1h : $err'], ok: false));
    return PipelineResult(reports, null, false);
  }
  if (c.length < 120) {
    reports.add(DeskReport('2 · Bureau analyse 1', 'DONNEES INSUFFISANTES',
        ['Seulement ${c.length} bougies 1h disponibles'], ok: false));
    return PipelineResult(reports, null, false);
  }

  // 2 - Bureau analyse 1 + rapport
  final closes = c.map((x) => x.c).toList();
  final e20 = ema(closes, 20);
  final e50 = ema(closes, 50);
  final r = rsi(closes);
  final h = macdHist(closes);
  final st = supertrend(c);
  final a = atr(c, 14);
  final i = c.length - 1;

  var lp = 0;
  var sp = 0;
  if (e20[i] > e50[i]) {
    lp++;
  } else {
    sp++;
  }
  if (st[i] == 1) {
    lp++;
  } else {
    sp++;
  }
  if (h[i] > 0) {
    lp++;
  } else {
    sp++;
  }
  if (r[i] > 50 && r[i] < 75) {
    lp++;
  } else if (r[i] < 50 && r[i] > 25) {
    sp++;
  }
  if (t.direction == 'up') {
    lp++;
  } else if (t.direction == 'down') {
    sp++;
  }
  bool? side;
  if (lp >= 3 && lp > sp) {
    side = true;
  } else if (sp >= 3 && sp > lp) {
    side = false;
  }
  final totalEv = t.upEvents + t.downEvents;
  final continuity = totalEv >= 2 ? t.dirEvents / totalEv * 100 : 0.0;
  final instab = totalEv >= 3 ? t.flips / (totalEv - 1) * 100 : 0.0;
  String pv(int p) => t.klinesLoaded ? fmtPct(t.volVar[p] ?? 0.0) : 'n/d';

  reports.add(DeskReport(
    '2 · Bureau analyse 1',
    side == null ? 'Pas de biais clair' : (side ? 'Biais LONG ($lp/5)' : 'Biais SHORT ($sp/5)'),
    [
      'Rang volume 24h : #${t.rank}  ·  vol ${fmtVol(t.quoteVol24)} USDT',
      'Variation de volume : 1J ${pv(1)} · 1S ${pv(7)} · 1M ${pv(30)} · 90J ${pv(90)} · 180J ${pv(180)}',
      'RSI(14) 1h : ${r[i].toStringAsFixed(1)}',
      'MACD histogramme 1h : ${h[i] >= 0 ? 'positif' : 'negatif'} (${h[i].toStringAsExponential(2)})',
      'EMA20 ${e20[i] > e50[i] ? '>' : '<'} EMA50 (1h)',
      'Supertrend 1h : ${st[i] == 1 ? 'haussier ↑' : 'baissier ↓'}',
      'Continuite des mouvements : ${continuity.toStringAsFixed(0)} %',
      'Instabilite (changements de sens) : ${instab.toStringAsFixed(0)} %',
      'Flux BTC : ${e.btcTrend == Trend.bull ? 'HAUSSIER' : (e.btcTrend == Trend.bear ? 'BAISSIER' : 'inconnu')} - ${e.btcInfo}',
    ],
  ));

  // 3 - Bureau de backtest + rapport
  final bt = backtest(c, e.market.fee, e.market == Market.futures);
  final btOk = bt.trades >= 5 && bt.profitFactor >= 1.0;
  reports.add(DeskReport(
    '3 · Bureau de backtest',
    btOk ? 'Strategie validee' : 'Strategie non validee',
    [
      'Donnees : ${c.length} bougies 1h (~${(c.length / 24).round()} jours)',
      'Regle : retournement Supertrend + EMA20/50, SL 1,5 ATR, TP 1,5 R, sortie max 48 h',
      'Trades : ${bt.trades}  ·  gagnants : ${bt.winRate.toStringAsFixed(0)} %',
      'Facteur de profit : ${bt.profitFactor.toStringAsFixed(2)}',
      'Resultat cumule : ${bt.totalR.toStringAsFixed(1)} R  ·  drawdown max : ${bt.maxDd.toStringAsFixed(1)} R',
      'Frais inclus (${(e.market.fee * 100).toStringAsFixed(2)} % par cote). Echantillon limite : a prendre comme indice, pas comme preuve.',
    ],
    ok: btOk,
  ));

  // 4 - Bureau analyse 2 + rapport
  String? reject;
  if (side == null) {
    reject = 'Aucun biais directionnel clair';
  } else if (e.btcTrend == Trend.unknown) {
    reject = 'Flux BTC indisponible';
  } else if (e.btcTrend == Trend.bull && !side) {
    reject = 'Flux BTC haussier : short interdit';
  } else if (e.btcTrend == Trend.bear && side) {
    reject = 'Flux BTC baissier : long interdit';
  } else if (!side && e.market == Market.spot) {
    reject = 'Short impossible en SPOT (passer en FUTURES)';
  }
  TradePlan? plan;
  if (reject == null && side != null && t.price > 0) {
    final slPct = 1.5 * a[i] / t.price * 100;
    plan = e.sim.buildPlan(
      symbol: symbol,
      long: side,
      entry: t.price,
      slPct: slPct,
      market: e.market,
      riskPct: e.riskPct,
    );
  }
  if (plan != null) {
    final p = plan;
    reports.add(DeskReport(
      '4 · Bureau analyse 2',
      p.long ? 'Plan LONG' : 'Plan SHORT',
      [
        'Marche : ${e.market.label}  ·  position ${p.long ? 'LONG' : 'SHORT'}',
        'Entree : ${fmtPrice(p.entry)} (prix du marche)',
        'Stop loss : ${fmtPrice(p.sl)}  (1,5 ATR)',
        'TP1 : ${fmtPrice(p.tp1)} (1,5 R, 50 % puis SL a l entree)  ·  TP2 : ${fmtPrice(p.tp2)} (3 R)',
        'Levier : x${p.leverage.toStringAsFixed(0)}${e.market == Market.spot ? ' (spot)' : ''}',
        'Taille : ${p.notional.toStringAsFixed(0)} USDT  ·  risque : ${p.riskUsd.toStringAsFixed(2)} USDT (${e.riskPct} % du capital virtuel)',
      ],
    ));
  } else {
    reports.add(DeskReport('4 · Bureau analyse 2', 'Pas de plan', [reject ?? 'Prix indisponible'], ok: false));
  }

  // 5 - Bureau de live test + rapport
  final live = e.sim.open.where((x) => x.symbol == symbol).toList();
  if (live.isNotEmpty) {
    final x = live.first;
    final pnl = x.unrealized(t.price) + x.realized;
    reports.add(DeskReport('5 · Bureau de live test', 'Paper trade en cours', [
      '${x.long ? 'LONG' : 'SHORT'} ouvert a ${fmtPrice(x.entry)}',
      'PnL en direct : ${fmtUsd(pnl)} USDT',
      'Statut : TP1 ${x.tp1Hit ? 'atteint' : 'non atteint'}',
    ]));
  } else {
    reports.add(DeskReport('5 · Bureau de live test', 'En attente', [
      'Aucun paper trade actif sur ce jeton.',
      'Le test en direct s effectue dans le simulateur (prix reels, argent virtuel).',
    ], ok: false));
  }

  // 6 - Bureau d execution
  final rr = plan == null ? 0.0 : (plan.tp1 - plan.entry).abs() / (plan.entry - plan.sl).abs();
  final checks = <String, bool>{
    'Score radar >= 80 % du seuil (${(e.sens.alertScore * 0.8).round()})': t.score >= e.sens.alertScore * 0.8,
    'Biais clair et aligne sur le flux BTC': reject == null,
    'Backtest : >= 5 trades et facteur de profit >= 1': btOk,
    'Ratio gain/risque >= 1,5': rr >= 1.499,
  };
  final execute = checks.values.every((v) => v) && plan != null;
  reports.add(DeskReport(
    '6 · Bureau d execution',
    execute ? 'EXECUTER (paper)' : 'REJETER',
    [
      for (final en in checks.entries) '${en.value ? '✔' : '✘'} ${en.key}',
      'Execution reelle sur Binance : non incluse dans cette version.',
    ],
    ok: execute,
  ));

  return PipelineResult(reports, plan, execute);
}
