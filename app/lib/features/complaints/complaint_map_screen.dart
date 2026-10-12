import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'uc_boundaries.dart';

const _processingKey = 'complaintProcessingIds';

class ComplaintMapScreen extends StatefulWidget {
  const ComplaintMapScreen({super.key});

  @override
  State<ComplaintMapScreen> createState() => _ComplaintMapScreenState();
}

class _ComplaintMapScreenState extends State<ComplaintMapScreen> {
  final _search = TextEditingController();
  final _processing = ValueNotifier<Set<int>>(<int>{});
  String _status = 'All';
  int? _selectedId;
  List<SupervisorIssue> _issues = const [];
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadIssues();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _processing.dispose();
    super.dispose();
  }

  Future<void> _loadIssues() async {
    final session = AppStateScope.read(context).session;
    if (session == null) {
      setState(() => _loadError = 'Sign in again.');
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_processingKey) ?? const <String>[];
      final rows = await SupervisorApi().issues(session.cnic);
      if (!mounted) return;
      final processing = <int>{
        for (final id in saved)
          if (int.tryParse(id) != null) int.parse(id),
      };
      processing.removeWhere((id) => rows.any((issue) => issue.id == id && issue.resolved));
      _processing.value = processing;
      await prefs.setStringList(_processingKey, [for (final id in processing) '$id']);
      if (!mounted) return;
      setState(() {
        _issues = rows;
        _loadError = null;
        if (_selectedId != null && !_visibleIssues.any((issue) => issue.id == _selectedId)) {
          _selectedId = null;
        }
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.message);
    }
  }

  Future<void> _rememberProcessing(int id) async {
    final next = {..._processing.value, id};
    _processing.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_processingKey, [for (final saved in next) '$saved']);
  }

  List<SupervisorIssue> get _visibleIssues {
    final query = _search.text.trim().toLowerCase();
    return [
      for (final issue in _issues)
        if (_matchesStatus(issue) && _matchesQuery(issue, query)) issue,
    ];
  }

  bool _matchesStatus(SupervisorIssue issue) {
    return switch (_status) {
      'Pending' => !issue.resolved,
      'Resolved' => issue.resolved,
      _ => true,
    };
  }

  bool _matchesQuery(SupervisorIssue issue, String query) {
    if (query.isEmpty) return true;
    final haystack = '${issue.id} ${issue.description} ${issue.sector} ${issue.activity} ${issue.loggedBy}'.toLowerCase();
    return haystack.contains(query);
  }

  Future<void> _onAction(BuildContext sheetContext, SupervisorIssue issue) async {
    if (issue.resolved) return;
    if (_processing.value.contains(issue.id)) {
      AppStateScope.read(context).openIssue(issue, processing: true);
      await context.push(AppRoutes.afterPhotos);
      if (mounted) await _loadIssues();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (context) => AlertDialog(
        title: const Text('Start this complaint?'),
        content: const Text('After you confirm, this point changes to in processing.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _rememberProcessing(issue.id);
  }

  Future<void> _viewDetail(SupervisorIssue issue) async {
    AppStateScope.read(context).openIssue(
      issue,
      processing: _processing.value.contains(issue.id),
    );
    await context.push(AppRoutes.complaintDetails);
    if (mounted) await _loadIssues();
  }

  String _badgeLabel(SupervisorIssue issue, Set<int> processing) {
    if (issue.resolved) return 'Completed';
    if (processing.contains(issue.id)) return 'In Processing';
    return 'Pending';
  }

  Color _badgeColor(SupervisorIssue issue, Set<int> processing) {
    if (issue.resolved) return AppColors.success;
    if (processing.contains(issue.id)) return AppColors.warning;
    return AppColors.info;
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Complaints Map',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              children: [
                SearchBarField(
                  controller: _search,
                  hint: 'Search complaints',
                  onChanged: (_) => setState(() {
                    if (_selectedId != null && !_visibleIssues.any((issue) => issue.id == _selectedId)) {
                      _selectedId = null;
                    }
                  }),
                ),
                const SizedBox(height: 12),
                FilterChips(
                  options: const ['All', 'Pending', 'Resolved'],
                  selected: _status,
                  onSelected: (value) => setState(() {
                    _status = value;
                    if (_selectedId != null && !_visibleIssues.any((issue) => issue.id == _selectedId)) {
                      _selectedId = null;
                    }
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                child: _ComplaintsMap(
                  issues: _visibleIssues,
                  processing: _processing,
                  selectedId: _selectedId,
                  onSelect: (issue) => setState(() => _selectedId = issue?.id),
                  onAction: _onAction,
                  onViewDetail: _viewDetail,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                if (_loadError != null)
                  InlineMessage(tone: InlineTone.error, message: _loadError!)
                else if (_visibleIssues.isEmpty)
                  const InlineMessage(message: 'No complaints match this filter.')
                else
                  ValueListenableBuilder<Set<int>>(
                    valueListenable: _processing,
                    builder: (context, processing, _) {
                      return SizedBox(
                        height: 168,
                        child: ListView.separated(
                          itemCount: _visibleIssues.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final issue = _visibleIssues[index];
                            final selected = issue.id == _selectedId;
                            return ListItem(
                              title: issue.activity.isEmpty ? 'Complaint ${issue.id}' : issue.activity,
                              subtitle: issue.description.isEmpty ? issue.sector : issue.description,
                              trailing: StatusBadge(
                                label: _badgeLabel(issue, processing),
                                color: _badgeColor(issue, processing),
                              ),
                              onTap: () => setState(() => _selectedId = selected ? null : issue.id),
                            );
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintsMap extends StatefulWidget {
  const _ComplaintsMap({
    required this.issues,
    required this.processing,
    required this.selectedId,
    required this.onSelect,
    required this.onAction,
    required this.onViewDetail,
    this.initialAreas,
    this.allowFullScreen = true,
  });

  final List<SupervisorIssue> issues;
  final ValueNotifier<Set<int>> processing;
  final int? selectedId;
  final ValueChanged<SupervisorIssue?> onSelect;
  final Future<void> Function(BuildContext context, SupervisorIssue issue) onAction;
  final Future<void> Function(SupervisorIssue issue) onViewDetail;
  final List<UcArea>? initialAreas;
  final bool allowFullScreen;

  @override
  State<_ComplaintsMap> createState() => _ComplaintsMapState();
}

class _ComplaintsMapState extends State<_ComplaintsMap> {
  static const _islamabad = LatLng(33.6844, 73.0479);
  static const _fills = <Color>[
    Color(0xFF0F766E),
    Color(0xFF1D4ED8),
    Color(0xFFB45309),
    Color(0xFF7C3AED),
    Color(0xFFBE123C),
    Color(0xFF047857),
    Color(0xFF0369A1),
    Color(0xFFA16207),
  ];

  final _controller = MapController();
  final LayerHitNotifier<UcArea> _hits = ValueNotifier(null);
  List<UcArea> _areas = const [];
  bool _loading = true;
  bool _mapReady = false;
  String? _error;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedId;
    widget.processing.addListener(_onProcessing);
    final seeded = widget.initialAreas;
    if (seeded != null && seeded.isNotEmpty) {
      _areas = seeded;
      _loading = false;
    } else {
      _load();
    }
  }

  void _onProcessing() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _ComplaintsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.processing != widget.processing) {
      oldWidget.processing.removeListener(_onProcessing);
      widget.processing.addListener(_onProcessing);
    }
    if (widget.selectedId != oldWidget.selectedId && widget.selectedId != _selectedId) {
      _selectedId = widget.selectedId;
      final point = _point(_issueById(widget.selectedId));
      if (point != null && _mapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _mapReady) _controller.move(point, 16);
        });
      }
    }
  }

  @override
  void dispose() {
    widget.processing.removeListener(_onProcessing);
    _hits.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final areas = await loadUcAreas();
      if (!mounted) return;
      setState(() {
        _areas = areas;
        _loading = false;
      });
      if (_mapReady) _fit(areas);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Union council boundaries could not be loaded.';
        _loading = false;
      });
    }
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    final camera = _controller.camera;
    final next = (camera.zoom + delta).clamp(8.0, 18.0);
    _controller.move(camera.center, next);
  }

  void _openFullMap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AppPage(
          title: 'Complaints Map',
          body: _ComplaintsMap(
            issues: widget.issues,
            processing: widget.processing,
            selectedId: _selectedId,
            onSelect: widget.onSelect,
            onAction: widget.onAction,
            onViewDetail: widget.onViewDetail,
            initialAreas: _areas,
            allowFullScreen: false,
          ),
        ),
      ),
    );
  }

  void _fit(List<UcArea> areas) {
    if (!_mapReady) return;
    final points = [for (final area in areas) ...area.points];
    if (points.isEmpty) return;
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(16),
        maxZoom: 14,
      ),
    );
  }

  List<UcArea> get _visibleAreas => _areas;

  SupervisorIssue? _issueById(int? id) {
    if (id == null) return null;
    for (final issue in widget.issues) {
      if (issue.id == id) return issue;
    }
    return null;
  }

  void _select(SupervisorIssue issue) {
    setState(() => _selectedId = issue.id);
    widget.onSelect(issue);
    final point = _point(issue);
    if (point != null && _mapReady) _controller.move(point, 16);
  }

  Future<void> _openLocation(SupervisorIssue issue) async {
    final point = _point(issue);
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This complaint has no map location.')),
      );
      return;
    }
    if (_mapReady) _controller.move(point, 16);
    final geo = Uri.parse('geo:${point.latitude},${point.longitude}?q=${point.latitude},${point.longitude}');
    try {
      final opened = await launchUrl(geo, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        final web = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${point.latitude},${point.longitude}',
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
    final areas = _visibleAreas;
    final selected = _issueById(_selectedId);
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _islamabad,
            initialZoom: 11,
            minZoom: 8,
            maxZoom: 18,
            onMapReady: () {
              _mapReady = true;
              _fit(areas.isEmpty ? _areas : areas);
            },
            onTap: (_, _) {
              final area = _hits.value?.hitValues.firstOrNull;
              if (area != null) _fit([area]);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'pk.gov.cda.cda_clean_islamabad',
            ),
            PolygonLayer<UcArea>(
              hitNotifier: _hits,
              polygonLabels: true,
              drawLabelsLast: true,
              polygons: [
                for (var i = 0; i < areas.length; i++)
                  Polygon<UcArea>(
                    points: areas[i].points,
                    hitValue: areas[i],
                    label: areas[i].code,
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(color: Color(0xCC0F172A), blurRadius: 4),
                      ],
                    ),
                    color: _fills[i % _fills.length].withValues(alpha: 0.38),
                    borderColor: _fills[i % _fills.length],
                    borderStrokeWidth: 2,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final issue in widget.issues)
                  if (_point(issue) case final point?)
                    Marker(
                      key: ValueKey(issue.id),
                      point: point,
                      width: 28,
                      height: 28,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onTap: () => _select(issue),
                        child: _ComplaintPin(
                          color: _pinColor(issue, widget.processing.value),
                          selected: issue.id == _selectedId,
                        ),
                      ),
                    ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Column(
            children: [
              if (widget.allowFullScreen)
                _MapButton(
                  icon: Icons.open_in_full_rounded,
                  tooltip: 'Full map',
                  onPressed: _openFullMap,
                ),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.add_rounded,
                tooltip: 'Zoom in',
                onPressed: _mapReady ? () => _zoomBy(1) : null,
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.remove_rounded,
                tooltip: 'Zoom out to union councils',
                onPressed: _mapReady ? () => _fit(areas) : null,
              ),
            ],
          ),
        ),
        if (selected != null)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: _PointActions(
              issue: selected,
              processing: widget.processing.value.contains(selected.id),
              onAction: () => widget.onAction(context, selected),
              onLocation: () => _openLocation(selected),
              onViewDetail: () => widget.onViewDetail(selected),
            ),
          ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _PointActions extends StatelessWidget {
  const _PointActions({
    required this.issue,
    required this.processing,
    required this.onAction,
    required this.onLocation,
    required this.onViewDetail,
  });

  final SupervisorIssue issue;
  final bool processing;
  final VoidCallback onAction;
  final VoidCallback onLocation;
  final VoidCallback onViewDetail;

  @override
  Widget build(BuildContext context) {
    final completed = issue.resolved;
    final label = completed
        ? 'Completed'
        : processing
            ? 'In Processing'
            : 'Pending';
    final color = completed
        ? AppColors.success
        : processing
            ? AppColors.warning
            : AppColors.info;
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    issue.activity.isEmpty ? 'Complaint ${issue.id}' : issue.activity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(label: label, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PointButton(
                    icon: Icons.play_arrow_rounded,
                    label: processing && !completed ? 'Update' : 'Action',
                    onPressed: completed ? null : onAction,
                  ),
                ),
                Expanded(
                  child: _PointButton(
                    icon: Icons.near_me_outlined,
                    label: 'Location',
                    onPressed: onLocation,
                  ),
                ),
                Expanded(
                  child: _PointButton(
                    icon: Icons.article_outlined,
                    label: 'View detail',
                    onPressed: onViewDetail,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PointButton extends StatelessWidget {
  const _PointButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _ComplaintPin extends StatefulWidget {
  const _ComplaintPin({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  State<_ComplaintPin> createState() => _ComplaintPinState();
}

class _ComplaintPinState extends State<_ComplaintPin> {
  double _scale = 1;

  @override
  void didUpdateWidget(covariant _ComplaintPin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color != oldWidget.color) {
      setState(() => _scale = 1.4);
      Future<void>.delayed(const Duration(milliseconds: 240), () {
        if (mounted) setState(() => _scale = 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: widget.selected ? _scale * 1.12 : _scale,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      child: Icon(
        Icons.location_on,
        color: widget.color,
        size: widget.selected ? 28 : 22,
        shadows: const [
          Shadow(color: Color(0x660F172A), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF12304A), size: 20),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

LatLng? _point(SupervisorIssue? issue) {
  if (issue == null) return null;
  final lat = issue.latitude;
  final lng = issue.longitude;
  if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180 && !(lat == 0 && lng == 0)) {
    return LatLng(lat, lng);
  }
  final tag = issue.geoTag;
  if (tag == null || !tag.contains(',')) return null;
  final parts = tag.split(',');
  final parsedLat = double.tryParse(parts[0].trim());
  final parsedLng = double.tryParse(parts[1].trim());
  if (parsedLat == null || parsedLng == null) return null;
  return LatLng(parsedLat, parsedLng);
}

Color _pinColor(SupervisorIssue issue, Set<int> processing) {
  if (issue.resolved) return AppColors.success;
  if (processing.contains(issue.id)) return AppColors.warning;
  return const Color(0xFFE11D48);
}
