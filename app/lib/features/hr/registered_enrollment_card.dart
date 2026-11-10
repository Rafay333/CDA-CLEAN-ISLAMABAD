import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/display_format.dart';

/// Professional enrolled / already-registered presentation used by HR, HR1, and Face HR.
class RegisteredEnrollmentCard extends StatelessWidget {
  const RegisteredEnrollmentCard({
    super.key,
    required this.name,
    this.role = '',
    this.cnicNo = '',
    this.shift,
    this.registeredAt,
    this.photoUrl = '',
    this.photoHeaders = const {},
    this.photo,
    this.justRegistered = false,
    this.footer,
    this.alreadyHint,
    this.successHint,
  });

  final String name;
  final String role;
  final String cnicNo;
  final String? shift;
  final Object? registeredAt;
  final String photoUrl;
  final Map<String, String> photoHeaders;
  /// Optional custom photo widget (e.g. [EmployeePhoto]). Overrides [photoUrl].
  final Widget? photo;
  final bool justRegistered;
  final Widget? footer;
  final String? alreadyHint;
  final String? successHint;

  String get _when {
    if (registeredAt == null || '$registeredAt'.isEmpty) return '';
    final date = DateTime.tryParse('$registeredAt');
    return date == null ? '$registeredAt' : formatDateTime(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final hint = justRegistered
        ? (successHint ?? 'This face is ready for attendance verification.')
        : (alreadyHint ??
            'This worker already has a photo on file. No further registration needed.');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7EBE2)),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 6,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF15803D)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFBBF7D0), width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A15803D),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: photo ??
                          (photoUrl.isEmpty
                              ? const ColoredBox(
                                  color: Color(0xFFF0FDF4),
                                  child: Icon(Icons.person_rounded, size: 52, color: Color(0xFF15803D)),
                                )
                              : Image.network(
                                  photoUrl,
                                  headers: photoHeaders,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: Color(0xFFF0FDF4),
                                    child: Icon(Icons.person_rounded, size: 52, color: Color(0xFF15803D)),
                                  ),
                                )),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF15803D),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: AppType.section.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                if (role.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    role,
                    textAlign: TextAlign.center,
                    style: AppType.caption.copyWith(color: const Color(0xFF64748B)),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF15803D)),
                      const SizedBox(width: 6),
                      Text(
                        justRegistered ? 'Enrolled successfully' : 'Already enrolled',
                        style: AppType.body.copyWith(
                          color: const Color(0xFF166534),
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      if (cnicNo.isNotEmpty)
                        _MetaRow(icon: Icons.badge_outlined, label: 'CNIC', value: cnicNo),
                      if (shift != null && shift!.trim().isNotEmpty) ...[
                        if (cnicNo.isNotEmpty) const SizedBox(height: 10),
                        _MetaRow(icon: Icons.schedule_outlined, label: 'Shift', value: shift!.trim()),
                      ],
                      if (_when.isNotEmpty) ...[
                        if (cnicNo.isNotEmpty || (shift != null && shift!.trim().isNotEmpty))
                          const SizedBox(height: 10),
                        _MetaRow(icon: Icons.event_available_outlined, label: 'Enrolled', value: _when),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: AppType.caption.copyWith(height: 1.4, color: const Color(0xFF64748B)),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 12),
                  footer!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0F766E)),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: AppType.caption.copyWith(color: const Color(0xFF94A3B8)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppType.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
