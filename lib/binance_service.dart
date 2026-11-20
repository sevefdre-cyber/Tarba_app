import 'dart:convert';
import 'package:http/http.dart' as http;
import 'indicators.dart';
import 'models.dart';

class BinanceService {
  BinanceService(this.market);
  final Market market;

  String get restBase =>
      market == Market.spot ? 'https://api.binance.com' : 'https://fapi.binance.com';
  String get prefix => market == Market.spot ? '/api/v3' : '/fapi/v1';

  // !ticker@arr a ete retire par Binance (2026) : on utilise !miniTicker@arr.
  String get wsUrl => market == Market.spot
      ? 'wss://stream.binance.com:9443/ws/!miniTicker@arr'
      : 'wss://fstream.binance.com/ws/!miniTicker@arr';

  Future<List<Map<String, dynamic>>> fetch24h() async {
    final r = await http
        .get(Uri.parse('$restBase$prefix/ticker/24hr'))
        .timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final j = jsonDecode(r.body) as List<dynamic>;
    return j.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Candle>> klines(String symbol, String interval, int limit) async {
    final uri =
        Uri.parse('$restBase$prefix/klines?symbol=$symbol&interval=$interval&limit=$limit');
    final r = await http.get(uri).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final j = jsonDecode(r.body) as List<dynamic>;
    return j.map((e) {
      final l = e as List<dynamic>;
      return Candle(
        (l[0] as num).toInt(),
        toD(l[1]),
        toD(l[2]),
        toD(l[3]),
        toD(l[4]),
        toD(l[5]),
        toD(l[7]),
      );
    }).toList();
  }
}
