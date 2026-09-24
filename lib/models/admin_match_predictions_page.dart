import 'package:flutter/material.dart';

import '../../models/prediction.dart';
import '../../models/upcoming_match.dart';
import '../../services/admin_service.dart';

class AdminMatchPredictionsPage extends StatelessWidget {
  final UpcomingMatch match;
  final AdminService adminService;

  const AdminMatchPredictionsPage({Key? key, required this.match, required this.adminService})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${match.fighterAName} vs ${match.fighterBName}')),
      body: StreamBuilder<List<Prediction>>(
        stream: adminService.watchPredictionsForMatch(match.matchId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final predictions = snapshot.data!;
          if (predictions.isEmpty) {
            return const Center(child: Text('No predictions submitted yet.'));
          }

          final int pickedA = predictions.where((p) => p.pickedSide == 'A').length;
          final int pickedB = predictions.where((p) => p.pickedSide == 'B').length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatChip(label: match.fighterAName, count: pickedA, color: Colors.blue),
                    _StatChip(label: match.fighterBName, count: pickedB, color: Colors.red),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: predictions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = predictions[index];
                    final pickedName = p.pickedSide == 'A' ? match.fighterAName : match.fighterBName;
                    return ListTile(
                      title: Text('User: ${p.userId}'),
                      subtitle: Text('Picked $pickedName · ${p.createdAt.toLocal()}'),
                      trailing: p.scored
                          ? Text(
                              p.pointsAwarded > 0 ? '+${p.pointsAwarded} pts' : '0 pts',
                              style: TextStyle(
                                color: p.pointsAwarded > 0 ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : const Text('Pending', style: TextStyle(color: Colors.orange)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $count', style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
    );
  }
}
