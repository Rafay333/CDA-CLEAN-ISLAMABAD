import 'package:flutter/material.dart';

import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class TodayCard extends StatefulWidget {
  const TodayCard({super.key});

  @override
  State<TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<TodayCard> {
  HrSummary? _summary;
  int? _openIssues;
  int? _evidence;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
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
    try {
      final api = SupervisorApi();
      final results = await Future.wait([
        api.hrSummary(session.cnic),
        api.openIssues(session.cnic),
        api.evidence(session.cnic),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as HrSummary;
        _openIssues = (results[1] as List).length;
        _evidence = (results[2] as EvidenceDay).count;
        _loading = false;
        _error = null;
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
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
                  _Stat(label: 'Present', value: '${_summary?.presentToday ?? 0}/${_summary?.activeEmployees ?? 0}'),
                  _Stat(label: 'Open complaints', value: '${_openIssues ?? 0}'),
                  _Stat(label: 'Evidence', value: '${_evidence ?? 0}'),
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
