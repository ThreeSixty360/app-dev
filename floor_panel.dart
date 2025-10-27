import 'package:flutter/material.dart';
import 'models.dart';
import 'room_panel.dart';

class FloorPanel extends StatelessWidget {
  final int floor;
  final Map<String, List<RequestModel>> rooms;
  final String assignedNurse;
  final void Function(RequestModel) onAcknowledge;
  final void Function(RequestModel) onSelect;

  const FloorPanel({
    Key? key,
    required this.floor,
    required this.rooms,
    required this.assignedNurse,
    required this.onAcknowledge,
    required this.onSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final roomKeys = rooms.keys.toList()..sort();
    final total = rooms.values.expand((x) => x).length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Floor $floor', style: const TextStyle(fontWeight: FontWeight.bold)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Assigned: $assignedNurse', style: TextStyle(color: assignedNurse.isNotEmpty ? Colors.green : Colors.grey, fontSize: 12)),
                Text('$total active', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        children: roomKeys.map((roomKey) {
          return RoomPanel(
            roomName: roomKey,
            requests: rooms[roomKey]!,
            onAcknowledge: onAcknowledge,
            onSelect: onSelect,
            initiallyExpanded: true,
          );
        }).toList(),
      ),
    );
  }
}