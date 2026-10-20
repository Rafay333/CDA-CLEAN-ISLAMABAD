import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/pakistan_time.dart';

class EvidenceHistoryScreen extends StatefulWidget {
  const EvidenceHistoryScreen({super.key, this.date});

  final String? date;

  @override
  State<EvidenceHistoryScreen> createState() => _EvidenceHistoryScreenState();
}

class _EvidenceHistoryScreenState extends State<EvidenceHistoryScreen> {
  late DateTime _date;
  EvidenceDay? _day;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = parseSupervisorDate(widget.date) ?? DateTime(pakistanNow().year, pakistanNow().month, pakistanNow().day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final session = AppStateScope.read(context).session;
    if (session == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in again.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final day = await SupervisorApi().evidence(session.cnic, date: supervisorDate(_date), mineOnly: true);
      if (!mounted) return;
      setState(() {
        _day = day;
        _loading = false;
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
        _day = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;
    final now = pakistanNow();
    return AppPage(
      title: 'My evidence',
      actions: [
        IconActionButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          light: true,
          busy: _loading,
          onPressed: _loading ? null : _load,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          DatePickerField(
            label: 'Date',
            value: _date,
            firstDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 90)),
            lastDate: DateTime(now.year, now.month, now.day),
            onChanged: (value) {
              setState(() => _date = DateTime(value.year, value.month, value.day));
              _load();
            },
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingSkeletonGroup()
          else if (_error != null)
            InlineMessage(tone: InlineTone.error, message: _error!)
          else if (day == null || day.count == 0)
            const EmptyState(
              icon: Icons.photo_outlined,
              title: 'No photos yet',
              message: 'Photos you upload for this date will appear here.',
            )
          else ...[
            InlineMessage(
              tone: InlineTone.success,
              message: '${day.count} photo${day.count == 1 ? '' : 's'} uploaded on ${day.date}.',
            ),
            if (day.activitiesSummary.isNotEmpty) ...[
              const SizedBox(height: 18),
              const SectionHeader(title: 'By activity'),
              const SizedBox(height: 10),
              for (final row in day.activitiesSummary) ...[
                ListItem(
                  title: row.activity,
                  subtitle: [
                    if (row.pedSerial != null && row.pedSerial!.isNotEmpty) 'PED ${row.pedSerial}',
                    '${row.photoCount} photo${row.photoCount == 1 ? '' : 's'}',
                    if (row.hitsPed) 'Scores PED',
                  ].join(' · '),
                  trailing: StatusBadge(
                    label: '${row.photoCount}',
                    color: row.photoCount > 0 ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 8),
            const SectionHeader(title: 'Photos'),
            const SizedBox(height: 10),
            for (final item in day.items) ...[
              _EvidenceTile(item: item),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.item});

  final EvidenceItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              supervisorMediaUrl(item.url),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFEEF3F6),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Icon(Icons.image_outlined, color: AppColors.navy),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.activity.isEmpty ? 'Evidence ${item.id}' : item.activity,
                  style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (item.pedSerial != null && item.pedSerial!.isNotEmpty) 'PED ${item.pedSerial}',
                    item.dateCaptured,
                    if (item.geoTag != null) item.geoTag!,
                  ].join(' · '),
                  style: AppType.caption,
                ),
                if (item.hitsPed) ...[
                  const SizedBox(height: 6),
                  const StatusBadge(label: 'PED', color: AppColors.success),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
