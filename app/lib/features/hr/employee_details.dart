import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../constants/app_copy.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/display_format.dart';

class EmployeeDetails extends StatelessWidget {
  const EmployeeDetails({
    super.key,
    required this.employee,
    this.attendance,
    this.matchPercent,
  });

  final Map<String, dynamic> employee;
  final Map<String, dynamic>? attendance;
  final int? matchPercent;

  @override
  Widget build(BuildContext context) {
    final enrolled = employee['enrolled'] == true;
    final status = employee['status'] == true ? 'Active' : 'Inactive';
    final contractor = employee['contractorName'] == null
        ? _text(employee['contractorId'])
        : '${employee['contractorName']}'
            '${employee['contractorCode'] == null ? '' : ' (${employee['contractorCode']})'}';
    final rows = <(String, String)>[
      ('Employee ID', _text(employee['employeeId'])),
      ('Name', _text(employee['name'])),
      ('Role', _text(employee['role'])),
      ('Shift', _text(employee['shift'])),
      ('CNIC', _text(employee['cnic'])),
      ('Contact', _text(employee['contact'])),
      ('Salary', _money(employee['salary'])),
      ('Status', status),
      ('Status id', '${employee['statusId'] ?? AppCopy.notProvided} — ${_text(employee['statusName'])}'),
      ('Contractor', contractor),
      ('Created by', _text(employee['createdBy'])),
      ('Created at', _when(employee['createdAt'])),
      ('Modified by', _text(employee['modifiedBy'])),
      ('Modified at', _when(employee['modifiedAt'])),
      ('Face', enrolled ? 'Registered' : 'Not registered'),
      ('Face registered at', _when(employee['faceRegisteredAt'])),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (enrolled)
          Align(
            alignment: Alignment.centerLeft,
            child: EmployeePhoto(
              employeeId: employee['employeeId'] as int,
              registeredAt: employee['faceRegisteredAt'] as String?,
              enrolled: true,
              size: 96,
            ),
          ),
        for (final row in rows) ...[
          const SizedBox(height: 8),
          InfoCard(label: row.$1, value: row.$2),
        ],
        if (attendance != null) ...[
          const SizedBox(height: 16),
          Text('Today', style: AppType.section.copyWith(fontSize: 16)),
          const SizedBox(height: 8),
          InfoCard(label: 'Date', value: _text(attendance!['date'])),
          const SizedBox(height: 8),
          InfoCard(label: 'Check in', value: _clock(attendance!['checkIn'])),
          const SizedBox(height: 8),
          InfoCard(label: 'Check out', value: _clock(attendance!['checkOut'])),
          const SizedBox(height: 8),
          InfoCard(label: 'Location', value: _text(attendance!['geoTag'])),
          const SizedBox(height: 8),
          InfoCard(
            label: 'Match',
            value: matchPercent != null
                ? '$matchPercent%'
                : _percent(attendance!['similarity']),
          ),
          const SizedBox(height: 8),
          InfoCard(label: 'Source', value: _text(attendance!['source'])),
        ],
      ],
    );
  }

  static String _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? AppCopy.notProvided : text;
  }

  static String _money(Object? value) {
    if (value == null) return AppCopy.notProvided;
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return _text(value);
    return number.toStringAsFixed(number == number.roundToDouble() ? 0 : 2);
  }

  static String _when(Object? value) {
    if (value == null || '$value'.isEmpty) return AppCopy.notProvided;
    final date = DateTime.tryParse('$value');
    return date == null ? _text(value) : formatDateTime(date.toLocal());
  }

  static String _clock(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty || text == 'null') return AppCopy.notProvided;
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  static String _percent(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('${value ?? ''}');
    if (number == null) return AppCopy.notProvided;
    return '${(number * 100).round()}%';
  }
}

/// The registered face photo, or a grey placeholder when none is saved.
class EmployeePhoto extends StatelessWidget {
  const EmployeePhoto({
    super.key,
    required this.employeeId,
    required this.registeredAt,
    required this.enrolled,
    this.size = 64,
  });

  final int employeeId;
  final String? registeredAt;
  final bool enrolled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: AppColors.border,
      alignment: Alignment.center,
      child: Icon(Icons.person_outline, size: size * 0.5, color: AppColors.textSecondary),
    );
    final cnic = AppStateScope.of(context).session?.cnic ?? '';
    final api = SupervisorApi();
    return ClipOval(
      child: enrolled && cnic.isNotEmpty
          ? Image.network(
              api.facePhotoUrl(employeeId, cnic, registeredAt),
              headers: api.facePhotoHeaders,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            )
          : placeholder,
    );
  }
}
