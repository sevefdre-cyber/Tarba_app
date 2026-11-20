import 'package:flutter/material.dart';
import '../engine.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import 'pipeline_screen.dart';
import 'widgets.dart';

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (BuildContext context, Widget? _) {
        final list = engine.ranking;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: <Widget>[
                const Text(
                  'CRYPTO RADAR',
                  style: TextStyle(color: kGold, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Icon(Icons.circle, size: 10, color: engine.connected ? kGreen : kRed),
              ],
            ),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SegmentedButton<Market>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const <ButtonSegment<Market>>[
                    ButtonSegment<Market>(value: Market.spot, label: Text('SPOT')),
                    ButtonSegment<Market>(value: Market.futures, label: Text('FUTURES')),
                  ],
                  selected: <Market>{engine.market},
                  onSelectionChanged: (Set<Market> s) => engine.setMarket(s.first),
                ),
              ),
            ],
          ),
          body: Column(
            children: <Widget>[
              const _BtcBar(),
              const _SortBar(),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            engine.favoritesOnly ? 'Aucun favori. Appui long sur un jeton pour ajouter une etoile.' : engine.status,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: kMuted),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 90),
                        itemCount: list.length,
                        itemBuilder: (BuildContext context, int i) => _TokenCard(t: list[i]),
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showScanSheet(context),
            icon: const Icon(Icons.radar),
            label: const Text('SCAN'),
            backgroundColor: kGold,
            foregroundColor: Colors.black,
          ),
        );
      },
    );
  }
}

class _BtcBar extends StatelessWidget {
  const _BtcBar();

  @override
  Widget build(BuildContext context) {
    final tr = engine.btcTrend;
    final col = tr == Trend.bull ? kGreen : (tr == Trend.bear ? kRed : kMuted);
    final txt = tr == Trend.bull
        ? 'FLUX BTC HAUSSIER → LONG'
        : (tr == Trend.bear
            ? (engine.market == Market.futures ? 'FLUX BTC BAISSIER → SHORT' : 'FLUX BTC BAISSIER → ATTENTE (spot)')
            : 'FLUX BTC : INCONNU');
    final btc = engine.tokens['BTCUSDT'];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: col.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: col.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(txt, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 12))),
              if (btc != null)
                Text('BTC ${fmtPrice(btc.price)}  ${fmtPct2(btc.change24)}',
                    style: const TextStyle(fontSize: 11, color: kMuted)),
            ],
          ),
          Text(engine.btcInfo, style: const TextStyle(fontSize: 10, color: kMuted)),
        ],
      ),
    );
  }
}

class _SortBar extends StatelessWidget {
  const _SortBar();

  static const Map<SortKey, String> _labels = <SortKey, String>{
    SortKey.score: 'Score',
    SortKey.speed: 'Vitesse',
    SortKey.change: '% 24h',
    SortKey.volume: 'Volume',
    SortKey.volVar: 'Var. vol 1J',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: <Widget>[
          for (final e in _labels.entries)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(e.value, style: const TextStyle(fontSize: 12)),
                selected: engine.sortKey == e.key,
                onSelected: (bool _) => engine.setSort(e.key),
              ),
            ),
        ],
      ),
    );
  }
}

class _TokenCard extends StatelessWidget {
  const _TokenCard({required this.t});
  final TokenData t;

  @override
  Widget build(BuildContext context) {
    final up = t.change24 >= 0;
    final col = up ? kGreen : kRed;
    final hot = t.score >= engine.sens.alertScore;
    final fav = engine.favorites.contains(t.symbol);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (BuildContext _) => PipelineScreen(symbol: t.symbol)),
      ),
      onLongPress: () => engine.toggleFavorite(t.symbol),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hot ? kRed.withOpacity(0.7) : kSurface2),
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: 34,
                  child: Text('#${t.rank}', style: const TextStyle(color: kMuted, fontSize: 11)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(t.base, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          if (fav) const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.star, size: 14, color: kGold),
                          ),
                        ],
                      ),
                      Text(
                        'Vol ${fmtVol(t.quoteVol24)} · ${t.speed} · ↑${t.upEvents} ↓${t.downEvents}',
                        style: const TextStyle(fontSize: 10, color: kMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(fmtPrice(t.price), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(fmtPct2(t.change24), style: TextStyle(color: col, fontSize: 12)),
                  ],
                ),
                const SizedBox(width: 10),
                ScoreBadge(score: t.score, direction: t.direction, hot: hot),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                for (final p in kPeriods)
                  Expanded(
                    child: VolumeCandle(
                      label: periodLabel(p),
                      value: t.volVar[p] ?? 0.0,
                      ready: t.klinesLoaded && t.volVar.containsKey(p),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void showScanSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSurface,
    builder: (BuildContext ctx) {
      return ListenableBuilder(
        listenable: engine,
        builder: (BuildContext ctx, Widget? _) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('SCAN · parametres pre-configures',
                      style: TextStyle(color: kGold, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  for (var i = 0; i < kPresets.length; i++)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        engine.presetIndex == i ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: engine.presetIndex == i ? kGold : kMuted,
                      ),
                      title: Text(kPresets[i].name),
                      subtitle: Text(kPresets[i].desc, style: const TextStyle(fontSize: 11)),
                      onTap: () => engine.applyPreset(i),
                    ),
                  const Divider(),
                  const Text('Sensibilite du classement', style: TextStyle(fontSize: 12, color: kMuted)),
                  Wrap(
                    spacing: 6,
                    children: <Widget>[
                      for (final s in Sensitivity.values)
                        ChoiceChip(
                          label: Text(s.label),
                          selected: engine.sens == s,
                          onSelected: (bool _) => engine.setSensitivity(s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Nombre de jetons scannes', style: TextStyle(fontSize: 12, color: kMuted)),
                  Wrap(
                    spacing: 6,
                    children: <Widget>[
                      for (final n in const <int>[30, 50, 100, 150, 200])
                        ChoiceChip(
                          label: Text('Top $n'),
                          selected: engine.topN == n,
                          onSelected: (bool _) => engine.setTopN(n),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Favoris uniquement'),
                    subtitle: Text('${engine.favorites.length} jeton(s) en etoile (appui long dans le classement)',
                        style: const TextStyle(fontSize: 11)),
                    value: engine.favoritesOnly,
                    onChanged: engine.setFavoritesOnly,
                  ),
                  Text(
                    'Alerte quand ≥ ${engine.sens.minEvents} mouvements de ${engine.sens.step}% dans le meme sens '
                    'et score ≥ ${engine.sens.alertScore.round()}.',
                    style: const TextStyle(fontSize: 11, color: kMuted),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
