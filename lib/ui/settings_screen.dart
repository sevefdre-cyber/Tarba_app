import 'package:flutter/material.dart';
import '../engine.dart';
import '../models.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (BuildContext context, Widget? _) {
        return Scaffold(
          appBar: AppBar(title: const Text('REGLAGES')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: <Widget>[
              const _H('Notifications'),
              SwitchListTile(
                title: const Text('Alertes "pret a exploser"'),
                subtitle: const Text('Notification immediate quand un jeton atteint le seuil de mouvements'),
                value: engine.notifOn,
                onChanged: engine.setNotif,
              ),
              ListTile(
                title: const Text('Tester la notification'),
                trailing: const Icon(Icons.notifications),
                onTap: engine.testNotification,
              ),
              SwitchListTile(
                title: const Text('Garder le radar actif en arriere-plan'),
                subtitle: const Text('Service au premier plan (notification permanente). Consomme plus de batterie.'),
                value: engine.keepAlive,
                onChanged: engine.setKeepAlive,
              ),
              const _H('Sensibilite du detecteur'),
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Pas de mouvement : ${engine.sens.step}% · mouvements requis : ${engine.sens.minEvents} · '
                  'score d alerte : ${engine.sens.alertScore.round()}',
                  style: const TextStyle(fontSize: 11, color: kMuted),
                ),
              ),
              const _H('Simulateur'),
              Text('Risque par trade : ${engine.riskPct.toStringAsFixed(1)} % du capital virtuel'),
              Slider(
                value: engine.riskPct,
                min: 0.5,
                max: 3.0,
                divisions: 5,
                label: '${engine.riskPct.toStringAsFixed(1)} %',
                onChanged: engine.setRisk,
              ),
              const _H('A savoir'),
              const Text(
                'Le score est un indicateur statistique de "preparation" (mouvements repetes, vitesse, flux de volume) : '
                'il ne predit pas une explosion de prix et ne garantit rien. Tout le trading est simule (paper). '
                'Ceci n est pas un conseil financier.',
                style: TextStyle(fontSize: 12, color: kMuted, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
        child: Text(text, style: const TextStyle(color: kGold, fontWeight: FontWeight.bold)),
      );
}
