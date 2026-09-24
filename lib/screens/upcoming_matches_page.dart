import 'package:flutter/material.dart';

import '../models/prediction.dart';
import '../models/upcoming_match.dart';
import '../services/prediction_service.dart';

class UpcomingMatchesPage extends StatefulWidget {
  final String userId;
  final PredictionService? predictionService;

  const UpcomingMatchesPage({Key? key, required this.userId, this.predictionService}) : super(key: key);

  @override
  State<UpcomingMatchesPage> createState() => _UpcomingMatchesPageState();
}

class _UpcomingMatchesPageState extends State<UpcomingMatchesPage> {
  late final PredictionService _service = widget.predictionService ?? PredictionService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming Matches')),
      body: StreamBuilder<List<UpcomingMatch>>(
        stream: _service.watchUpcomingMatches(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load matches.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final matches = snapshot.data!;
          if (matches.isEmpty) {
            return const Center(child: Text('No upcoming matches right now.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: matches.length,
            itemBuilder: (context, index) => _MatchPredictionCard(
              match: matches[index],
              userId: widget.userId,
              service: _service,
            ),
          );
        },
      ),
    );
  }
}

class _MatchPredictionCard extends StatelessWidget {
  final UpcomingMatch match;
  final String userId;
  final PredictionService service;

  const _MatchPredictionCard({required this.match, required this.userId, required this.service});

  Future<void> _pick(BuildContext context, String side) async {
    final result = await service.submitPrediction(
      matchId: match.matchId,
      userId: userId,
      pickedSide: side,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${match.fighterAName} vs ${match.fighterBName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '${match.matchTime.toLocal()} · ${match.pointsValue} pts for a correct pick',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            StreamBuilder<Prediction?>(
              stream: service.watchMyPrediction(match.matchId, userId),
              builder: (context, snapshot) {
                final Prediction? myPick = snapshot.data;
                if (myPick != null) {
                  final pickedName = myPick.pickedSide == 'A' ? match.fighterAName : match.fighterBName;
                  return Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      Text('You picked $pickedName'),
                    ],
                  );
                }
                if (!match.canStillPredict) {
                  return const Text('Predictions closed', style: TextStyle(color: Colors.grey));
                }
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pick(context, 'A'),
                        child: Text(match.fighterAName, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pick(context, 'B'),
                        child: Text(match.fighterBName, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
