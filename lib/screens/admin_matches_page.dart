import 'package:flutter/material.dart';

import '../../models/upcoming_match.dart';
import '../../services/admin_service.dart';
import '../../models/admin_match_predictions_page.dart';


class AdminMatchesPage extends StatefulWidget {
  final AdminService? adminService;
  const AdminMatchesPage({Key? key, this.adminService}) : super(key: key);

  @override
  State<AdminMatchesPage> createState() => _AdminMatchesPageState();
}

class _AdminMatchesPageState extends State<AdminMatchesPage> {
  late final AdminService _service = widget.adminService ?? AdminService();

  Future<void> _openCreateDialog() async {
    final fighterAController = TextEditingController();
    final fighterBController = TextEditingController();
    final pointsController = TextEditingController(text: '10');
    DateTime? selectedTime;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Create Match'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fighterAController,
                  decoration: const InputDecoration(labelText: 'Team / Fighter A name'),
                ),
                TextField(
                  controller: fighterBController,
                  decoration: const InputDecoration(labelText: 'Team / Fighter B name'),
                ),
                TextField(
                  controller: pointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Points for a correct pick'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedTime == null ? 'No date/time set' : selectedTime.toString(),
                        style: selectedTime == null
                            ? const TextStyle(color: Colors.red)
                            : null,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date == null) return;
                        final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                        if (time == null) return;
                        setLocal(() {
                          selectedTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        });
                      },
                      child: const Text('Pick date/time'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedTime == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Pick a date and time first.')),
                  );
                  return;
                }
                final result = await _service.createMatch(
                  fighterAName: fighterAController.text,
                  fighterBName: fighterBController.text,
                  matchTime: selectedTime!,
                  pointsValue: int.tryParse(pointsController.text) ?? 10,
                );
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openResultDialog(UpcomingMatch match) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enter result: ${match.fighterAName} vs ${match.fighterBName}'),
        content: const Text('Who won? This will score every prediction for this match.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('A'),
            child: Text('${match.fighterAName} won'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('B'),
            child: Text('${match.fighterBName} won'),
          ),
        ],
      ),
    );
    if (result == null) return;

    final opResult = await _service.enterResultAndScore(matchId: match.matchId, winningSide: result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(opResult.message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Matches'),
        actions: [
          IconButton(onPressed: _openCreateDialog, icon: const Icon(Icons.add)),
        ],
      ),
      body: StreamBuilder<List<UpcomingMatch>>(
        stream: _service.watchAllMatches(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load matches:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final matches = snapshot.data!;
          if (matches.isEmpty) {
            return const Center(child: Text('No matches yet — tap + to create one.'));
          }
          return ListView.builder(
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              return ListTile(
                title: Text('${match.fighterAName} vs ${match.fighterBName}'),
                subtitle: Text(
                  '${match.status.name.toUpperCase()} · ${match.matchTime.toLocal()}'
                  '${match.winningSide != null ? ' · Winner: ${match.winningSide}' : ''}',
                ),
                trailing: match.status == PredictionMatchStatus.upcoming
                    ? TextButton(onPressed: () => _openResultDialog(match), child: const Text('Enter result'))
                    : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminMatchPredictionsPage(match: match, adminService: _service),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}