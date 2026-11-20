import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'binance_service.dart';
import 'indicators.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'simulator.dart';

final RadarEngine engine = RadarEngine();

class RadarEngine extends ChangeNotifier {
  RadarEngine() {
    sim = Simulator((s) => tokens[s]?.price, _onSimChange);
  }

  // Reglages
  Market market = Market.spot;
  Sensitivity sens = Sensitivity.medium;
  int topN = 100;
  SortKey sortKey = SortKey.score;
  bool notifOn = true;
  bool keepAlive = false;
  bool autoTrade = false;
  bool favoritesOnly = false;
  double riskPct = 1.0;
  int presetIndex = 1;
  Set<String> favorites = <String>{};

  // Etat
  final Map<String, TokenData> tokens = <String, TokenData>{};
  List<TokenData> ranking = <TokenData>[];
  final List<AlertItem> alerts = <AlertItem>[];
  Trend btcTrend = Trend.unknown;
  String btcInfo = 'Flux BTC : calcul en cours...';
  bool connected = false;
  String status = 'Initialisation...';
  late final Simulator sim;

  SharedPreferences? _p;
  BinanceService _api = BinanceService(Market.spot);
  Timer? _loop;
  Timer? _klineTimer;
  Timer? _btcTimer;
  StreamSubscription<dynamic>? _wsSub;
  WebSocketChannel? _channel;
  int _gen = 0;
  bool _reconnectPending = false;

  static const Set<String> _stables = <String>{
    'USDC', 'FDUSD', 'TUSD', 'BUSD', 'USDP', 'DAI', 'AEUR', 'EUR', 'USDE', 'XUSD',
    'PYUSD', 'USD1', 'UST', 'USDS', 'BFUSD',
  };

  bool _ok(String s) {
    if (!s.endsWith('USDT') || s.contains('_')) return false;
    final b = s.substring(0, s.length - 4);
    return b.isNotEmpty && !_stables.contains(b);
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _p = p;
    market = Market.values[_ci(p.getInt('market') ?? 0, 0, 1)];
    sens = Sensitivity.values[_ci(p.getInt('sens') ?? 1, 0, 3)];
    topN = p.getInt('topN') ?? 100;
    notifOn = p.getBool('notifOn') ?? true;
    keepAlive = p.getBool('keepAlive') ?? false;
    autoTrade = p.getBool('autoTrade') ?? false;
    favoritesOnly = p.getBool('favOnly') ?? false;
    riskPct = p.getDouble('riskPct') ?? 1.0;
    presetIndex = _ci(p.getInt('preset') ?? 1, 0, kPresets.length - 1);
    favorites = (p.getStringList('fav') ?? <String>[]).toSet();
    sim.load(p.getString('sim'));
    NativeBridge.requestPermission();
    if (keepAlive) NativeBridge.startService();
    unawaited(start());
  }

  int _ci(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

  void _save() {
    final p = _p;
    if (p == null) return;
    p.setInt('market', market.index);
    p.setInt('sens', sens.index);
    p.setInt('topN', topN);
    p.setBool('notifOn', notifOn);
    p.setBool('keepAlive', keepAlive);
    p.setBool('autoTrade', autoTrade);
    p.setBool('favOnly', favoritesOnly);
    p.setDouble('riskPct', riskPct);
    p.setInt('preset', presetIndex);
    p.setStringList('fav', favorites.toList());
  }

  void _onSimChange() {
    _p?.setString('sim', sim.encode());
  }

  // ---------------------------------------------------------------- reseau

  void _stop() {
    _loop?.cancel();
    _klineTimer?.cancel();
    _btcTimer?.cancel();
    _wsSub?.cancel();
    _wsSub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _reconnectPending = false;
  }

  Future<void> start() async {
    _gen++;
    final gen = _gen;
    _stop();
    _api = BinanceService(market);
    tokens.clear();
    ranking = <TokenData>[];
    connected = false;
    btcTrend = Trend.unknown;
    status = 'Chargement du marche ${market.label}...';
    notifyListeners();
    try {
      final snap = await _api.fetch24h();
      if (gen != _gen) return;
      for (final m in snap) {
        final s = m['symbol'] as String;
        _applyTick(
          s,
          toD(m['lastPrice']),
          toD(m['openPrice']),
          toD(m['highPrice']),
          toD(m['lowPrice']),
          toD(m['quoteVolume']),
        );
      }
      status = 'Marche charge (${tokens.length} paires USDT)';
    } catch (e) {
      status = 'Erreur reseau : $e';
    }
    if (gen != _gen) return;
    _connectWs(gen);
    _loop = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    unawaited(_loadKlines(gen, true));
    _klineTimer = Timer.periodic(const Duration(minutes: 30), (_) => _loadKlines(_gen, true));
    unawaited(_refreshBtc(gen));
    _btcTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refreshBtc(_gen));
    notifyListeners();
  }

