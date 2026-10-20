import 'package:flutter/material.dart';

import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class TodayCard extends StatefulWidget {
  const TodayCard({super.key});

  @override
  TodayCardState createState() => TodayCardState();
}

class TodayCardState extends State<TodayCard> {
  Future<void> reload() => _load();
  HrSummary? _summary;
  int? _openIssues;
  int? _evidence;
  int? _required;
  int? _uploadedRequired;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<T?> _try<T>(Future<T> Function() call, List<String> errors) async {
    try {
      return await call();
    } on SupervisorException catch (error) {
      errors.add(error.message);
      return null;
    }
  }

  Future<void> _load() async {
    final session = AppStateScope.read(context).session;
    if (session == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in to load today.';
      });
      return;
    }
    final api = SupervisorApi();
    final errors = <String>[];
    final summary = await _try(() => api.hrSummary(session.cnic), errors);
    final issues = await _try(() => api.openIssues(session.cnic), errors);
    EvidenceStatus? status;
    EvidenceDay? day;
    try {
      status = await api.evidenceStatus(session.cnic);
    } on SupervisorException {
      day = await _try(() => api.evidence(session.cnic), errors);
    }
    if (!mounted) return;
    final hasAny = summary != null || issues != null || status != null || day != null;
    setState(() {
      _summary = summary;
      _openIssues = issues?.length;
      _evidence = status?.totalPhotos ?? day?.count;
      _required = status?.requiredCount;
      _uploadedRequired = status?.uploadedRequired;
      _loading = false;
      _error = hasAny ? null : (errors.isEmpty ? 'Could not load today.' : errors.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDCE7F0)),
        ),
        child: _loading
            ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            : _error != null
            ? Text(_error!, style: AppType.caption.copyWith(color: AppColors.error))
            : Row(
                children: [
                  _Stat(
                    label: 'Present',
                    value: _summary == null
                        ? '—'
                        : '${_summary!.presentToday}/${_summary!.activeEmployees}',
                  ),
                  _Stat(label: 'Open complaints', value: _openIssues == null ? '—' : '${_openIssues!}'),
                  _Stat(
                    label: 'PED photos',
                    value: _required == null
                        ? (_evidence == null ? '—' : '${_evidence!}')
                        : '${_uploadedRequired ?? 0}/${_required ?? 0}',
                  ),
                ],
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppType.section.copyWith(fontSize: 18, color: const Color(0xFF12304A))),
          const SizedBox(height: 2),
          Text(label, style: AppType.caption),
        ],
      ),
    );
  }
}
