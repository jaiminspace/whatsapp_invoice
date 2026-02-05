import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/activity_log_model.dart';
import '../state/activity_log_notifier.dart';

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(filteredLogsProvider);
    final entityFilter = ref.watch(logEntityFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
        actions: [
          IconButton(
            tooltip: 'Clear all logs',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Clear all logs?'),
                  content: const Text('This will delete all activity logs.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );

              if (ok == true) {
                await ref.read(activityLogProvider.notifier).clearAll();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search logs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (v) => ref.read(logSearchProvider.notifier).state = v,
            ),
          ),

          // Entity filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _chip(
                  context,
                  label: 'All',
                  selected: entityFilter == null,
                  onTap: () => ref.read(logEntityFilterProvider.notifier).state =
                  null,
                ),
                const SizedBox(width: 8),
                ...LogEntity.values.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _chip(
                      context,
                      label: _labelEntity(e),
                      selected: entityFilter == e,
                      onTap: () => ref
                          .read(logEntityFilterProvider.notifier)
                          .state = e,
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: logs.isEmpty
                ? const Center(
              child: Text('No logs found'),
            )
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final l = logs[i];
                final time =
                DateFormat('dd MMM yyyy, hh:mm a').format(l.createdAt);

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withOpacity(0.35),
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      l.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('${l.message}\n$time'),
                    isThreeLine: true,
                    trailing: _badge(
                      context,
                      text:
                      '${_labelEntity(l.entity)} • ${l.action.name.toUpperCase()}',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
      BuildContext context, {
        required String label,
        required bool selected,
        required VoidCallback onTap,
      }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _badge(BuildContext context, {required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _labelEntity(LogEntity e) {
    switch (e) {
      case LogEntity.business:
        return 'Business';
      case LogEntity.customer:
        return 'Customer';
      case LogEntity.item:
        return 'Item';
      case LogEntity.invoice:
        return 'Invoice';
    }
  }
}
