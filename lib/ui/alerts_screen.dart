import 'package:flutter/material.dart';
import '../engine.dart';
import '../format.dart';
import '../theme.dart';
import 'pipeline_screen.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (BuildContext context, Widget? _) {
        final list = engine.alerts;
        return Scaffold(
          appBar: AppBar(title: const Text('ALERTES')),
          body: list.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Aucune alerte pour le moment.\nLe radar surveille les jetons en continu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kMuted),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: list.length,
                  itemBuilder: (BuildContext context, int i) {
                    final a = list[i];
                    final col = a.up ? kGreen : kRed;
                    return Card(
                      color: kSurface,
                      child: ListTile(
                        leading: Icon(a.up ? Icons.trending_up : Icons.trending_down, color: col),
                        title: Text(a.title, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('${fmtTime(a.time)} · ${a.body}', style: const TextStyle(fontSize: 11)),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (BuildContext _) => PipelineScreen(symbol: a.symbol)),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
