import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/hr1_api_face.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../utils/pakistan_time.dart';
import 'face_hr_ui.dart';

class GpsAttendanceLogScreenFace extends StatefulWidget {
  const GpsAttendanceLogScreenFace({super.key});

  @override
  State<GpsAttendanceLogScreenFace> createState() => _GpsAttendanceLogScreenFaceState();
}

class _GpsAttendanceLogScreenFaceState extends State<GpsAttendanceLogScreenFace> {
  final _api = Hr1ApiFace();
  final _search = TextEditingController();
  late DateTime _date = DateTime(pakistanNow().year, pakistanNow().month, pakistanNow().day);
  List<Map<String, dynamic>> _rows = [];
  Map<int, Map<String, dynamic>> _employees = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = AppStateScope.read(context).session;
      if (session == null) throw SupervisorException('Sign in again.');
      final rows = await _api.attendanceLog(session.cnic, date: supervisorDate(_date));
      Map<int, Map<String, dynamic>> employees = {};
      try {
        final people = await SupervisorApi().faceEmployees(session.cnic);
        employees = {for (final person in people) person['employeeId'] as int: person};
      } on SupervisorException {
        employees = {};
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _employees = employees;
        _loading = false;
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
        _rows = [];
      });
    }
  }

  Future<void> _openPhoto(Map<String, dynamic>? row) async {
    if (row == null) return;
    final session = AppStateScope.read(context).session;
    final cnic = session?.cnic ?? '';
    final url = _api.absolute(row['photo_url']?.toString(), cnic);
    if (!mounted || url.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) => FaceHrStampedPhotoDialog(
        photoUrl: url,
        photoHeaders: _api.photoHeaders,
        title: row['type'] == 'check_out' ? 'Check-out photo' : 'Check-in photo',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final people = _people();
    final visible = query.isEmpty
        ? people
        : people.where((person) {
            return '${person.name} ${person.cnic}'.toLowerCase().contains(query);
          }).toList();
    final present = people.length;
    final checkedIn = people.where((person) => person.checkIn != null).length;
    final checkedOut = people.where((person) => person.checkOut != null).length;
    final cnic = AppStateScope.of(context).session?.cnic ?? '';

    return AppPage(
      title: 'Attendance log',
      actions: [
        IconActionButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          light: true,
          busy: _loading,
          onPressed: _load,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const FaceHrHero(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Face attendance log',
            subtitle: 'Daily check-in and check-out tracks from face recognition, with GPS stamps.',
            colors: [Color(0xFF1D4ED8), Color(0xFF0F766E), Color(0xFF123B5D)],
          ),
          const SizedBox(height: 16),
          DatePickerField(
            label: 'Date',
            value: _date,
            firstDate: DateTime(2024),
            lastDate: DateTime(pakistanNow().year + 1),
            onChanged: (value) {
              setState(() => _date = value);
              _load();
            },
          ),
          const SizedBox(height: 12),
          if (!_loading && _error == null) ...[
            FaceHrDaySummary(present: present, checkedIn: checkedIn, checkedOut: checkedOut),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search name or CNIC',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_error != null)
            InlineMessage(message: _error!, tone: InlineTone.error)
          else if (visible.isEmpty)
            const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No attendance',
              message: 'Check-in and check-out for this day will show here.',
            )
          else
            for (final person in visible) ...[
              FaceHrLogPersonCard(
                name: person.name,
                cnic: person.cnic,
                shift: person.shift,
                registeredAt: person.registeredAt,
                photoUrl: _api.absolute(
                  '/api/supervisor/hr-photo-face/register/${person.employeeId}/photo',
                  cnic,
                ),
                photoHeaders: _api.photoHeaders,
                checkIn: person.checkIn,
                checkOut: person.checkOut,
                onOpen: _openPhoto,
                showSuspicious: true,
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  List<_PersonDay> _people() {
    final ordered = [..._rows]..sort((a, b) => '${a['timestamp'] ?? ''}'.compareTo('${b['timestamp'] ?? ''}'));
    final byId = <int, _PersonDay>{};
    for (final row in ordered) {
      final id = int.tryParse('${row['employee_id'] ?? row['user_id'] ?? ''}') ?? 0;
      final employee = _employees[id];
      final person = byId.putIfAbsent(
        id,
        () => _PersonDay(
          employeeId: id,
          name: '${row['name'] ?? employee?['name'] ?? ''}',
          cnic: '${row['cnic'] ?? employee?['cnic'] ?? ''}',
          shift: '${employee?['shift'] ?? row['shift'] ?? ''}',
          registeredAt: '${employee?['createdAt'] ?? row['registered_at'] ?? ''}',
        ),
      );
      if (row['type'] == 'check_out') {
        person.checkOut = row;
      } else {
        person.checkIn ??= row;
      }
    }
    final people = byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return people;
  }
}

class _PersonDay {
  _PersonDay({
    required this.employeeId,
    required this.name,
    required this.cnic,
    required this.shift,
    required this.registeredAt,
  });

  final int employeeId;
  final String name;
  final String cnic;
  final String shift;
  final String registeredAt;
  Map<String, dynamic>? checkIn;
  Map<String, dynamic>? checkOut;
}
