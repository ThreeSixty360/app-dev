import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:carelink/dashboard/models.dart';
import 'package:carelink/dashboard/floor_panel.dart';
import 'package:carelink/dashboard/request_details_sheet.dart';
import 'package:carelink/dashboard/history_sheet.dart';
import '../utils/notification_service.dart';

/// DashboardScreen (refactored)
/// - Uses modular widgets (FloorPanel, RoomPanel, RequestTile, sheets)
/// - Keeps Firebase listeners, grouping and notification logic here
class DashboardScreen extends StatefulWidget {
  final String caretakerName;

  const DashboardScreen({Key? key, required this.caretakerName})
      : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final _queueRef = FirebaseDatabase.instance.ref('/requests/queue');
  final _historyRef = FirebaseDatabase.instance.ref('/requests/history');
  final _devicesRef = FirebaseDatabase.instance.ref('/devices');
  final _assignRef = FirebaseDatabase.instance.ref('/assignments');

  final NotificationService _notificationService = NotificationService();

  late AnimationController _idlePulseController;
  late AnimationController _cardController;
  late Animation<double> _idlePulse;
  late Animation<double> _cardScale;

  List<RequestModel> _allRequests = [];
  Map<String, DeviceInfo> _devices = {};
  Map<String, String> _assignments = {};
  List<HistoryItem> _requestHistory = [];
  RequestState? _currentRequest;

  StreamSubscription<DatabaseEvent>? _queueSubscription;
  StreamSubscription<DatabaseEvent>? _historySubscription;
  StreamSubscription<DatabaseEvent>? _devicesSubscription;
  StreamSubscription<DatabaseEvent>? _assignSubscription;

