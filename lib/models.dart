import 'dart:math' as math;

double toD(dynamic x) => x is num ? x.toDouble() : (double.tryParse('$x') ?? 0.0);

double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

enum Market { spot, futures }

extension MarketX on Market {
  String get label => this == Market.spot ? 'SPOT' : 'FUTURES';
  double get fee => this == Market.spot ? 0.001 : 0.0004;
}

enum Sensitivity { low, medium, high, ultra }

extension SensitivityX on Sensitivity {
  String get label => switch (this) {
        Sensitivity.low => 'FAIBLE',
        Sensitivity.medium => 'MOYENNE',
        Sensitivity.high => 'HAUTE',
        Sensitivity.ultra => 'ULTRA',
      };

  /// Pas de mouvement (en %) : un "mouvement" est compte a chaque fois que le prix bouge de ce pas.
  double get step => switch (this) {
        Sensitivity.low => 0.30,
        Sensitivity.medium => 0.20,
        Sensitivity.high => 0.12,
        Sensitivity.ultra => 0.07,
      };

  /// Nombre minimal de mouvements dans le meme sens (fenetre 10 min).
  int get minEvents => switch (this) {
        Sensitivity.low => 5,
        Sensitivity.medium => 4,
        Sensitivity.high => 3,
        Sensitivity.ultra => 3,
      };

  /// Score minimal (0-100) pour declencher l'alerte.
  double get alertScore => switch (this) {
        Sensitivity.low => 75.0,
        Sensitivity.medium => 65.0,
        Sensitivity.high => 55.0,
        Sensitivity.ultra => 45.0,
      };
}

enum Trend { bull, bear, unknown }

enum SortKey { score, change, volume, volVar, speed }

class ScanPreset {
  const ScanPreset(this.name, this.desc, this.sens, this.topN, this.favOnly);
  final String name;
  final String desc;
  final Sensitivity sens;
  final int topN;
  final bool favOnly;
}

const List<ScanPreset> kPresets = [
  ScanPreset('Scalp ultra-rapide', 'Top 50 - detection maximale', Sensitivity.ultra, 50, false),
  ScanPreset('Equilibre', 'Top 100 - sensibilite moyenne', Sensitivity.medium, 100, false),
  ScanPreset('Swing calme', 'Top 200 - alertes rares et solides', Sensitivity.low, 200, false),
  ScanPreset('Ma watchlist', 'Jetons favoris (etoile) - haute sensibilite', Sensitivity.high, 100, true),
];

const List<int> kPeriods = [1, 7, 30, 90, 180];

String periodLabel(int p) => switch (p) {
      1 => '1J',
      7 => '1S',
      30 => '1M',
      90 => '90J',
      _ => '180J',
    };

class Sample {
  Sample(this.t, this.price, this.quoteVol);
  final int t;
  final double price;
  final double quoteVol;
}

class MoveEvent {
  MoveEvent(this.t, this.up);
  final int t;
  final bool up;
}

class TokenData {
  TokenData(this.symbol)
      : base = symbol.endsWith('USDT') ? symbol.substring(0, symbol.length - 4) : symbol;

  final String symbol;
  final String base;

  double price = 0;
  double prevPrice = 0;
  double open24 = 0;
  double high24 = 0;
  double low24 = 0;
  double quoteVol24 = 0;

  double get change24 => open24 > 0 ? (price / open24 - 1) * 100 : 0;
  double get rangePct => price > 0 ? (high24 - low24) / price * 100 : 0;

  // Variation de volume par periode (jours) : % vs periode precedente.
  final Map<int, double> volVar = {};
  List<double> dailyQuoteVol = [];
  bool klinesLoaded = false;

  // Detecteur
  final List<Sample> samples = [];
  final List<MoveEvent> events = [];
  double anchor = 0;
  double move1m = 0;
  double move5m = 0;
  double volRatio = 1;
  int upEvents = 0;
  int downEvents = 0;
  int flips = 0;
  double score = 0;
  String direction = 'neutral';
  String speed = 'slow';
  int lastAlertMs = 0;

  int rank = 0;

  int get dirEvents => math.max(upEvents, downEvents);

  void updateVolVar() {
    final v = dailyQuoteVol;
    final n = v.length;
    if (n < 2) return;
    double sumRange(int from, int to) {
      double s = 0;
      for (var i = from; i < to; i++) {
        s += (i == n - 1) ? quoteVol24 : v[i];
      }
      return s;
    }

    for (final p in kPeriods) {
      final curFrom = n - p;
      if (curFrom < 1) {
        volVar[p] = 0;
        continue;
      }
      final prevFrom = math.max(0, curFrom - p);
      final cur = sumRange(curFrom, n) / p;
      final prevCount = curFrom - prevFrom;
      final prev = sumRange(prevFrom, curFrom) / prevCount;
      volVar[p] = prev > 0 ? (cur / prev - 1) * 100 : 0;
    }
  }
}

class AlertItem {
  AlertItem({
    required this.symbol,
    required this.base,
    required this.up,
    required this.score,
    required this.move5m,
    required this.events,
    required this.price,
    required this.time,
    required this.title,
    required this.body,
  });
  final String symbol;
  final String base;
  final bool up;
  final double score;
  final double move5m;
  final int events;
  final double price;
  final int time;
  final String title;
  final String body;
}
