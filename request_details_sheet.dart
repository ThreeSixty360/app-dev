import 'package:flutter/material.dart';
import 'models.dart';

Future<void> showRequestDetailsSheet(BuildContext context, RequestModel r, void Function(RequestModel) onAcknowledge) {
  return showModalBottomSheet(
    context: context,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        children: [
          ListTile(title: Text('Patient: ${r.patientName ?? 'Unknown'}'), subtitle: Text('Device: ${r.sender}\nRoom: ${r.room}\nFloor: ${r.floor}')),
          ListTile(leading: Icon(r.isEmergency ? Icons.warning : Icons.inbox, color: r.isEmergency ? Colors.red : Colors.blue), title: Text('Request'), subtitle: Text(r.type)),
          if (r.notes != null && r.notes!.isNotEmpty) ListTile(title: const Text('Notes'), subtitle: Text(r.notes!)),
          ListTile(title: const Text('Waiting time'), subtitle: Text(_formatDurationSince(r.timestamp))),
          ButtonBar(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onAcknowledge(r);
                },
                icon: const Icon(Icons.check),
                label: const Text('Acknowledge'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              ElevatedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), label: const Text('Close')),
            ],
          ),
        ],
      ),
    ),
  );
}

String _formatDurationSince(int timestamp) {
  final now = DateTime.now();
  final then = DateTime.fromMillisecondsSinceEpoch(timestamp);
  final diff = now.difference(then);
  if (diff.inSeconds < 5) return 'Just now';
  if (diff.inMinutes < 1) return '${diff.inSeconds}s';
  if (diff.inHours < 1) return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
  if (diff.inDays < 1) return '${diff.inHours}h ${diff.inMinutes % 60}m';
  return '${diff.inDays}d ${diff.inHours % 24}h';
}