  void _connectWs(int gen) {
    if (gen != _gen) return;
    _reconnectPending = false;
    try {
      _wsSub?.cancel();
      final ch = WebSocketChannel.connect(Uri.parse(_api.wsUrl));
      _channel = ch;
      _wsSub = ch.stream.listen(
        (dynamic data) {
          connected = true;
          _onWs(data);
        },
        onError: (Object _) => _reconnect(gen),
        onDone: () => _reconnect(gen),
        cancelOnError: true,
      );
    } catch (_) {
      _reconnect(gen);
    }
  }

  void _reconnect(int gen) {
    connected = false;
    if (gen != _gen || _reconnectPending) return;
    _reconnectPending = true;
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (gen == _gen) _connectWs(gen);
    });
  }

  void _onWs(dynamic data) {
    try {
      final j = jsonDecode(data as String);
      if (j is List<dynamic>) {
        for (final m in j) {
          final mm = m as Map<String, dynamic>;
          _applyTick(
            mm['s'] as String,
            toD(mm['c']),
            toD(mm['o']),
            toD(mm['h']),
            toD(mm['l']),
            toD(mm['q']),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _loadKlines(int gen, bool force) async {
    final all = tokens.values.where((t) => t.price > 0).toList()
      ..sort((a, b) => b.quoteVol24.compareTo(a.quoteVol24));
    final set = <TokenData>{...all.take(topN)};
    for (final f in favorites) {
      final t = tokens[f];
      if (t != null) set.add(t);
    }
    final list = set.where((t) => force || !t.klinesLoaded).toList();
    for (var i = 0; i < list.length; i += 6) {
      if (gen != _gen) return;
      final batch = list.sublist(i, math.min(i + 6, list.length));
      await Future.wait(batch.map((t) async {
        try {
          final k = await _api.klines(t.symbol, '1d', 361);
          t.dailyQuoteVol = k.map((c) => c.qv).toList();
          t.klinesLoaded = true;
        } catch (_) {}
      }));
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _refreshBtc(int gen) async {
    try {
      final h1 = await _api.klines('BTCUSDT', '1h', 200);
      final h4 = await _api.klines('BTCUSDT', '4h', 200);
      if (gen != _gen) return;
      final c1 = h1.map((c) => c.c).toList();
      final c4 = h4.map((c) => c.c).toList();
      final a1 = ema(c1, 20).last > ema(c1, 50).last;
      final a4 = ema(c4, 20).last > ema(c4, 50).last;
      final st = supertrend(h1).last == 1;
      final bull = (a1 ? 1 : 0) + (a4 ? 1 : 0) + (st ? 1 : 0);
      if (bull == 3) {
        btcTrend = Trend.bull;
      } else if (bull == 0) {
        btcTrend = Trend.bear;
      } else if (btcTrend == Trend.unknown) {
        btcTrend = bull >= 2 ? Trend.bull : Trend.bear;
      }
      btcInfo = 'EMA 1h ${a1 ? "↑" : "↓"} · EMA 4h ${a4 ? "↑" : "↓"} · Supertrend 1h ${st ? "↑" : "↓"}';
    } catch (_) {}
  }

  // ------------------------------------------------------------- detecteur

  void _applyTick(String s, double c, double o, double h, double l, double q) {
    if (c <= 0 || !_ok(s)) return;
    final t = tokens.putIfAbsent(s, () => TokenData(s));
    t.prevPrice = t.price == 0 ? c : t.price;
    t.price = c;
    if (o > 0) t.open24 = o;
    if (h > 0) t.high24 = h;
    if (l > 0) t.low24 = l;
    if (q > 0) t.quoteVol24 = q;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (t.samples.isEmpty || now - t.samples.last.t >= 2000) {
      t.samples.add(Sample(now, c, t.quoteVol24));
      final cut = now - 900000;
      var k = 0;
      while (k < t.samples.length && t.samples[k].t < cut) {
        k++;
      }
      if (k > 0) t.samples.removeRange(0, k);
    }
    if (t.anchor <= 0) {
      t.anchor = c;
    } else {
      final d = (c / t.anchor - 1) * 100;
      if (d.abs() >= sens.step) {
        t.events.add(MoveEvent(now, d > 0));
        t.anchor = c;
      }
    }
  }

  double _moveSince(TokenData t, int now, int ms) {
    final cut = now - ms;
    for (final s in t.samples) {
      if (s.t >= cut) {
        if (now - s.t < ms * 0.5) return 0;
        return s.price > 0 ? (t.price / s.price - 1) * 100 : 0;
      }
    }
    return 0;
  }

  double _volRatio(TokenData t, int now) {
    final cut = now - 300000;
    for (final s in t.samples) {
      if (s.t >= cut) {
        final span = now - s.t;
        if (span < 150000) return 1;
        final delta = t.quoteVol24 - s.quoteVol;
        final expected = t.quoteVol24 / 86400000.0 * span;
        if (expected <= 0) return 1;
        return clampD(delta / expected, 0, 10);
      }
    }
    return 1;
  }

  void _recompute(TokenData t, int now) {
    t.events.removeWhere((e) => now - e.t > 600000);
    var up = 0;
    var down = 0;
    var flips = 0;
    bool? last;
    for (final e in t.events) {
      if (e.up) {
        up++;
      } else {
        down++;
      }
      if (last != null && last != e.up) flips++;
      last = e.up;
    }
    t.upEvents = up;
    t.downEvents = down;
    t.flips = flips;
    t.move1m = _moveSince(t, now, 60000);
    t.move5m = _moveSince(t, now, 300000);
    t.volRatio = _volRatio(t, now);

    final total = up + down;
    final dirEv = math.max(up, down);
    final continuity = total >= 2 ? dirEv / total : 0.0;
    final step = sens.step;
    final s1 = math.min(40.0, dirEv / sens.minEvents * 25);
    final s2 = math.min(25.0, t.move5m.abs() / (step * 4) * 25);
    final s3 = math.min(20.0, math.max(0.0, t.volRatio - 1) * 10);
    final s4 = continuity * 15;
    t.score = math.min(100.0, s1 + s2 + s3 + s4);

    if (up > down) {
      t.direction = 'up';
    } else if (down > up) {
      t.direction = 'down';
    } else {
      t.direction = t.move5m > 0 ? 'up' : (t.move5m < 0 ? 'down' : 'neutral');
    }
    final sp = t.move1m.abs() / step;
    t.speed = sp >= 3 ? 'explosive' : (sp >= 1.5 ? 'rapide' : (sp >= 0.5 ? 'normale' : 'lente'));
  }

  void _tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final all = tokens.values.where((t) => t.price > 0).toList()
      ..sort((a, b) => b.quoteVol24.compareTo(a.quoteVol24));
    final pool = favoritesOnly
        ? all.where((t) => favorites.contains(t.symbol)).toList()
        : all.take(topN).toList();
    for (final t in pool) {
      _recompute(t, now);
      t.updateVolVar();
    }
    _checkAlerts(pool, now);
    _sortPool(pool);
    ranking = pool;
    sim.onPrices();
    notifyListeners();
  }

  void _checkAlerts(List<TokenData> pool, int now) {
    for (final t in pool) {
      if (t.dirEvents >= sens.minEvents &&
          t.score >= sens.alertScore &&
          now - t.lastAlertMs > 900000) {
        _fire(t, now);
      }
    }
  }

  void _fire(TokenData t, int now) {
    t.lastAlertMs = now;
    final up = t.direction == 'up';
    final title = up
        ? '🚀 ${t.base} se prepare a exploser ↑'
        : '⚠️ ${t.base} se prepare a chuter ↓';
    final body = 'Score ${t.score.round()} · ${t.move5m.toStringAsFixed(2)}% en 5 min · '
        '${t.dirEvents} mouvements · ${t.price}';
    alerts.insert(
      0,
      AlertItem(
        symbol: t.symbol,
        base: t.base,
        up: up,
        score: t.score,
        move5m: t.move5m,
        events: t.dirEvents,
        price: t.price,
        time: now,
        title: title,
        body: body,
      ),
    );
    if (alerts.length > 50) alerts.removeLast();
    if (notifOn) NativeBridge.notify(title, body);
    if (autoTrade) sim.autoOpen(t, up, btcTrend, market, riskPct);
  }

  void _sortPool(List<TokenData> pool) {
    int cmp(TokenData a, TokenData b) {
      switch (sortKey) {
        case SortKey.score:
          return b.score.compareTo(a.score);
        case SortKey.change:
          return b.change24.compareTo(a.change24);
        case SortKey.volume:
          return b.quoteVol24.compareTo(a.quoteVol24);
        case SortKey.volVar:
          return (b.volVar[1] ?? 0.0).compareTo(a.volVar[1] ?? 0.0);
        case SortKey.speed:
          return b.move1m.abs().compareTo(a.move1m.abs());
      }
    }

    pool.sort((a, b) {
      final c = cmp(a, b);
      return c != 0 ? c : b.quoteVol24.compareTo(a.quoteVol24);
    });
    for (var i = 0; i < pool.length; i++) {
      pool[i].rank = i + 1;
    }
  }

  // ---------------------------------------------------------------- actions

  void _resetDetector() {
    for (final t in tokens.values) {
      t.events.clear();
      t.anchor = 0;
      t.score = 0;
    }
  }

  void setMarket(Market m) {
    if (m == market) return;
    market = m;
    _save();
    unawaited(start());
  }

  void setSensitivity(Sensitivity s) {
    sens = s;
    _resetDetector();
    _save();
    notifyListeners();
  }

  void setTopN(int n) {
    topN = n;
    _save();
    unawaited(_loadKlines(_gen, false));
    notifyListeners();
  }

  void setSort(SortKey k) {
    sortKey = k;
    notifyListeners();
  }

  void setFavoritesOnly(bool v) {
    favoritesOnly = v;
    _save();
    notifyListeners();
  }

  void applyPreset(int i) {
    final p = kPresets[i];
    presetIndex = i;
    sens = p.sens;
    topN = p.topN;
    favoritesOnly = p.favOnly;
    _resetDetector();
    _save();
    unawaited(_loadKlines(_gen, false));
    notifyListeners();
  }

  void toggleFavorite(String symbol) {
    if (favorites.contains(symbol)) {
      favorites.remove(symbol);
    } else {
      favorites.add(symbol);
      unawaited(_loadKlines(_gen, false));
    }
    _save();
    notifyListeners();
  }

  void setNotif(bool v) {
    notifOn = v;
    if (v) NativeBridge.requestPermission();
    _save();
    notifyListeners();
  }

  void setKeepAlive(bool v) {
    keepAlive = v;
    if (v) {
      NativeBridge.requestPermission();
      NativeBridge.startService();
    } else {
      NativeBridge.stopService();
    }
    _save();
    notifyListeners();
  }

  void setAutoTrade(bool v) {
    autoTrade = v;
    _save();
    notifyListeners();
  }

  void setRisk(double v) {
    riskPct = v;
    _save();
    notifyListeners();
  }

  void resetSim() {
    sim.reset();
    notifyListeners();
  }

  void testNotification() {
    NativeBridge.notify('Crypto Radar', 'Test de notification : tout fonctionne ✅');
  }
}
