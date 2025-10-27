import 'package:flutter/material.dart';
import 'models.dart';

class HistorySheet extends StatelessWidget {
  final List<HistoryItem> items;

  const HistorySheet({Key? key, required this.items}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            const Text('Request History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No history yet'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final it = items[i];
                        return ListTile(
                          leading: Icon(it.isEmergency ? Icons.warning : Icons.history, color: it.isEmergency ? Colors.red : Colors.teal),
                          title: Text('${it.sender} — ${it.type}'),
                          subtitle: Text('${it.action} • ${_formatDetailedTimestamp(it.timestamp)}${it.acknowledgedBy != null ? ' • by ${it.acknowledgedBy}' : ''}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDetailedTimestamp(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at $hour:$minute:$second $ampm';
  }
}