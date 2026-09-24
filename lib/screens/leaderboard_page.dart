import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/prediction_service.dart';

class LeaderboardPage extends StatelessWidget {
  final String? currentUserId;
  final PredictionService? predictionService;

  const LeaderboardPage({Key? key, this.currentUserId, this.predictionService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = predictionService ?? PredictionService();

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: StreamBuilder<List<AppUser>>(
        stream: service.watchLeaderboard(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final players = snapshot.data!;
          if (players.isEmpty) {
            return const Center(child: Text('No ranked players yet.'));
          }
          return ListView.separated(
            itemCount: players.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final player = players[index];
              final bool isMe = player.uid == currentUserId;
              final int rank = index + 1;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: rank <= 3 ? Colors.amber.shade600 : Colors.grey.shade300,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: rank <= 3 ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  player.displayName,
                  style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
                ),
                subtitle: isMe ? const Text('You') : null,
                trailing: Text(
                  '${player.points} pts',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                tileColor: isMe ? Colors.blue.shade50 : null,
              );
            },
          );
        },
      ),
    );
  }
}
