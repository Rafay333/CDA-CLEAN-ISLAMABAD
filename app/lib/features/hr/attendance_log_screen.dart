import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/display_format.dart';
import 'employee_details.dart';

class AttendanceLogScreen extends StatefulWidget {
  const AttendanceLogScreen({super.key});

  @override
  State<AttendanceLogScreen> createState() => _AttendanceLogScreenState();
}

class _AttendanceLogScreenState extends State<AttendanceLogScreen> {
  final _api = SupervisorApi();
  final _search = TextEditingController();
  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _rows = [];
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
      final month = _date.month.toString().padLeft(2, '0');
      final day = _date.day.toString().padLeft(2, '0');
      final rows = await _api.faceLog(session.cnic, date: '${_date.year}-$month-$day');
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? _rows
        : _rows.where((row) {
            return '${row['name']} ${row['cnic']} ${row['employeeId']}'.toLowerCase().contains(query);
          }).toList();
    return AppPage(
      title: 'Attendance Log',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          DatePickerField(
            label: 'Date',
            value: _date,
            hint: 'Select date',
            lastDate: DateTime.now(),
            onChanged: (value) {
              setState(() => _date = value);
              _load();
            },
          ),
          const SizedBox(height: 12),
          SearchBarField(
            controller: _search,
            hint: 'Search by name, CNIC or employee ID',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingSkeletonGroup()
          else if (_error != null)
            InlineMessage(tone: InlineTone.error, message: _error!)
          else if (visible.isEmpty)
            EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'No attendance records',
              message: query.isEmpty
                  ? 'No one was marked on ${formatDate(_date)}.'
                  : 'Nothing matches this search.',
            )
          else
            for (final row in visible) ...[
              _LogCard(row: row),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final out = row['checkOut'] == null;
    final match = row['similarity'];
    final percent = match is num ? '${(match * 100).round()}% match' : null;
    final employeeId = row['employeeId'];
    final id = employeeId is int ? employeeId : int.tryParse('$employeeId') ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmployeePhoto(
            employeeId: id,
            registeredAt: row['faceRegisteredAt'] as String?,
            enrolled: row['enrolled'] == true,
            size: 64,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${row['name']} (${row['employeeId']})',
                        style: AppType.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (row['shift'] == 'Night' || row['shift'] == 'Evening') ...[
                      StatusBadge(
                        label: '${row['shift']}',
                        color: row['shift'] == 'Night' ? AppColors.navy : AppColors.info,
                      ),
                      const SizedBox(width: 6),
                    ],
                    StatusBadge(
                      label: out ? 'In' : 'Out',
                      color: out ? AppColors.success : AppColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Employee ID: ${row['employeeId']}', style: AppType.caption),
                Text('${row['cnic']} · ${row['role']}', style: AppType.caption),
                const SizedBox(height: 8),
                Text(
                  'In ${_clock(row['checkIn'])}   Out ${_clock(row['checkOut'])}',
                  style: AppType.body,
                ),
                if (row['geoTag'] != null || percent != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [?percent, if (row['geoTag'] != null) '${row['geoTag']}'].join(' · '),
                    style: AppType.caption,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _clock(Object? value) {
    if (value == null) return '—';
    final text = value.toString();
    return text.length >= 5 ? text.substring(0, 5) : text;
  }
}
