import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

const _processingKey = 'complaintProcessingIds';

class ComplaintListScreen extends StatefulWidget {
  const ComplaintListScreen({super.key, this.openOnly = false});

  final bool openOnly;

  @override
  State<ComplaintListScreen> createState() => _ComplaintListScreenState();
}

class _ComplaintListScreenState extends State<ComplaintListScreen> {
  final _search = TextEditingController();
  final _processing = <int>{};
  String _status = 'All';
  List<SupervisorIssue> _issues = const [];
  String? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.openOnly) _status = 'Open';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadIssues();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadIssues() async {
    final session = AppStateScope.read(context).session;
    if (session == null) {
      setState(() {
        _loadError = 'Sign in again.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_processingKey) ?? const <String>[];
      final query = _search.text.trim();
      final rows = widget.openOnly
          ? await SupervisorApi().openIssues(session.cnic, query: query)
          : await SupervisorApi().issues(session.cnic, status: _apiStatus, query: query);
      if (!mounted) return;
      final processing = <int>{
        for (final id in saved)
          if (int.tryParse(id) != null) int.parse(id),
      };
      processing.removeWhere((id) => rows.any((issue) => issue.id == id && issue.resolved));
      await prefs.setStringList(_processingKey, [for (final id in processing) '$id']);
      if (!mounted) return;
      setState(() {
        _processing
          ..clear()
          ..addAll(processing);
        _issues = rows;
        _loadError = null;
        _loading = false;
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _rememberProcessing(int id) async {
    setState(() => _processing.add(id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_processingKey, [for (final saved in _processing) '$saved']);
  }

  List<SupervisorIssue> get _visibleIssues {
    final query = _search.text.trim().toLowerCase();
    return [
      for (final issue in _issues)
        if (_matchesStatus(issue) && _matchesQuery(issue, query)) issue,
    ];
  }

  String get _apiStatus {
    return switch (_status) {
      'Pending' => 'pending',
      'In Processing' => 'in_processing',
      'Resolved' => 'resolved',
      'Open' => 'pending',
      _ => 'all',
    };
  }

  bool _working(SupervisorIssue issue) => issue.inProcessing || _processing.contains(issue.id);

  bool _matchesStatus(SupervisorIssue issue) {
    final processing = _working(issue);
    return switch (_status) {
      'Pending' => !issue.resolved && !processing,
      'In Processing' => !issue.resolved && processing,
      'Open' => !issue.resolved,
      'Resolved' => issue.resolved,
      _ => true,
    };
  }

  bool _matchesQuery(SupervisorIssue issue, String query) {
    if (query.isEmpty) return true;
    final haystack =
        '${issue.id} ${issue.description} ${issue.sector} ${issue.activity} ${issue.loggedBy} ${issue.landmark ?? ''}'
            .toLowerCase();
    return haystack.contains(query);
  }

  String _badgeLabel(SupervisorIssue issue) {
    if (issue.resolved) return 'Completed';
    if (_working(issue)) return 'In Processing';
    return 'Pending';
  }

  Color _badgeColor(SupervisorIssue issue) {
    if (issue.resolved) return AppColors.success;
    if (_working(issue)) return AppColors.warning;
    return AppColors.info;
  }

  Future<void> _onAction(SupervisorIssue issue) async {
    if (issue.resolved) return;
    if (_working(issue)) {
      AppStateScope.read(context).openIssue(issue, processing: true);
      await context.push(AppRoutes.afterPhotos);
      if (mounted) await _loadIssues();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Start this complaint?'),
        content: const Text('After you confirm, this complaint moves to In Processing.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ModulePalette.complaintsAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final session = AppStateScope.read(context).session;
    if (session == null) return;
    try {
      await SupervisorApi().setIssueStatus(
        cnic: session.cnic,
        id: issue.id,
        portalStatus: 'in_processing',
      );
      await _rememberProcessing(issue.id);
      if (mounted) await _loadIssues();
    } on SupervisorException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _viewDetail(SupervisorIssue issue) async {
    AppStateScope.read(context).openIssue(
      issue,
      processing: _working(issue),
    );
    await context.push(AppRoutes.complaintDetails);
    if (mounted) await _loadIssues();
  }

  Future<void> _openLocation(SupervisorIssue issue) async {
    final lat = issue.latitude;
    final lng = issue.longitude;
    double? resolvedLat = lat;
    double? resolvedLng = lng;
    if ((resolvedLat == null || resolvedLng == null) && issue.geoTag != null && issue.geoTag!.contains(',')) {
      final parts = issue.geoTag!.split(',');
      resolvedLat = double.tryParse(parts[0].trim());
      resolvedLng = double.tryParse(parts[1].trim());
    }
    if (resolvedLat == null || resolvedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This complaint has no map location.')),
      );
      return;
    }
    final geo = Uri.parse('geo:$resolvedLat,$resolvedLng?q=$resolvedLat,$resolvedLng');
    try {
      final opened = await launchUrl(geo, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        final web = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$resolvedLat,$resolvedLng',
        );
        await launchUrl(web, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the location.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = widget.openOnly
        ? const ['Open', 'Pending', 'In Processing']
        : const ['All', 'Pending', 'In Processing', 'Resolved'];
    final visible = _visibleIssues;
    return AppPage(
      title: widget.openOnly ? 'Open Complaints' : 'All Complaints',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ModuleHero(
                  icon: widget.openOnly ? Icons.pending_actions_rounded : Icons.list_alt_rounded,
                  title: widget.openOnly ? 'Open complaints' : 'All complaints',
                  subtitle: widget.openOnly
                      ? 'Pending and in-processing cases ready for action.'
                      : 'Search, filter and open any cleanliness complaint.',
                  colors: ModulePalette.complaints,
                ),
                const SizedBox(height: 14),
                SearchBarField(
                  controller: _search,
                  hint: 'Search by ID, sector, or description',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                FilterChips(
                  options: filters,
                  selected: _status,
                  onSelected: (value) {
                    setState(() => _status = value);
                    _loadIssues();
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  _loading
                      ? 'Loading complaints…'
                      : '${visible.length} complaint${visible.length == 1 ? '' : 's'}',
                  style: AppType.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadIssues,
              child: _loading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: const [
                        LoadingSkeleton(height: 110, radius: 18),
                        SizedBox(height: 12),
                        LoadingSkeleton(height: 110, radius: 18),
                        SizedBox(height: 12),
                        LoadingSkeleton(height: 110, radius: 18),
                      ],
                    )
                  : _loadError != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            InlineMessage(tone: InlineTone.error, message: _loadError!),
                            const SizedBox(height: 12),
                            OutlineButton(label: 'Try again', onPressed: _loadIssues),
                          ],
                        )
                      : visible.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              children: const [
                                EmptyState(
                                  icon: Icons.inbox_outlined,
                                  title: 'No complaints',
                                  message: 'No complaints match this filter.',
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final issue = visible[index];
                                return _ComplaintStatusCard(
                                  issue: issue,
                                  statusLabel: _badgeLabel(issue),
                                  statusColor: _badgeColor(issue),
                                  onTap: () => _viewDetail(issue),
                                  onAction: issue.resolved ? null : () => _onAction(issue),
                                  onLocation: () => _openLocation(issue),
                                  actionLabel: _working(issue) && !issue.resolved
                                      ? 'Update'
                                      : 'Start',
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintStatusCard extends StatelessWidget {
  const _ComplaintStatusCard({
    required this.issue,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
    required this.onLocation,
    this.onAction,
    this.actionLabel = 'Start',
  });

  final SupervisorIssue issue;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;
  final VoidCallback? onAction;
  final VoidCallback onLocation;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final title = issue.activity.isEmpty ? 'Complaint #${issue.id}' : issue.activity;
    final place = [
      if (issue.sector.trim().isNotEmpty) issue.sector.trim(),
      if ((issue.landmark ?? '').trim().isNotEmpty) issue.landmark!.trim(),
    ].join(' · ');
    final description =
        issue.description.trim().isEmpty ? 'No description provided' : issue.description.trim();

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.report_outlined, color: statusColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.section.copyWith(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '#${issue.id}${place.isEmpty ? '' : ' · $place'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.caption,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ModuleStatusChip(label: statusLabel, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (issue.dateLogged.trim().isNotEmpty)
                          Expanded(
                            child: Text(
                              issue.dateLogged,
                              style: AppType.caption.copyWith(fontSize: 12),
                            ),
                          )
                        else
                          const Spacer(),
                        TextButton.icon(
                          onPressed: onLocation,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.navy,
                          ),
                          icon: const Icon(Icons.place_outlined, size: 16),
                          label: const Text('Map'),
                        ),
                        if (onAction != null)
                          FilledButton(
                            onPressed: onAction,
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: statusColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(actionLabel),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
