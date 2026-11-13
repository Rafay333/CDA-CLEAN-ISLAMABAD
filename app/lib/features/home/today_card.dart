import 'package:flutter/material.dart';

import '../../core/staff_access.dart';
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
    final showHr = session.can(StaffCapability.manageHr);
    final showIssues = session.can(StaffCapability.resolveIssues);
    final showEvidence = session.can(StaffCapability.submitEvidence);
    if (!showHr && !showIssues && !showEvidence) {
      setState(() {
        _loading = false;
        _summary = null;
        _openIssues = null;
        _evidence = null;
        _required = null;
        _uploadedRequired = null;
        _error = null;
      });
      return;
    }
    final api = SupervisorApi();
    final errors = <String>[];
    final summary = showHr ? await _try(() => api.hrSummary(session.cnic), errors) : null;
    final issues = showIssues ? await _try(() => api.openIssues(session.cnic), errors) : null;
    EvidenceStatus? status;
    EvidenceDay? day;
    if (showEvidence) {
      try {
        status = await api.evidenceStatus(session.cnic);
      } on SupervisorException {
        day = await _try(() => api.evidence(session.cnic), errors);
      }
    }
    if (!mounted) return;
    final hasAny = (showHr && summary != null) ||
        (showIssues && issues != null) ||
        (showEvidence && (status != null || day != null));
    setState(() {
      _summary = summary;
      _openIssues = showIssues ? issues?.length : null;
      _evidence = showEvidence ? (status?.totalPhotos ?? day?.count) : null;
      _required = showEvidence ? status?.requiredCount : null;
      _uploadedRequired = showEvidence ? status?.uploadedRequired : null;
      _loading = false;
      _error = hasAny ? null : (errors.isEmpty ? 'Could not load today.' : errors.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = AppStateScope.of(context).session;
    final showHr = session?.can(StaffCapability.manageHr) == true;
    final showIssues = session?.can(StaffCapability.resolveIssues) == true;
    final showEvidence = session?.can(StaffCapability.submitEvidence) == true;
    if (!_loading && _error == null && !showHr && !showIssues && !showEvidence) {
      return const SizedBox.shrink();
    }
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
                  if (showHr)
                    _Stat(
                      label: 'Present',
                      value: _summary == null
                          ? '—'
                          : '${_summary!.presentToday}/${_summary!.activeEmployees}',
                    ),
                  if (showIssues)
                    _Stat(label: 'Open complaints', value: _openIssues == null ? '—' : '${_openIssues!}'),
                  if (showEvidence)
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
