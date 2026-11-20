import 'package:flutter/material.dart';
import '../engine.dart';
import '../pipeline.dart';
import '../theme.dart';

class PipelineScreen extends StatefulWidget {
  const PipelineScreen({super.key, required this.symbol});
  final String symbol;

  @override
  State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen> {
  late Future<PipelineResult> _f;

  @override
  void initState() {
    super.initState();
    _f = runPipeline(engine, widget.symbol);
  }

  void _refresh() {
    setState(() {
      _f = runPipeline(engine, widget.symbol);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.symbol} · bureaux'),
        actions: <Widget>[IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh)],
      ),
      body: FutureBuilder<PipelineResult>(
        future: _f,
        builder: (BuildContext context, AsyncSnapshot<PipelineResult> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}'));
          }
          final r = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(10),
            children: <Widget>[
              for (final d in r.reports) _DeskTile(d: d),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: r.execute && r.plan != null
                    ? () {
                        final t = engine.sim.openPlan(r.plan!, engine.market);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(t == null
                              ? 'Impossible : position deja ouverte ou limite de 5 atteinte'
                              : 'Paper trade ouvert - suivi dans l onglet Simulateur'),
                        ));
                        _refresh();
                      }
                    : null,
                icon: const Icon(Icons.science),
                label: const Text('Envoyer au simulateur (paper)'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Simulation uniquement : aucun ordre reel n est passe sur Binance. Ceci n est pas un conseil financier.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: kMuted),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeskTile extends StatelessWidget {
  const _DeskTile({required this.d});
  final DeskReport d;

  @override
  Widget build(BuildContext context) {
    final col = d.ok ? kGreen : kRed;
    return Card(
      color: kSurface,
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(d.verdict, style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final l in d.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(l, style: const TextStyle(fontSize: 12, height: 1.3)),
            ),
        ],
      ),
    );
  }
}
