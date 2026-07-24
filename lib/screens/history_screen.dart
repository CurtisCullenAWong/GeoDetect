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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: savedAnalyses.isEmpty
              ? _buildEmptyState(context)
              : _buildHistoryList(context, savedAnalyses, historyService),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamedAndRemoveUntil('/map', (route) => false);
        },
        heroTag: 'newAnalysisFab',
        child: const FaIcon(FontAwesomeIcons.plus),
      ),
    );
  }

  void _showClearAllDialog(BuildContext pageContext, HistoryService service) {
    bool closed = false;
    showDialog(
      context: pageContext,
      builder: (BuildContext dialogContext) {
        Future.delayed(const Duration(seconds: 5), () {
          if (!closed && dialogContext.mounted) {
            closed = true;
            Navigator.of(dialogContext, rootNavigator: true).pop();
          }
        });
        return AlertDialog(
          title: const Text('Clear All History'),
          content: const Text('Are you sure you want to remove all saved locations? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () {
                if (!closed) {
                  closed = true;
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                }
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (!closed) {
                  closed = true;
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                }
                await service.clearAllAnalyses();
                if (pageContext.mounted) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    const SnackBar(content: Text('All saved locations removed')),
                  );
                }
              },
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(pageContext).colorScheme.error),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteSingleDialog(BuildContext pageContext, AnalysisEntry entry, HistoryService service) {
    bool closed = false;
    showDialog(
      context: pageContext,
      builder: (BuildContext dialogContext) {
        Future.delayed(const Duration(seconds: 5), () {
          if (!closed && dialogContext.mounted) {
            closed = true;
            Navigator.of(dialogContext, rootNavigator: true).pop();
          }
        });
        return AlertDialog(
          title: const Text('Delete Location'),
          content: Text('Are you sure you want to remove "${entry.address}"?'),
          actions: [
            TextButton(
              onPressed: () {
                if (!closed) {
                  closed = true;
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                }
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (!closed) {
                  closed = true;
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                }
                await service.removeAnalysis(entry);
                if (pageContext.mounted) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    SnackBar(content: Text("Removed '${entry.address}'")),
                  );
                }
              },
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(pageContext).colorScheme.error),
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
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.mapPin),
          tooltip: 'Pin on Demo Map',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            Navigator.of(context).pushNamed('/map', arguments: entry);
          },
        ),
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
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                Navigator.of(context).pushNamed('/analyze', arguments: entry);
              },
              tooltip: 'View Analysis',
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
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          Navigator.of(context).pushNamed('/analyze', arguments: entry);
        },
      ),
    );
  }
}