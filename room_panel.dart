import 'package:flutter/material.dart';
import 'models.dart';
import 'request_tile.dart';

class RoomPanel extends StatelessWidget {
  final String roomName;
  final List<RequestModel> requests;
  final void Function(RequestModel) onAcknowledge;
  final void Function(RequestModel) onSelect;
  final bool initiallyExpanded;

  const RoomPanel({
    Key? key,
    required this.roomName,
    required this.requests,
    required this.onAcknowledge,
    required this.onSelect,
    this.initiallyExpanded = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Row(children: [
          Text('Room $roomName', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.teal.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Text('${requests.length} requests')),
          const Spacer(),
          Text(_formatDurationSince(requests.map((r) => r.timestamp).reduce((a, b) => a < b ? a : b)), style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        children: requests.map((r) {
          // flashing should be computed by parent and passed if needed;
          // here we leave flashing false by default
          return RequestTile(
            request: r,
            onAcknowledge: onAcknowledge,
            onTap: onSelect,
            flashing: false,
          );
        }).toList(),
      ),
    );
  }

  String _formatDurationSince(int timestamp) {
    final now = DateTime.now();
    final then = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(then);
    if (diff.inMinutes < 1) return '${diff.inSeconds}s';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }
}