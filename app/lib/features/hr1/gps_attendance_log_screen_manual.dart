import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/hr1_api_manual.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/pakistan_time.dart';

class GpsAttendanceLogScreenManual extends StatefulWidget {
  const GpsAttendanceLogScreenManual({super.key});

  @override
  State<GpsAttendanceLogScreenManual> createState() => _GpsAttendanceLogScreenManualState();
}

class _GpsAttendanceLogScreenManualState extends State<GpsAttendanceLogScreenManual> {
  final _api = Hr1ApiManual();
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
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.network(
              url,
              headers: _api.photoHeaders,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('The stamped photo could not be loaded.'),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
            ),
          ],
        ),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
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
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search name or CNIC',
              prefixIcon: Icon(Icons.search),
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
              _PersonCard(
                person: person,
                cnic: AppStateScope.of(context).session?.cnic ?? '',
                onOpen: _openPhoto,
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

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, required this.cnic, required this.onOpen});

  final _PersonDay person;
  final String cnic;
  final Future<void> Function(Map<String, dynamic>? row) onOpen;

  @override
  Widget build(BuildContext context) {
    final api = Hr1ApiManual();
    final photo = api.absolute('/api/supervisor/hr-photo-manual/register/${person.employeeId}/photo', cnic);
    return Material(
      color: AppColors.white,
      elevation: 1,
      shadowColor: const Color(0x14000000),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(person.name, style: AppType.section.copyWith(fontSize: 18, height: 1.25)),
            const SizedBox(height: 6),
            Text('Shift Id: ${_shown(person.shift)}', style: AppType.body.copyWith(fontSize: 13.5)),
            Text('Cnic: ${_shown(person.cnic)}', style: AppType.body.copyWith(fontSize: 13.5)),
            Text('Registration Time: ${_clock(person.registeredAt)}', style: AppType.body.copyWith(fontSize: 13.5)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: photo.isEmpty
                      ? const _PhotoFallback()
                      : Image.network(
                          photo,
                          headers: api.photoHeaders,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _PhotoFallback(),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _MarkColumn(title: 'Check In', row: person.checkIn, onOpen: onOpen)),
                Expanded(child: _MarkColumn(title: 'Check Out', row: person.checkOut, onOpen: onOpen)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkColumn extends StatelessWidget {
  const _MarkColumn({required this.title, required this.row, required this.onOpen});

  final String title;
  final Map<String, dynamic>? row;
  final Future<void> Function(Map<String, dynamic>? row) onOpen;

  @override
  Widget build(BuildContext context) {
    final marked = row != null;
    return InkWell(
      onTap: marked ? () => onOpen(row) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Icon(
              marked ? Icons.check_circle : Icons.circle_outlined,
              color: marked ? const Color(0xFF22C55E) : AppColors.disabledText,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(title, textAlign: TextAlign.center, style: AppType.label.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            Text('Server ID', textAlign: TextAlign.center, style: AppType.caption),
            Text(
              marked ? '${row!['id'] ?? ''}' : '—',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text('Server Time', textAlign: TextAlign.center, style: AppType.caption),
            Text(
              _clock(row?['timestamp']),
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 72,
      height: 72,
      child: ColoredBox(
        color: AppColors.disabled,
        child: Icon(Icons.person, color: AppColors.disabledText),
      ),
    );
  }
}

String _shown(String value) {
  final text = value.trim();
  return text.isEmpty || text == 'null' ? '—' : text;
}

String _clock(Object? value) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty || text == 'null') return '—';
  final date = DateTime.tryParse(text);
  if (date == null) return text;
  final local = date.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