  Timer? _ticker;
  final Map<String, bool> _lastFlashState = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startListeners();
    _startTicker();
  }

  @override
  void dispose() {
    _idlePulseController.dispose();
    _cardController.dispose();
    _queueSubscription?.cancel();
    _historySubscription?.cancel();
    _devicesSubscription?.cancel();
    _assignSubscription?.cancel();
    _ticker?.cancel();
    _notificationService.stopSound();
    super.dispose();
  }

  void _initializeAnimations() {
    _idlePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _idlePulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _idlePulseController, curve: Curves.easeInOut),
    );

    _cardScale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.elasticOut),
    );
  }

  void _startListeners() {
    _queueSubscription = _queueRef.onValue.listen(_processQueueUpdate);
    _historySubscription = _historyRef
        .orderByChild('timestamp')
        .limitToLast(200)
        .onValue
        .listen((event) {
      if (!event.snapshot.exists) {
        setState(() => _requestHistory.clear());
        return;
      }
      final historyData = Map<String, dynamic>.from(event.snapshot.value as Map);
      final items = <HistoryItem>[];
      historyData.forEach((k, v) {
        if (v is Map) {
          items.add(HistoryItem.fromMap(k, Map<String, dynamic>.from(v)));
        }
      });
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      setState(() => _requestHistory = items);
    });

    _devicesSubscription = _devicesRef.onValue.listen((event) {
      final d = <String, DeviceInfo>{};
      if (event.snapshot.exists) {
        final map = Map<String, dynamic>.from(event.snapshot.value as Map);
        map.forEach((key, value) {
          if (value is Map) {
            d[key] = DeviceInfo.fromMap(key, Map<String, dynamic>.from(value));
          }
        });
      }
      setState(() => _devices = d);
    });

    _assignSubscription = _assignRef.onValue.listen((event) {
      final a = <String, String>{};
      if (event.snapshot.exists) {
        final map = Map<String, dynamic>.from(event.snapshot.value as Map);
        map.forEach((key, value) {
          a[key] = value?.toString() ?? '';
        });
      }
      setState(() => _assignments = a);
    });
  }

  void _startTicker() {
    // tick every 500ms to refresh flashing and timers
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  void _processQueueUpdate(DatabaseEvent event) {
    if (!event.snapshot.exists) {
      setState(() {
        _allRequests.clear();
      });
      _clearCurrentRequest();
      return;
    }

    final queueData = Map<String, dynamic>.from(event.snapshot.value as Map);
    final requests = <RequestModel>[];

    queueData.forEach((key, value) {
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        if ((map['status'] ?? 'pending') == 'pending') {
          final model = RequestModel.fromMap(key, map);
          final dev = _devices[model.sender];
          if (dev != null) {
            model.patientName = dev.patientName;
            model.floor = dev.floor;
            model.room = dev.room;
            model.notes = dev.notes;
          }
          requests.add(model);
        }
      }
    });

    requests.sort((a, b) {
      final eA = a.isEmergency ? 0 : 1;
      final eB = b.isEmergency ? 0 : 1;
      if (eA != eB) return eA - eB;
      if (a.priority != b.priority) return a.priority - b.priority;
      return a.timestamp.compareTo(b.timestamp);
    });

    setState(() {
      _allRequests = requests;
    });

    // Auto-process next visible request if none is active
    if (_currentRequest == null) {
      final next = _visibleRequestsForCaretaker().isNotEmpty
          ? _visibleRequestsForCaretaker().first
          : null;
      if (next != null) _processNextRequest(next);
    } else {
      final exists = _allRequests.any((r) => r.key == _currentRequest!.key);
      if (!exists) _clearCurrentRequest();
    }
  }

  List<RequestModel> _visibleRequestsForCaretaker() {
    final name = widget.caretakerName;
    if (_assignments.isEmpty) return _allRequests;
    return _allRequests.where((r) {
      final floorStr = r.floor?.toString() ?? '';
      final assigned = _assignments[floorStr];
      return assigned == name;
    }).toList();
  }

  void _processNextRequest(RequestModel request) {
    if (_currentRequest?.key == request.key) return;

    _updateCurrentRequest(RequestState.fromModel(request));
    _cardController.forward(from: 0.0);

    // Start appropriate sound for the newly processed request:
    if (request.isEmergency) {
      _notificationService.playEmergencySound();
    } else {
      // Play one-shot notification when it becomes current
      _notificationService.playNormalSound();
    }
  }

  Future<void> _acknowledgeRequest(RequestState currentRequest) async {
    if (currentRequest == null) return;
    try {
      final requestRef = _queueRef.child(currentRequest.key);
      await requestRef.update({'status': 'acknowledged'});

      final historyItem = {
        'sender': currentRequest.sender,
        'type': currentRequest.type,
        'isEmergency': currentRequest.isEmergency,
        'action': 'acknowledged',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'originalRequestKey': currentRequest.key,
        'acknowledgedBy': widget.caretakerName,
      };
      await _historyRef.push().set(historyItem);

      // allow ESP32 to detect ack
      await Future.delayed(const Duration(milliseconds: 900));
      await requestRef.remove();

      _showSuccessMessage('Acknowledged request from ${currentRequest.sender} ✅');

      // Stop sounds (important for emergency)
      await _notificationService.stopSound();

      _clearCurrentRequest();

      // Refresh queue locally
      final queueSnap = await _queueRef.get();
      if (queueSnap.exists) {
        final queueData = Map<String, dynamic>.from(queueSnap.value as Map);
        final requests = <RequestModel>[];
        queueData.forEach((k, v) {
          if (v is Map && (v['status'] ?? 'pending') == 'pending') {
            final m = RequestModel.fromMap(k, Map<String, dynamic>.from(v));
            final dev = _devices[m.sender];
            if (dev != null) {
              m.patientName = dev.patientName;
              m.floor = dev.floor;
              m.room = dev.room;
              m.notes = dev.notes;
            }
            requests.add(m);
          }
        });
        requests.sort((a, b) {
          final eA = a.isEmergency ? 0 : 1;
          final eB = b.isEmergency ? 0 : 1;
          if (eA != eB) return eA - eB;
          if (a.priority != b.priority) return a.priority - b.priority;
          return a.timestamp.compareTo(b.timestamp);
        });
        setState(() => _allRequests = requests);

        final nextList = _visibleRequestsForCaretaker();
        if (nextList.isNotEmpty) _processNextRequest(nextList.first);
      } else {
        setState(() => _allRequests.clear());
      }
    } catch (e) {
      _showErrorMessage('Failed to acknowledge: $e');
    }
  }

  void _updateCurrentRequest(RequestState? request) {
    setState(() {
      _currentRequest = request;
    });
  }

  void _clearCurrentRequest() {
    if (_currentRequest != null) {
      _notificationService.stopSound();
    }
    _updateCurrentRequest(null);
  }

  // Flashing helpers (keeps same timing rules)
  bool _shouldFlash(RequestModel r) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - r.timestamp;
    if (r.isEmergency) {
      final halfPeriods = (elapsed / 500).floor();
      return (halfPeriods % 2) == 0;
    } else {
      final periods = (elapsed / 10000).floor();
      return (periods % 2) == 0;
    }
  }

  // play a one-shot normal beep on rising-edge for visible normal requests
  void _maybePlayRisingEdgeBeep(RequestModel r) {
    final key = r.key;
    final should = _shouldFlash(r);
    final was = _lastFlashState[key] ?? false;
    if (should && !was) {
      if (!r.isEmergency) {
        _notificationService.playNormalSound();
      }
      // emergency uses looping alarm started elsewhere
    }
    _lastFlashState[key] = should;
  }

  Map<int, Map<String, List<RequestModel>>> _groupRequests(List<RequestModel> requests) {
    final Map<int, Map<String, List<RequestModel>>> result = {};
    for (final r in requests) {
      final floor = r.floor ?? 0;
      final room = r.room ?? (r.sender);
      result.putIfAbsent(floor, () => {});
      result[floor]!.putIfAbsent(room, () => []);
      result[floor]![room]!.add(r);
    }
    for (final floorMap in result.values) {
      for (final list in floorMap.values) {
        list.sort((a, b) {
          final eA = a.isEmergency ? 0 : 1;
          final eB = b.isEmergency ? 0 : 1;
          if (eA != eB) return eA - eB;
          return a.timestamp.compareTo(b.timestamp);
        });
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final visibleRequests = _visibleRequestsForCaretaker();
    visibleRequests.sort((a, b) {
      final eA = a.isEmergency ? 0 : 1;
      final eB = b.isEmergency ? 0 : 1;
      if (eA != eB) return eA - eB;
      return a.timestamp.compareTo(b.timestamp);
    });

    // Manage rising-edge beeps for visible normal requests
    for (final r in visibleRequests) _maybePlayRisingEdgeBeep(r);

    final grouped = _groupRequests(visibleRequests);
    final floorsSorted = grouped.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text('CareLink - ${widget.caretakerName}'),
        backgroundColor: _currentRequest?.isEmergency == true ? Colors.redAccent : Colors.teal,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Request History',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => HistorySheet(items: _requestHistory),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: floorsSorted.isEmpty
          ? _buildIdleView()
          : ListView(
              padding: const EdgeInsets.all(12),
              children: floorsSorted.map((floor) {
                final rooms = grouped[floor]!;
                final assigned = _assignments[floor.toString()] ?? 'Unassigned';
                return FloorPanel(
                  floor: floor,
                  rooms: rooms,
                  assignedNurse: assigned,
                  onAcknowledge: (r) => _acknowledgeRequest(RequestState.fromModel(r)),
                  onSelect: (r) => showRequestDetailsSheet(context, r, (req) => _acknowledgeRequest(RequestState.fromModel(req))),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildIdleView() {
    return Center(
      child: ScaleTransition(
        scale: _idlePulse,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hearing, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '🔄 Listening for requests...',
              style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text('Logged in as: ${widget.caretakerName}', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _logout() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }
}