// Models used by dashboard widgets

class RequestModel {
  final String key;
  final String sender;
  String? patientName;
  int? floor;
  String? room;
  String? notes;
  final String type;
  final bool isEmergency;
  final int priority;
  final int timestamp;

  RequestModel({
    required this.key,
    required this.sender,
    required this.type,
    required this.isEmergency,
    required this.priority,
    required this.timestamp,
    this.patientName,
    this.floor,
    this.room,
    this.notes,
  });

  factory RequestModel.fromMap(String key, Map<String, dynamic> data) {
    return RequestModel(
      key: key,
      sender: data['sender'] ?? 'unknown',
      type: data['type'] ?? 'Unknown',
      isEmergency: data['emergency'] == true,
      priority: data['priority'] ?? (data['emergency'] == true ? 1 : 2),
      timestamp: data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class RequestState {
  final String key;
  final String sender;
  final String type;
  final bool isEmergency;
  final int? queuePosition;

  const RequestState({
    required this.key,
    required this.sender,
    required this.type,
    required this.isEmergency,
    required this.queuePosition,
  });

  factory RequestState.fromModel(RequestModel m) {
    return RequestState(
      key: m.key,
      sender: m.sender,
      type: m.type,
      isEmergency: m.isEmergency,
      queuePosition: 0,
    );
  }
}

class DeviceInfo {
  final String id;
  final String patientName;
  final int floor;
  final String room;
  final String notes;

  DeviceInfo({
    required this.id,
    required this.patientName,
    required this.floor,
    required this.room,
    required this.notes,
  });

  factory DeviceInfo.fromMap(String id, Map<String, dynamic> data) {
    return DeviceInfo(
      id: id,
      patientName: (data['patientName'] ?? data['name'] ?? '').toString(),
      floor: (data['floor'] is int) ? data['floor'] as int : int.tryParse('${data['floor']}') ?? 0,
      room: (data['room'] ?? '').toString(),
      notes: (data['notes'] ?? '').toString(),
    );
  }
}

class HistoryItem {
  final String key;
  final String sender;
  final String type;
  final bool isEmergency;
  final String action;
  final int timestamp;
  final String originalRequestKey;
  final String? acknowledgedBy;

  const HistoryItem({
    required this.key,
    required this.sender,
    required this.type,
    required this.isEmergency,
    required this.action,
    required this.timestamp,
    required this.originalRequestKey,
    this.acknowledgedBy,
  });

  factory HistoryItem.fromMap(String key, Map<String, dynamic> data) {
    return HistoryItem(
      key: key,
      sender: data['sender'] ?? 'Unknown',
      type: data['type'] ?? 'Unknown',
      isEmergency: data['isEmergency'] ?? false,
      action: data['action'] ?? 'unknown',
      timestamp: data['timestamp'] ?? 0,
      originalRequestKey: data['originalRequestKey'] ?? '',
      acknowledgedBy: data['acknowledgedBy'],
    );
  }
}