import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/display_format.dart';

/// Shared visual language for Face HR register + attendance screens.
class FaceHrPalette {
  const FaceHrPalette._();

  static const accent = Color(0xFF0F766E);
  static const accentDeep = Color(0xFF115E59);
  static const accentSoft = Color(0xFFE6F7F4);
  static const accentLine = Color(0xFF99D6CD);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const panel = Color(0xFFF8FAFC);
  static const successSoft = Color(0xFFECFDF5);
  static const warningSoft = Color(0xFFFFFBEB);
}

class FaceHrHero extends StatelessWidget {
  const FaceHrHero({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.colors = const [Color(0xFF0F766E), Color(0xFF134E4A), Color(0xFF123B5D)],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x33123B5D), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppType.section.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: AppType.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.45,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FaceHrWorkerPicker extends StatelessWidget {
  const FaceHrWorkerPicker({
    super.key,
    required this.name,
    required this.hint,
    this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  final String? name;
  final String hint;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selected = name != null && name!.trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? FaceHrPalette.accentLine : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: AppShadows.soft,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected
                        ? const LinearGradient(
                            colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
                          )
                        : null,
                    color: selected ? null : FaceHrPalette.panel,
                    border: Border.all(
                      color: selected ? const Color(0xFF99F6E4) : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    selected ? Icons.person_rounded : Icons.person_search_rounded,
                    color: selected ? Colors.white : FaceHrPalette.muted,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected ? name! : hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.section.copyWith(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? FaceHrPalette.ink : FaceHrPalette.muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        selected
                            ? (subtitle?.trim().isNotEmpty == true
                                ? subtitle!
                                : 'Tap to choose another worker')
                            : 'Search by name or CNIC',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption.copyWith(color: FaceHrPalette.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: FaceHrPalette.accentSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    selected ? Icons.swap_horiz_rounded : Icons.chevron_right_rounded,
                    color: FaceHrPalette.accent,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FaceHrWorkerCard extends StatelessWidget {
  const FaceHrWorkerCard({
    super.key,
    required this.name,
    this.role = '',
    this.cnic = '',
    this.shift = '',
    this.contact = '',
    this.photo,
    this.badge,
    this.footer,
  });

  final String name;
  final String role;
  final String cnic;
  final String shift;
  final String contact;
  final Widget? photo;
  final Widget? badge;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF1688D4)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    photo ??
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: FaceHrPalette.accentSoft,
                            border: Border.all(color: FaceHrPalette.accentLine, width: 2.5),
                          ),
                          child: const Icon(Icons.person_rounded, color: FaceHrPalette.accent, size: 34),
                        ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Worker' : name,
                            style: AppType.section.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: FaceHrPalette.ink,
                            ),
                          ),
                          if (role.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(role, style: AppType.caption.copyWith(color: FaceHrPalette.muted)),
                          ],
                          if (badge != null) ...[
                            const SizedBox(height: 8),
                            badge!,
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: FaceHrPalette.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      if (cnic.trim().isNotEmpty)
                        FaceHrMetaRow(icon: Icons.badge_outlined, label: 'CNIC', value: cnic),
                      if (shift.trim().isNotEmpty) ...[
                        if (cnic.trim().isNotEmpty) const SizedBox(height: 10),
                        FaceHrMetaRow(icon: Icons.schedule_outlined, label: 'Shift', value: shift),
                      ],
                      if (contact.trim().isNotEmpty) ...[
                        if (cnic.trim().isNotEmpty || shift.trim().isNotEmpty) const SizedBox(height: 10),
                        FaceHrMetaRow(icon: Icons.call_outlined, label: 'Contact', value: contact),
                      ],
                    ],
                  ),
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

class FaceHrMetaRow extends StatelessWidget {
  const FaceHrMetaRow({
    super.key,
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
        Icon(icon, size: 17, color: FaceHrPalette.accent),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(label, style: AppType.caption.copyWith(color: const Color(0xFF94A3B8))),
        ),
        Expanded(
          child: Text(
            value,
            style: AppType.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: FaceHrPalette.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class FaceHrStatusChip extends StatelessWidget {
  const FaceHrStatusChip({
    super.key,
    required this.label,
    required this.ok,
  });

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF15803D) : const Color(0xFFB45309);
    final bg = ok ? FaceHrPalette.successSoft : FaceHrPalette.warningSoft;
    final border = ok ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.verified_rounded : Icons.info_rounded, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppType.caption.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class FaceHrStepGuide extends StatelessWidget {
  const FaceHrStepGuide({super.key, required this.steps});

  final List<(IconData, String, String)> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: FaceHrPalette.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(steps[i].$1, color: FaceHrPalette.accent, size: 18),
                    ),
                    if (i < steps.length - 1)
                      Container(
                        width: 2,
                        height: 22,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: const Color(0xFFCCFBF1),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 10 : 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].$2,
                          style: AppType.label.copyWith(fontSize: 13.5, color: FaceHrPalette.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          steps[i].$3,
                          style: AppType.caption.copyWith(color: FaceHrPalette.muted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class FaceHrShiftPicker extends StatelessWidget {
  const FaceHrShiftPicker({
    super.key,
    required this.shifts,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<(String, IconData)> shifts;
  final String? value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final item in shifts) ...[
          Expanded(
            child: _ShiftTile(
              label: item.$1,
              icon: item.$2,
              selected: value == item.$1,
              onTap: enabled ? () => onChanged(item.$1) : null,
            ),
          ),
          if (item != shifts.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? FaceHrPalette.accentSoft : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? FaceHrPalette.accent : const Color(0xFFE2E8F0),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected ? AppShadows.soft : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: selected ? FaceHrPalette.accentDeep : FaceHrPalette.muted),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? FaceHrPalette.accentDeep : FaceHrPalette.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FaceHrActionBanner extends StatelessWidget {
  const FaceHrActionBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.tone = FaceHrActionTone.checkIn,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final FaceHrActionTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      FaceHrActionTone.checkIn => const [Color(0xFF0F766E), Color(0xFF0E7490)],
      FaceHrActionTone.checkOut => const [Color(0xFF1D4ED8), Color(0xFF312E81)],
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: const [
          BoxShadow(color: Color(0x28123B5D), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppType.section.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppType.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum FaceHrActionTone { checkIn, checkOut }

class FaceHrTodayTimeline extends StatelessWidget {
  const FaceHrTodayTimeline({
    super.key,
    required this.rows,
    required this.formatWhen,
    required this.isSuspicious,
    required this.flagNote,
  });

  final List<Map<String, dynamic>> rows;
  final String Function(Object?) formatWhen;
  final bool Function(Object?) isSuspicious;
  final String Function(Object?) flagNote;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: FaceHrPalette.panel,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event_available_outlined, color: FaceHrPalette.muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No marks yet today. Capture will create the first one.',
                style: AppType.caption.copyWith(color: FaceHrPalette.muted, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _TodayRow(
              row: rows[i],
              when: formatWhen(rows[i]['timestamp']),
              suspicious: isSuspicious(rows[i]['suspicious']),
              note: flagNote(rows[i]['suspicious_reason']),
              isLast: i == rows.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({
    required this.row,
    required this.when,
    required this.suspicious,
    required this.note,
    required this.isLast,
  });

  final Map<String, dynamic> row;
  final String when;
  final bool suspicious;
  final String note;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final checkout = row['type'] == 'check_out';
    final color = checkout ? const Color(0xFF1D4ED8) : const Color(0xFF0F766E);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 6 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  checkout ? Icons.logout_rounded : Icons.login_rounded,
                  size: 18,
                  color: color,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: suspicious ? 36 : 18,
                  margin: const EdgeInsets.only(top: 4),
                  color: const Color(0xFFE2E8F0),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checkout ? 'Check out' : 'Check in',
                  style: AppType.label.copyWith(color: FaceHrPalette.ink),
                ),
                const SizedBox(height: 2),
                Text(when, style: AppType.caption.copyWith(color: FaceHrPalette.muted)),
                if (suspicious) ...[
                  const SizedBox(height: 6),
                  Text(
                    note,
                    style: AppType.caption.copyWith(
                      color: const Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (suspicious)
            const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFF59E0B)),
        ],
      ),
    );
  }
}

class FaceHrResultSheet extends StatelessWidget {
  const FaceHrResultSheet({
    super.key,
    required this.message,
    required this.photoUrl,
    required this.photoHeaders,
    this.matchPercent,
    this.latitude,
    this.longitude,
    this.address = '',
    this.timestamp = '',
    this.suspicious = false,
    this.suspiciousReason = '',
  });

  final String message;
  final String photoUrl;
  final Map<String, String> photoHeaders;
  final Object? matchPercent;
  final Object? latitude;
  final Object? longitude;
  final String address;
  final String timestamp;
  final bool suspicious;
  final String suspiciousReason;

  @override
  Widget build(BuildContext context) {
    final ok = !suspicious;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: ok
                      ? const [Color(0xFF0F766E), Color(0xFF134E4A)]
                      : const [Color(0xFFB45309), Color(0xFF92400E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      ok ? Icons.check_rounded : Icons.warning_amber_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ok ? 'Attendance saved' : 'Saved · flagged for review',
                      style: AppType.section.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(message, style: AppType.body.copyWith(height: 1.4)),
                    if (photoUrl.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.network(
                            photoUrl,
                            headers: photoHeaders,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: FaceHrPalette.panel,
                              alignment: Alignment.center,
                              child: const Text('Photo could not be loaded.'),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (matchPercent != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: FaceHrPalette.accentSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: FaceHrPalette.accentLine),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.face_retouching_natural, color: FaceHrPalette.accent),
                            const SizedBox(width: 10),
                            Text(
                              'Face match $matchPercent%',
                              style: AppType.label.copyWith(
                                color: FaceHrPalette.accentDeep,
                                fontSize: 14.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (suspicious) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FaceHrPalette.warningSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          suspiciousReason.trim().isEmpty
                              ? 'Saved, but flagged for review.'
                              : 'Flagged for review: $suspiciousReason',
                          style: AppType.caption.copyWith(
                            color: const Color(0xFF92400E),
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (latitude != null && longitude != null) ...[
                      const SizedBox(height: 12),
                      FaceHrMetaRow(
                        icon: Icons.my_location_outlined,
                        label: 'GPS',
                        value: '$latitude, $longitude',
                      ),
                    ],
                    if (address.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      FaceHrMetaRow(
                        icon: Icons.place_outlined,
                        label: 'Place',
                        value: address,
                      ),
                    ],
                    if (timestamp.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      FaceHrMetaRow(
                        icon: Icons.schedule_outlined,
                        label: 'Time',
                        value: _prettyTime(timestamp),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: FaceHrPalette.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _prettyTime(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return formatDateTime(date.toLocal());
  }
}

class FaceHrSectionLabel extends StatelessWidget {
  const FaceHrSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppType.section.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: FaceHrPalette.ink,
      ),
    );
  }
}

class FaceHrDaySummary extends StatelessWidget {
  const FaceHrDaySummary({
    super.key,
    required this.present,
    required this.checkedIn,
    required this.checkedOut,
  });

  final int present;
  final int checkedIn;
  final int checkedOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          _SummaryStat(label: 'Present', value: present, icon: Icons.groups_rounded, color: AppColors.emerald),
          Container(width: 1, height: 64, color: const Color(0xFFE2E8F0)),
          _SummaryStat(label: 'Check in', value: checkedIn, icon: Icons.login_rounded, color: AppColors.teal),
          Container(width: 1, height: 64, color: const Color(0xFFE2E8F0)),
          _SummaryStat(label: 'Check out', value: checkedOut, icon: Icons.logout_rounded, color: AppColors.navy),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 8),
            Text('$value', style: AppType.title.copyWith(fontSize: 22, color: FaceHrPalette.ink)),
            const SizedBox(height: 2),
            Text(label, style: AppType.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class FaceHrLogPersonCard extends StatelessWidget {
  const FaceHrLogPersonCard({
    super.key,
    required this.name,
    required this.cnic,
    required this.shift,
    required this.registeredAt,
    required this.photoUrl,
    required this.photoHeaders,
    required this.checkIn,
    required this.checkOut,
    required this.onOpen,
    this.showSuspicious = false,
  });

  final String name;
  final String cnic;
  final String shift;
  final String registeredAt;
  final String photoUrl;
  final Map<String, String> photoHeaders;
  final Map<String, dynamic>? checkIn;
  final Map<String, dynamic>? checkOut;
  final Future<void> Function(Map<String, dynamic>? row) onOpen;
  final bool showSuspicious;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF1688D4)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: FaceHrPalette.accentLine, width: 2.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: photoUrl.isEmpty
                          ? const ColoredBox(
                              color: FaceHrPalette.accentSoft,
                              child: Icon(Icons.person_rounded, color: FaceHrPalette.accent),
                            )
                          : Image.network(
                              photoUrl,
                              headers: photoHeaders,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: FaceHrPalette.accentSoft,
                                child: Icon(Icons.person_rounded, color: FaceHrPalette.accent),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.trim().isEmpty ? 'Worker' : name,
                            style: AppType.section.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'CNIC · ${_shown(cnic)}',
                            style: AppType.caption.copyWith(color: FaceHrPalette.muted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Shift · ${_shown(shift)}',
                            style: AppType.caption.copyWith(color: FaceHrPalette.muted),
                          ),
                          if (_clock(registeredAt) != '—') ...[
                            const SizedBox(height: 2),
                            Text(
                              'Enrolled · ${_clock(registeredAt)}',
                              style: AppType.caption.copyWith(color: FaceHrPalette.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FaceHrMarkTile(
                        title: 'Check in',
                        row: checkIn,
                        onOpen: onOpen,
                        showSuspicious: showSuspicious,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FaceHrMarkTile(
                        title: 'Check out',
                        row: checkOut,
                        onOpen: onOpen,
                        showSuspicious: showSuspicious,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FaceHrMarkTile extends StatelessWidget {
  const FaceHrMarkTile({
    super.key,
    required this.title,
    required this.row,
    required this.onOpen,
    this.showSuspicious = false,
  });

  final String title;
  final Map<String, dynamic>? row;
  final Future<void> Function(Map<String, dynamic>? row) onOpen;
  final bool showSuspicious;

  @override
  Widget build(BuildContext context) {
    final marked = row != null;
    final suspicious = showSuspicious && _isSuspicious(row);
    final accent = marked
        ? (suspicious ? const Color(0xFFB45309) : const Color(0xFF15803D))
        : FaceHrPalette.muted;
    return Material(
      color: marked
          ? (suspicious ? FaceHrPalette.warningSoft : FaceHrPalette.successSoft)
          : FaceHrPalette.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: marked ? () => onOpen(row) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: Column(
            children: [
              Icon(
                marked
                    ? (suspicious ? Icons.warning_amber_rounded : Icons.check_circle_rounded)
                    : Icons.circle_outlined,
                color: accent,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(title, style: AppType.label.copyWith(fontSize: 12.5, color: FaceHrPalette.ink)),
              const SizedBox(height: 8),
              Text('Time', style: AppType.caption.copyWith(fontSize: 11)),
              const SizedBox(height: 2),
              Text(
                _clock(row?['timestamp']),
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              if (suspicious) ...[
                const SizedBox(height: 6),
                Text(
                  'Flagged',
                  style: AppType.caption.copyWith(
                    color: const Color(0xFFB45309),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FaceHrStampedPhotoDialog extends StatelessWidget {
  const FaceHrStampedPhotoDialog({
    super.key,
    required this.photoUrl,
    required this.photoHeaders,
    this.title = 'Stamped photo',
  });

  final String photoUrl;
  final Map<String, String> photoHeaders;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Text(
                title,
                style: AppType.section.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.network(
                photoUrl,
                headers: photoHeaders,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(child: Text('The stamped photo could not be loaded.')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: FaceHrPalette.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isSuspicious(Map<String, dynamic>? row) {
  final value = row?['suspicious'];
  return value == true || value == 1 || '${value ?? ''}'.toLowerCase() == 'true';
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
  return '${two(local.hour)}:${two(local.minute)}';
}
