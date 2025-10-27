import 'package:flutter/material.dart';
import 'models.dart';

typedef VoidRequestCallback = void Function(RequestModel request);

class RequestTile extends StatelessWidget {
  final RequestModel request;
  final VoidRequestCallback onAcknowledge;
  final VoidRequestCallback onTap;
  final bool flashing;

  const RequestTile({
    Key? key,
    required this.request,
    required this.onAcknowledge,
    required this.onTap,
    this.flashing = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = flashing ? (request.isEmergency ? Colors.red.shade300 : Colors.lightBlue.shade200) : Colors.white;
    final borderColor = request.isEmergency ? Colors.redAccent : Colors.lightBlue;

    return GestureDetector(
      onTap: () => onTap(request),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor.withOpacity(0.7), width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${request.sender} • ${request.patientName ?? ""}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: request.isEmergency ? Colors.redAccent : Colors.black87)),
                const SizedBox(height: 6),
                Text(request.type, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                if (request.notes != null && request.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text('Notes: ${request.notes!}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_formatDurationSince(request.timestamp), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  color: Colors.green,
                  onPressed: () => onAcknowledge(request),
                  tooltip: 'Acknowledge',
                ),
                IconButton(
                  icon: const Icon(Icons.person_pin_circle),
                  color: Colors.teal,
                  onPressed: () => onTap(request),
                  tooltip: 'Details',
                ),
              ]),
            ]),
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
}