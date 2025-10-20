import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../services/history_service.dart';
import '../models/analysis_entry.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final historyService = Provider.of<HistoryService>(context);
    final savedAnalyses = historyService.savedAnalyses;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Locations"),
        actions: [
          if (savedAnalyses.isNotEmpty)
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.trashCan),
              onPressed: () => _showClearAllDialog(context, historyService),
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: savedAnalyses.isEmpty
          ? _buildEmptyState(context)
          : _buildHistoryList(context, savedAnalyses, historyService),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamedAndRemoveUntil('/map', (route) => false);
        },
        heroTag: 'newAnalysisFab',
        child: const FaIcon(FontAwesomeIcons.plus),
      ),
    );
  }

  void _showClearAllDialog(BuildContext context, HistoryService service) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All History'),
          content: const Text('Are you sure you want to remove all saved locations? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await service.clearAllAnalyses();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All saved locations removed')),
                  );
                }
              },
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteSingleDialog(BuildContext context, AnalysisEntry entry, HistoryService service) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Location'),
          content: Text('Are you sure you want to remove "${entry.address}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await service.removeAnalysis(entry);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Removed '${entry.address}'")),
                  );
                }
              },
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Text(
        "No saved analyses yet!",
        style: TextStyle(
          fontSize: 18,
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context,
      List<AnalysisEntry> analyses, HistoryService service) {
    return ListView.builder(
      itemCount: analyses.length,
      itemBuilder: (context, index) {
        final entry = analyses[index];
        return _buildHistoryItem(context, entry, service);
      },
    );
  }

  Widget _buildHistoryItem(
      BuildContext context, AnalysisEntry entry, HistoryService service) {
    return Dismissible(
      key: Key(entry.dateSaved.toIso8601String()),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) async {
        await service.removeAnalysis(entry);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Removed '${entry.address}'")),
          );
        }
      },
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      child: ListTile(
        leading: const FaIcon(FontAwesomeIcons.mapPin),
        title: Text(
          entry.address,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text("Saved: ${entry.dateSaved.toLocal().toString().substring(0, 16)}"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.eye, size: 18),
              onPressed: () {
                Navigator.of(context).pushNamed('/analyze', arguments: entry);
              },
              tooltip: 'View Details',
            ),
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.trash, size: 16),
              onPressed: () => _showDeleteSingleDialog(context, entry, service),
              tooltip: 'Delete',
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).pushNamed('/analyze', arguments: entry);
        },
      ),
    );
  }
}